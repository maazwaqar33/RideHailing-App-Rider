import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nordic_design_kit/nordic_design_kit.dart';

import 'stitch.dart';

/// Stitch form field: label (label-md), 56 px white rounded-xl field with soft shadow, leading
/// Material Symbol, optional trailing widget and an inline error line.
/// Validation errors render BELOW the field so the 56 px box never grows.
class StitchTextField extends StatefulWidget {
  const StitchTextField({
    super.key,
    required this.label,
    required this.controller,
    this.icon,
    this.hint,
    this.obscure = false,
    this.keyboardType,
    this.textInputAction,
    this.validator,
    this.serverError,
    this.onSubmitted,
    this.onChanged,
    this.autofillHints,
    this.trailing,
    this.labelTrailing,
    this.height = 56,
    this.radius = 12,
    this.fill = NordicColors.surfaceContainerLowest,
    this.inputFormatters,
    this.maxLines = 1,
    this.enabled = true,
    this.iconSize = 22,
    this.showPasswordToggle = true,
  });

  final String label;
  final TextEditingController controller;
  final IconData? icon;
  final String? hint;
  final bool obscure;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final FormFieldValidator<String>? validator;
  final String? serverError;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;
  final Iterable<String>? autofillHints;
  final Widget? trailing;
  final Widget? labelTrailing;
  final double height;
  final double radius;
  final Color fill;
  final List<TextInputFormatter>? inputFormatters;
  final int maxLines;
  final bool enabled;
  final double iconSize;
  final bool showPasswordToggle;

  @override
  State<StitchTextField> createState() => _StitchTextFieldState();
}

class _StitchTextFieldState extends State<StitchTextField> {
  final _focus = FocusNode();
  late bool _hidden = widget.obscure;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FormField<String>(
      validator: widget.validator == null
          ? null
          : (_) => widget.validator!(widget.controller.text),
      builder: (state) {
        final error = widget.serverError ?? state.errorText;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.label,
                    style: NordicText.labelMd.copyWith(
                      color: NordicColors.onSurfaceVariant,
                    ),
                  ),
                ),
                ?widget.labelTrailing,
              ],
            ),
            const SizedBox(height: 6),
            Elevated(
              shadows: _focus.hasFocus ? Tw.md : Tw.sm,
              radius: widget.radius,
              child: Container(
                height: widget.maxLines > 1 ? null : widget.height,
                decoration: BoxDecoration(
                  color: widget.fill,
                  borderRadius: BorderRadius.circular(widget.radius),
                  border: error != null
                      ? Border.all(color: NordicColors.error, width: 1.5)
                      : null,
                ),
                child: Row(
                  crossAxisAlignment: widget.maxLines > 1
                      ? CrossAxisAlignment.start
                      : CrossAxisAlignment.center,
                  children: [
                    if (widget.icon != null)
                      Padding(
                        padding: EdgeInsets.only(
                          left: 16,
                          top: widget.maxLines > 1 ? 16 : 0,
                        ),
                        child: MIcon(
                          widget.icon!,
                          size: widget.iconSize,
                          color: NordicColors.outline,
                        ),
                      ),
                    Expanded(
                      child: TextField(
                        controller: widget.controller,
                        focusNode: _focus,
                        obscureText: _hidden,
                        enabled: widget.enabled,
                        keyboardType: widget.keyboardType,
                        textInputAction: widget.textInputAction,
                        autofillHints: widget.autofillHints,
                        inputFormatters: widget.inputFormatters,
                        maxLines: widget.obscure ? 1 : widget.maxLines,
                        onChanged: (v) {
                          if (state.hasError) state.validate();
                          widget.onChanged?.call(v);
                        },
                        onSubmitted: widget.onSubmitted,
                        style: NordicText.bodyMd.copyWith(
                          color: NordicColors.onSurface,
                        ),
                        cursorColor: NordicColors.secondary,
                        decoration: InputDecoration(
                          isCollapsed: false,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          disabledBorder: InputBorder.none,
                          errorBorder: InputBorder.none,
                          hintText: widget.hint,
                          hintStyle: NordicText.bodyMd.copyWith(
                            color: NordicColors.outline,
                          ),
                          contentPadding: EdgeInsets.only(
                            left: widget.icon != null ? 16 : 16,
                            right: 16,
                            top: widget.maxLines > 1 ? 16 : 0,
                            bottom: widget.maxLines > 1 ? 16 : 0,
                          ),
                        ),
                      ),
                    ),
                    if (widget.obscure && widget.showPasswordToggle)
                      Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: GestureDetector(
                          onTap: () => setState(() => _hidden = !_hidden),
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: MIcon(
                              _hidden
                                  ? Symbols.visibility
                                  : Symbols.visibility_off,
                              size: widget.iconSize,
                              color: NordicColors.outline,
                            ),
                          ),
                        ),
                      )
                    else if (widget.trailing != null)
                      Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: widget.trailing,
                      ),
                  ],
                ),
              ),
            ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  error,
                  style: NordicText.labelMd.copyWith(
                    color: NordicColors.error,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
