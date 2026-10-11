import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../tokens/colors.dart';
import '../tokens/spacing.dart';
import '../tokens/typography.dart';

/// Labelled text field (48px, 10px radius). Supports a password visibility toggle
/// and an externally supplied [errorText] (e.g. a 422 field error from the API).
class NordicTextField extends StatefulWidget {
  const NordicTextField({
    super.key,
    required this.label,
    this.controller,
    this.hint,
    this.errorText,
    this.helperText,
    this.validator,
    this.keyboardType,
    this.textInputAction,
    this.obscureText = false,
    this.prefixIcon,
    this.suffix,
    this.onChanged,
    this.onSubmitted,
    this.onTap,
    this.readOnly = false,
    this.enabled = true,
    this.autofillHints,
    this.inputFormatters,
    this.focusNode,
    this.maxLines = 1,
    this.autofocus = false,
  });

  final String label;
  final TextEditingController? controller;
  final String? hint;
  final String? errorText;
  final String? helperText;
  final FormFieldValidator<String>? validator;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool obscureText;
  final IconData? prefixIcon;
  final Widget? suffix;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onTap;
  final bool readOnly;
  final bool enabled;
  final Iterable<String>? autofillHints;
  final List<TextInputFormatter>? inputFormatters;
  final FocusNode? focusNode;
  final int maxLines;
  final bool autofocus;

  @override
  State<NordicTextField> createState() => _NordicTextFieldState();
}

class _NordicTextFieldState extends State<NordicTextField> {
  late bool _obscured = widget.obscureText;

  OutlineInputBorder _border(Color color, [double width = 1]) =>
      OutlineInputBorder(
        borderRadius: NordicRadii.inputRadius,
        borderSide: BorderSide(color: color, width: width),
      );

  @override
  Widget build(BuildContext context) {
    final suffix = widget.obscureText
        ? IconButton(
            tooltip: _obscured ? 'Show password' : 'Hide password',
            icon: Icon(
              _obscured
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
              size: 20,
            ),
            color: NordicColors.textSubdued,
            onPressed: () => setState(() => _obscured = !_obscured),
          )
        : widget.suffix;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          widget.label,
          style: NordicText.labelMd.copyWith(color: NordicColors.textSecondary),
        ),
        const SizedBox(height: 4),
        TextFormField(
          controller: widget.controller,
          focusNode: widget.focusNode,
          autofocus: widget.autofocus,
          validator: widget.validator,
          keyboardType: widget.keyboardType,
          textInputAction: widget.textInputAction,
          obscureText: _obscured,
          readOnly: widget.readOnly,
          enabled: widget.enabled,
          onChanged: widget.onChanged,
          onFieldSubmitted: widget.onSubmitted,
          onTap: widget.onTap,
          autofillHints: widget.autofillHints,
          inputFormatters: widget.inputFormatters,
          maxLines: widget.obscureText ? 1 : widget.maxLines,
          style: NordicText.bodyMd,
          cursorColor: NordicColors.accentTeal,
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: widget.enabled
                ? NordicColors.surfaceSubdued
                : NordicColors.surfaceMuted,
            hintText: widget.hint,
            hintStyle: NordicText.bodyMd.copyWith(
              color: NordicColors.textSubdued,
            ),
            helperText: widget.helperText,
            helperStyle: NordicText.bodySm.copyWith(
              color: NordicColors.textSecondary,
            ),
            errorText: widget.errorText,
            errorStyle: NordicText.bodySm.copyWith(color: NordicColors.error),
            errorMaxLines: 3,
            prefixIcon: widget.prefixIcon == null
                ? null
                : Icon(
                    widget.prefixIcon,
                    size: 20,
                    color: NordicColors.textSubdued,
                  ),
            suffixIcon: suffix,
            contentPadding: EdgeInsets.symmetric(
              horizontal: NordicSpacing.md,
              vertical: widget.maxLines > 1 ? 12 : 14,
            ),
            constraints: widget.maxLines > 1
                ? null
                : const BoxConstraints(minHeight: 56),
            enabledBorder: _border(NordicColors.border),
            disabledBorder: _border(NordicColors.border),
            focusedBorder: _border(NordicColors.primaryContainer, 2),
            errorBorder: _border(NordicColors.error),
            focusedErrorBorder: _border(NordicColors.error, 2),
          ),
        ),
      ],
    );
  }
}
