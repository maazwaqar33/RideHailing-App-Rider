import re, os, sys, hashlib, urllib.request, json
BASE = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SRC = os.path.join(os.path.dirname(BASE), 'stitch_nordic_ride_hailing_app')
OUT = os.path.join(BASE, 'tool', '_design', 'body')
IMG = os.path.join(BASE, 'assets', 'design')
os.makedirs(OUT, exist_ok=True); os.makedirs(IMG, exist_ok=True)
urlmap = {}
def fetch(url):
    h = hashlib.md5(url.encode()).hexdigest()[:10]
    for ext in ('jpg','png'):
        p = os.path.join(IMG, h + '.' + ext)
        if os.path.exists(p): return h + '.' + ext
    try:
        req = urllib.request.Request(url, headers={'User-Agent':'Mozilla/5.0'})
        data = urllib.request.urlopen(req, timeout=30).read()
        ext = 'png' if data[:4] == b'\x89PNG' else 'jpg'
        open(os.path.join(IMG, h + '.' + ext), 'wb').write(data)
        return h + '.' + ext
    except Exception as e:
        return 'FAILED(' + str(e)[:40] + ')'
for d in sorted(os.listdir(SRC)):
    f = os.path.join(SRC, d, 'code.html')
    if not os.path.exists(f): continue
    html = open(f, encoding='utf8').read()
    body = html[html.index('<body'):]
    # keep inline style blocks that matter (before body) minimal: print them separately
    styles = re.findall(r'<style>(.*?)</style>', html, re.S)
    def repl(m):
        u = m.group(0)
        if 'googleusercontent' in u:
            name = fetch(u)
            urlmap[u] = name
            return 'IMG[' + name + ']'
        return u
    body = re.sub(r'https://lh3\.googleusercontent\.com/[^"\')\s]+', repl, body)
    body = re.sub(r'(<svg[^>]*>)(.*?)(</svg>)', lambda m: m.group(1)+re.sub(r'\sd="([^"]{70})[^"]*"', r' d="..."', m.group(2))+m.group(3), body, flags=re.S)
    body = re.sub(r'>\s*<', '>\n<', body)
    body = re.sub(r'[ \t]+', ' ', body)
    custom = '\n'.join(s.strip() for s in styles if 'material-symbols' in s.lower() or 'keyframes' in s or 'gradient' in s)
    open(os.path.join(OUT, d + '.txt'), 'w', encoding='utf8').write('/* STYLES */\n' + custom + '\n/* BODY */\n' + body)
json.dump(urlmap, open(os.path.join(OUT, '_urlmap.json'), 'w'), indent=1)
print(len(urlmap), 'images;', sum(1 for v in urlmap.values() if v.startswith('FAILED')), 'failed')
