import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'auth_palette.dart';

/// Champ de saisie premium des écrans d'authentification : étiquette avec
/// icône, bordure et halo qui s'animent en douceur au focus et en cas
/// d'erreur de validation.
class PremiumAuthField extends StatefulWidget {
  final String label;
  final IconData icon;
  final String hint;
  final TextEditingController controller;
  final FocusNode? focusNode;
  final bool enabled;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final bool autocorrect;
  final Widget? suffix;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;
  final void Function(String)? onFieldSubmitted;
  final TextStyle? style;
  final TextAlign textAlign;
  final int? maxLength;
  final bool autofocus;

  const PremiumAuthField({
    super.key,
    required this.label,
    required this.icon,
    required this.hint,
    required this.controller,
    this.focusNode,
    this.enabled = true,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.autocorrect = true,
    this.suffix,
    this.validator,
    this.onChanged,
    this.onFieldSubmitted,
    this.style,
    this.textAlign = TextAlign.start,
    this.maxLength,
    this.autofocus = false,
  });

  @override
  State<PremiumAuthField> createState() => _PremiumAuthFieldState();
}

class _PremiumAuthFieldState extends State<PremiumAuthField> {
  late final FocusNode _focusNode = widget.focusNode ?? FocusNode();
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (_focused == _focusNode.hasFocus) return;
    setState(() => _focused = _focusNode.hasFocus);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    if (widget.focusNode == null) _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FormField<String>(
      initialValue: widget.controller.text,
      validator: widget.validator,
      builder: (field) {
        final hasError = field.hasError;
        final labelColor = hasError ? AuthPalette.danger : AuthPalette.forest;
        final borderColor = hasError
            ? AuthPalette.danger
            : (_focused
                ? AuthPalette.forest
                : AuthPalette.sage.withValues(alpha: 0.45));

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(widget.icon, size: 15, color: labelColor),
                const SizedBox(width: 7),
                Text(
                  widget.label,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: hasError ? AuthPalette.danger : AuthPalette.ink,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOut,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: _focused ? Colors.white : AuthPalette.fieldFill,
                border:
                    Border.all(color: borderColor, width: _focused ? 1.6 : 1.1),
                boxShadow: _focused
                    ? [
                        BoxShadow(
                          color: AuthPalette.forest.withValues(alpha: 0.14),
                          blurRadius: 14,
                          offset: const Offset(0, 5),
                        ),
                      ]
                    : null,
              ),
              child: TextField(
                controller: widget.controller,
                focusNode: _focusNode,
                enabled: widget.enabled,
                obscureText: widget.obscureText,
                keyboardType: widget.keyboardType,
                textInputAction: widget.textInputAction,
                textCapitalization: widget.textCapitalization,
                autocorrect: widget.autocorrect,
                textAlign: widget.textAlign,
                maxLength: widget.maxLength,
                autofocus: widget.autofocus,
                style: widget.style ??
                    const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: AuthPalette.ink,
                    ),
                onChanged: (v) {
                  field.didChange(v);
                  widget.onChanged?.call(v);
                },
                onSubmitted: widget.onFieldSubmitted,
                decoration: InputDecoration(
                  hintText: widget.hint,
                  hintStyle: const TextStyle(color: AuthPalette.fieldHint),
                  prefixIcon:
                      Icon(widget.icon, size: 18, color: AuthPalette.forest),
                  suffixIcon: widget.suffix,
                  filled: false,
                  isDense: false,
                  counterText: widget.maxLength != null ? '' : null,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                ),
              ),
            ),
            if (hasError) ...[
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.only(left: 2),
                child: Text(
                  field.errorText!,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: AuthPalette.danger,
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

/// Bouton œil standard pour basculer l'affichage d'un mot de passe.
class PasswordVisibilityToggle extends StatelessWidget {
  final bool obscured;
  final VoidCallback onPressed;
  const PasswordVisibilityToggle(
      {super.key, required this.obscured, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: obscured ? 'Afficher' : 'Masquer',
      icon: Icon(obscured ? LucideIcons.eye : LucideIcons.eyeOff,
          size: 18, color: AuthPalette.forest),
      onPressed: onPressed,
    );
  }
}
