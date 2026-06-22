import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../services/auth_service.dart';
import '../../theme/app_fonts.dart';

/// Écran de connexion / inscription des passagers.
class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();

  bool _signUpMode = false;
  bool _loading = false;
  bool _obscure = true;
  String? _error;
  String? _info;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _setMode(bool signUp) {
    if (_loading || signUp == _signUpMode) return;
    setState(() {
      _signUpMode = signUp;
      _error = null;
      _info = null;
    });
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = 'Renseigne ton email et ton mot de passe');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _info = null;
    });

    final auth = context.read<AuthService>();

    if (_signUpMode) {
      final result = await auth.signUpPassenger(
        email,
        password,
        displayName: _nameController.text,
      );
      if (!mounted) return;
      setState(() => _loading = false);
      if (result.isSuccess) {
        Navigator.of(context).pop(true);
      } else if (result.needsEmailConfirmation) {
        setState(() => _info =
            'Compte créé. Vérifie ta boîte mail pour confirmer ton adresse, puis connecte-toi.');
      } else {
        setState(() => _error = result.message);
      }
      return;
    }

    final err = await auth.signInPassenger(email, password);
    if (!mounted) return;
    setState(() => _loading = false);
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    Navigator.of(context).pop(true);
  }

  Future<void> _oauth(Future<String?> Function() action) async {
    setState(() {
      _loading = true;
      _error = null;
      _info = null;
    });
    final err = await action();
    if (!mounted) return;
    setState(() => _loading = false);
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    // Le retour OAuth se fait via deep link ; la session est mise à jour en
    // arrière-plan. On ferme l'écran, le menu reflètera l'état connecté.
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF141A23) : Colors.white;
    final scaffoldBg = isDark ? const Color(0xFF0B1016) : const Color(0xFFF4F6FA);
    final primaryTextColor =
        isDark ? const Color(0xFFEFF3F9) : const Color(0xFF0B1220);
    final mutedTextColor =
        isDark ? const Color(0xFF9BA7B7) : const Color(0xFF5B6677);
    final borderCol =
        isDark ? const Color(0x17FFFFFF) : const Color(0xFFE7EAF0);
    const accent = Color(0xFF1B66F5);

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        backgroundColor: scaffoldBg,
        elevation: 0,
        title: Text(
          _signUpMode ? 'Créer un compte' : 'Se connecter',
          style: hankenGrotesk(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: primaryTextColor,
          ),
        ),
        iconTheme: IconThemeData(color: primaryTextColor),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            Text(
              'Crée un compte pour retrouver tes favoris sur tous tes appareils. '
              'Tu peux continuer sans compte à tout moment.',
              style: hankenGrotesk(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: mutedTextColor,
              ),
            ),
            const SizedBox(height: 18),
            _ModeToggle(
              signUpMode: _signUpMode,
              onSelect: _setMode,
              accent: accent,
              cardBg: cardBg,
              borderCol: borderCol,
              mutedTextColor: mutedTextColor,
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: borderCol),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_signUpMode) ...[
                    _FieldLabel('Nom (optionnel)', mutedTextColor),
                    _AccountField(
                      controller: _nameController,
                      hint: 'Comment t\'appeler ?',
                      icon: LucideIcons.user,
                      primaryTextColor: primaryTextColor,
                      mutedTextColor: mutedTextColor,
                      borderCol: borderCol,
                    ),
                    const SizedBox(height: 14),
                  ],
                  _FieldLabel('Email', mutedTextColor),
                  _AccountField(
                    controller: _emailController,
                    hint: 'toi@exemple.fr',
                    icon: LucideIcons.mail,
                    keyboardType: TextInputType.emailAddress,
                    primaryTextColor: primaryTextColor,
                    mutedTextColor: mutedTextColor,
                    borderCol: borderCol,
                  ),
                  const SizedBox(height: 14),
                  _FieldLabel('Mot de passe', mutedTextColor),
                  _AccountField(
                    controller: _passwordController,
                    hint: '••••••••',
                    icon: LucideIcons.lock,
                    obscure: _obscure,
                    primaryTextColor: primaryTextColor,
                    mutedTextColor: mutedTextColor,
                    borderCol: borderCol,
                    suffix: IconButton(
                      icon: Icon(
                        _obscure ? LucideIcons.eye : LucideIcons.eyeOff,
                        size: 18,
                        color: mutedTextColor,
                      ),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 14),
                    _Banner(
                      text: _error!,
                      color: theme.colorScheme.error,
                      icon: LucideIcons.circleAlert,
                    ),
                  ],
                  if (_info != null) ...[
                    const SizedBox(height: 14),
                    _Banner(
                      text: _info!,
                      color: accent,
                      icon: LucideIcons.mailCheck,
                    ),
                  ],
                  const SizedBox(height: 18),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: accent,
                      minimumSize: const Size.fromHeight(50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: _loading ? null : _submit,
                    child: _loading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            _signUpMode ? 'Créer mon compte' : 'Se connecter',
                            style: hankenGrotesk(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(child: Divider(color: borderCol)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    'ou',
                    style: hankenGrotesk(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: mutedTextColor,
                    ),
                  ),
                ),
                Expanded(child: Divider(color: borderCol)),
              ],
            ),
            const SizedBox(height: 20),
            _OAuthButton(
              label: 'Continuer avec Google',
              icon: LucideIcons.globe,
              onTap: _loading
                  ? null
                  : () => _oauth(context.read<AuthService>().signInWithGoogle),
              cardBg: cardBg,
              borderCol: borderCol,
              primaryTextColor: primaryTextColor,
            ),
            const SizedBox(height: 12),
            _OAuthButton(
              label: 'Continuer avec Apple',
              icon: LucideIcons.apple,
              onTap: _loading
                  ? null
                  : () => _oauth(context.read<AuthService>().signInWithApple),
              cardBg: cardBg,
              borderCol: borderCol,
              primaryTextColor: primaryTextColor,
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeToggle extends StatelessWidget {
  final bool signUpMode;
  final ValueChanged<bool> onSelect;
  final Color accent;
  final Color cardBg;
  final Color borderCol;
  final Color mutedTextColor;

  const _ModeToggle({
    required this.signUpMode,
    required this.onSelect,
    required this.accent,
    required this.cardBg,
    required this.borderCol,
    required this.mutedTextColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderCol),
      ),
      child: Row(
        children: [
          _segment('Se connecter', !signUpMode, () => onSelect(false)),
          _segment('Créer un compte', signUpMode, () => onSelect(true)),
        ],
      ),
    );
  }

  Widget _segment(String label, bool selected, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? accent : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            label,
            style: hankenGrotesk(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : mutedTextColor,
            ),
          ),
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  final Color color;
  const _FieldLabel(this.text, this.color);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, left: 2),
      child: Text(
        text,
        style: hankenGrotesk(
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _AccountField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final bool obscure;
  final TextInputType? keyboardType;
  final Widget? suffix;
  final Color primaryTextColor;
  final Color mutedTextColor;
  final Color borderCol;

  const _AccountField({
    required this.controller,
    required this.hint,
    required this.icon,
    required this.primaryTextColor,
    required this.mutedTextColor,
    required this.borderCol,
    this.obscure = false,
    this.keyboardType,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      style: hankenGrotesk(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: primaryTextColor,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: hankenGrotesk(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: mutedTextColor,
        ),
        prefixIcon: Icon(icon, size: 18, color: mutedTextColor),
        suffixIcon: suffix,
        filled: true,
        fillColor: mutedTextColor.withValues(alpha: 0.06),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: borderCol),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF1B66F5), width: 1.5),
        ),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  final String text;
  final Color color;
  final IconData icon;
  const _Banner({required this.text, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: hankenGrotesk(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OAuthButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final Color cardBg;
  final Color borderCol;
  final Color primaryTextColor;

  const _OAuthButton({
    required this.label,
    required this.icon,
    required this.onTap,
    required this.cardBg,
    required this.borderCol,
    required this.primaryTextColor,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: cardBg,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderCol),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: primaryTextColor),
              const SizedBox(width: 12),
              Text(
                label,
                style: hankenGrotesk(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: primaryTextColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
