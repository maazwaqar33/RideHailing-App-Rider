import os

def process_file(path, replacements):
    with open(path, 'r', encoding='utf-8') as f:
        content = f.read()
    for old, new in replacements:
        content = content.replace(old, new)
    with open(path, 'w', encoding='utf-8') as f:
        f.write(content)

base = 'c:/Users/syedp/Desktop/POC/rider_app/lib'

process_file(f'{base}/features/auth/presentation/signup_screen.dart', [
    ("import '../../../shared/widgets.dart';\n", "")
])

process_file(f'{base}/features/auth/presentation/welcome_screen.dart', [
    ("import '../../../shared/widgets.dart';\n", "")
])

process_file(f'{base}/features/booking/presentation/confirm_pay_screen.dart', [
    ("showUnavailable, ", ""),
    ("this.iconFill = 0,", ""),
    ("final double iconFill;", ""),
    ("fill: iconFill,", "fill: 0,")
])

process_file(f'{base}/features/history/presentation/trip_receipt_screen.dart', [
    ("showUnavailable, ", "")
])

process_file(f'{base}/features/history/presentation/trips_tab.dart', [
    ("showUnavailable, ", "")
])

process_file(f'{base}/features/map/presentation/ride_tab.dart', [
    ("import '../../../shared/widgets.dart';\n", "")
])

process_file(f'{base}/features/tracking/presentation/ride_screen.dart', [
    ("import '../../../shared/widgets.dart';\n", ""),
    ("opacity: available ? 1 : 0.7,", "")
])

process_file(f'{base}/features/trip/presentation/trip_complete_screen.dart', [
    ("import '../../../shared/widgets.dart';\n", "")
])

process_file(f'{base}/features/wallet/presentation/wallet_tab.dart', [
    ("showUnavailable, UnavailableTag, ", ""),
    (", UnavailableTag", ""),
    (", showUnavailable", ""),
    ("UnavailableTag, ", ""),
    ("showUnavailable, ", ""),
    ("showUnavailable", "") # fallback if it's the only import
])

process_file(f'{base}/shared/account_sections.dart', [
    ("import 'widgets.dart';\n", "")
])
