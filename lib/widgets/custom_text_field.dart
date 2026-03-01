/// Reusable custom text field widget for the Spendly app.
///
/// Provides a consistently styled Material 3 input field with:
/// - Rounded outline border matching the app theme
/// - Prefix icon support
/// - Optional suffix icon (e.g. password visibility toggle)
/// - Built-in validation support
/// - Focus/error state styling
library;

import 'package:flutter/material.dart';
import '../utils/constants.dart';

class CustomTextField extends StatelessWidget {
  /// Creates a themed text field with consistent styling.
  const CustomTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.prefixIcon,
    this.suffixIcon,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.textInputAction = TextInputAction.next,
    this.validator,
    this.onFieldSubmitted,
    this.enabled = true,
    this.maxLines = 1,
    this.hintText,
    this.autofillHints,
    this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final IconData prefixIcon;
  final Widget? suffixIcon;
  final bool obscureText;
  final TextInputType keyboardType;
  final TextInputAction textInputAction;
  final String? Function(String?)? validator;
  final void Function(String)? onFieldSubmitted;
  final void Function(String)? onChanged;
  final bool enabled;
  final int maxLines;
  final String? hintText;
  final Iterable<String>? autofillHints;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      validator: validator,
      onFieldSubmitted: onFieldSubmitted,
      onChanged: onChanged,
      enabled: enabled,
      maxLines: maxLines,
      autofillHints: autofillHints,
      style: const TextStyle(
        fontSize: 16,
        color: AppConstants.textDark,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        prefixIcon: Icon(prefixIcon, color: AppConstants.primaryGreen),
        suffixIcon: suffixIcon,

        // ── Default (unfocused) border ──
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.borderRadiusMedium),
          borderSide: const BorderSide(color: AppConstants.textLightGray),
        ),

        // ── Enabled but unfocused border ──
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.borderRadiusMedium),
          borderSide: const BorderSide(color: AppConstants.textLightGray),
        ),

        // ── Focused border ──
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.borderRadiusMedium),
          borderSide: const BorderSide(
            color: AppConstants.primaryGreen,
            width: 2,
          ),
        ),

        // ── Error border ──
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.borderRadiusMedium),
          borderSide: const BorderSide(color: AppConstants.errorRed),
        ),

        // ── Focused + error border ──
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.borderRadiusMedium),
          borderSide: const BorderSide(
            color: AppConstants.errorRed,
            width: 2,
          ),
        ),

        // ── Label & hint styling ──
        labelStyle: const TextStyle(color: AppConstants.textMediumGray),
        hintStyle: const TextStyle(color: AppConstants.textLightGray),
        errorStyle: const TextStyle(color: AppConstants.errorRed, fontSize: 12),

        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppConstants.paddingMedium,
          vertical: AppConstants.paddingMedium,
        ),
      ),
    );
  }
}
