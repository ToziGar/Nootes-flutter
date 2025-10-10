import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class ModernTextField extends StatelessWidget {
  const ModernTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.icon,
    this.obscureText = false,
    this.keyboardType,
    this.autofillHints,
    this.suffixIcon,
    this.validator,
    this.tone = ModernFieldTone.primary,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final List<String>? autofillHints;
  final Widget? suffixIcon;
  final String? Function(String?)? validator;
  final ModernFieldTone tone;

  Color get _baseColor => switch (tone) {
        ModernFieldTone.primary => AppColors.primary,
        ModernFieldTone.accent => AppColors.accent,
        ModernFieldTone.secondary => AppColors.secondary,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _baseColor.withValues(alpha: 0.2),
          width: 1,
        ),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _baseColor.withValues(alpha: 0.05),
            Colors.transparent,
          ],
        ),
      ),
      child: TextFormField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        autofillHints: autofillHints,
        validator: validator,
        style: Theme.of(context).textTheme.bodyLarge,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: _baseColor),
          suffixIcon: suffixIcon,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.transparent,
          labelStyle: TextStyle(color: _baseColor.withValues(alpha: 0.8)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
      ),
    );
  }
}

enum ModernFieldTone { primary, secondary, accent }
