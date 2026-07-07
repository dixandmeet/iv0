import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import '../widgets/auth/auth_background.dart';
import '../widgets/auth/auth_palette.dart';
import '../widgets/auth/premium_auth_button.dart';
import '../widgets/auth/premium_auth_field.dart';

/// Connexion / inscription professionnelle (Aule Pro) — variante simple
/// **e-mail + mot de passe + matricule**.
///
/// La variante par code à usage unique (OTP) est conservée dans
/// `pro_login_screen_otp.dart` (mise de côté, non câblée) en attendant la
/// bascule SMS. Seuls les comptes conducteur / agent MSR sont acceptés
/// (contrôle dans [AuthService.signIn] / [AuthService.signUpDriver]).
class ProLoginScreen extends StatefulWidget {
  const ProLoginScreen({super.key});

  @override
  State<ProLoginScreen> createState() => _ProLoginScreenState();
}

class _ProLoginScreenState extends State<ProLoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _matriculeController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _passwordFocus = FocusNode();

  bool _isSignUp = false;
  bool _loading = false;
  bool _obscure = true;
  String? _error;
  String? _info;

  // Entrée en fondu/glissé au premier affichage : rend la transition depuis
  // le splash intentionnelle plutôt qu'un simple clignotement.
  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 620),
  )..forward();

  // Refus d'accès porté par AuthService (mode connexion seulement) : survit à
  // la reconstruction de l'écran après la déconnexion d'un compte non autorisé.
  String? get _accessDenial =>
      _isSignUp ? null : context.watch<AuthService>().accessDenialMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _matriculeController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _passwordFocus.dispose();
    _intro.dispose();
    super.dispose();
  }

  void _switchMode(bool signUp) {
    if (_isSignUp == signUp) return;
    context.read<AuthService>().clearAccessDenial();
    setState(() {
      _isSignUp = signUp;
      _error = null;
      _info = null;
    });
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    context.read<AuthService>().clearAccessDenial();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _loading = true;
      _error = null;
      _info = null;
    });

    final auth = context.read<AuthService>();
    if (_isSignUp) {
      final result = await auth.signUpDriver(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        employeeId: _matriculeController.text.trim(),
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
      );
      if (!mounted) return;
      setState(() => _loading = false);
      switch (result.status) {
        case DriverSignUpStatus.validated:
        case DriverSignUpStatus.pending:
          // ProRoot bascule (espace conducteur ou écran d'attente).
          break;
        case DriverSignUpStatus.alreadyUsed:
          setState(() => _error =
              'Cette immatriculation est déjà utilisée. Contactez votre exploitation.');
          break;
        case DriverSignUpStatus.emailConfirmationRequired:
          setState(() {
            _isSignUp = false;
            _info = 'Compte créé. Un e-mail de confirmation vous a été envoyé : '
                'cliquez sur le lien reçu, puis connectez-vous.';
          });
          break;
        case DriverSignUpStatus.error:
          setState(() => _error = result.message ?? 'Erreur d\'inscription');
          break;
      }
    } else {
      final err = await auth.signIn(
        _emailController.text.trim(),
        _passwordController.text,
      );
      if (!mounted) return;
      setState(() => _loading = false);
      if (err != null) setState(() => _error = err);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AuthPalette.background,
      body: Stack(
        children: [
          const Positioned.fill(child: AuthBackground()),
          SafeArea(
            child: Center(
              child: FadeTransition(
                opacity: CurvedAnimation(parent: _intro, curve: Curves.easeOut),
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.035),
                    end: Offset.zero,
                  ).animate(CurvedAnimation(
                      parent: _intro, curve: Curves.easeOutCubic)),
                  child: SingleChildScrollView(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 440),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildHeader(),
                            const SizedBox(height: 26),
                            _buildCard(),
                            const SizedBox(height: 18),
                            const _FooterTrust(),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        SizedBox(
          width: 100,
          height: 100,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AuthPalette.sage.withValues(alpha: 0.16),
                ),
              ),
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  // Rayon des coins déjà arrondis du logo (≈ 21 % du côté),
                  // pour que l'ombre épouse sa silhouette.
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    BoxShadow(
                      color: AuthPalette.forest.withValues(alpha: 0.35),
                      blurRadius: 22,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Image.asset(
                  'assets/images/aule_pro_logo.png',
                  width: 68,
                  height: 68,
                  filterQuality: FilterQuality.medium,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Aule Pro',
          style: TextStyle(
            fontSize: 29,
            fontWeight: FontWeight.w800,
            color: AuthPalette.ink,
            letterSpacing: -0.7,
          ),
        ),
        const SizedBox(height: 10),
        const _TrustBadge(),
      ],
    );
  }

  Widget _buildCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: Colors.white.withValues(alpha: 0.85)),
        boxShadow: [
          BoxShadow(
            color: AuthPalette.forestDeep.withValues(alpha: 0.12),
            blurRadius: 32,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildModeToggle(),
          const SizedBox(height: 18),
          if (_error != null) ...[
            _ErrorBanner(message: _error!),
            const SizedBox(height: 14),
          ],
          if (_error == null && _accessDenial != null) ...[
            _ErrorBanner(message: _accessDenial!),
            const SizedBox(height: 14),
          ],
          if (_info != null) ...[
            _InfoBanner(message: _info!),
            const SizedBox(height: 14),
          ],
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              transitionBuilder: (child, anim) =>
                  FadeTransition(opacity: anim, child: child),
              child: Column(
                key: ValueKey(_isSignUp),
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: _isSignUp ? _buildSignUpFields() : _buildLoginFields(),
              ),
            ),
          ),
          const SizedBox(height: 20),
          PremiumAuthButton(
            label: _isSignUp ? 'Créer mon compte' : 'Se connecter',
            icon: _isSignUp ? LucideIcons.userPlus : LucideIcons.arrowRight,
            loading: _loading,
            onTap: _loading ? null : _submit,
          ),
          const SizedBox(height: 14),
          _buildSwitchLink(),
        ],
      ),
    );
  }

  List<Widget> _buildLoginFields() {
    return [
      PremiumAuthField(
        label: 'Email professionnel',
        icon: LucideIcons.mail,
        hint: 'prenom.nom@semitan.fr',
        controller: _emailController,
        keyboardType: TextInputType.emailAddress,
        textInputAction: TextInputAction.next,
        autocorrect: false,
        enabled: !_loading,
        onFieldSubmitted: (_) => _passwordFocus.requestFocus(),
        validator: _emailValidator,
      ),
      const SizedBox(height: 16),
      _passwordField(),
    ];
  }

  List<Widget> _buildSignUpFields() {
    return [
      PremiumAuthField(
        label: 'Matricule (immatriculation)',
        icon: LucideIcons.idCard,
        hint: 'Ex. 1234',
        controller: _matriculeController,
        textInputAction: TextInputAction.next,
        autocorrect: false,
        enabled: !_loading,
        textCapitalization: TextCapitalization.characters,
        validator: (v) =>
            (v == null || v.trim().isEmpty) ? 'Matricule requis' : null,
      ),
      const SizedBox(height: 16),
      PremiumAuthField(
        label: 'Prénom',
        icon: LucideIcons.user,
        hint: 'Prénom',
        controller: _firstNameController,
        textInputAction: TextInputAction.next,
        enabled: !_loading,
        textCapitalization: TextCapitalization.words,
        validator: (v) =>
            (v == null || v.trim().isEmpty) ? 'Prénom requis' : null,
      ),
      const SizedBox(height: 16),
      PremiumAuthField(
        label: 'Nom',
        icon: LucideIcons.user,
        hint: 'Nom',
        controller: _lastNameController,
        textInputAction: TextInputAction.next,
        enabled: !_loading,
        textCapitalization: TextCapitalization.words,
        validator: (v) =>
            (v == null || v.trim().isEmpty) ? 'Nom requis' : null,
      ),
      const SizedBox(height: 16),
      PremiumAuthField(
        label: 'Email professionnel',
        icon: LucideIcons.mail,
        hint: 'prenom.nom@semitan.fr',
        controller: _emailController,
        keyboardType: TextInputType.emailAddress,
        textInputAction: TextInputAction.next,
        autocorrect: false,
        enabled: !_loading,
        onFieldSubmitted: (_) => _passwordFocus.requestFocus(),
        validator: (v) {
          final base = _emailValidator(v);
          if (base != null) return base;
          if (!v!.trim().toLowerCase().endsWith('@semitan.fr')) {
            return 'Seules les adresses @semitan.fr sont autorisées';
          }
          return null;
        },
      ),
      const SizedBox(height: 16),
      _passwordField(),
      const SizedBox(height: 12),
      const _HintNote(
        'Saisissez votre matricule pour valider votre accès. S\'il n\'est pas '
        'reconnu, votre demande sera vérifiée par l\'exploitation.',
      ),
    ];
  }

  Widget _passwordField() {
    return PremiumAuthField(
      label: 'Mot de passe',
      icon: LucideIcons.lockKeyhole,
      hint: '••••••••',
      controller: _passwordController,
      focusNode: _passwordFocus,
      obscureText: _obscure,
      enabled: !_loading,
      textInputAction: TextInputAction.done,
      onFieldSubmitted: (_) => _submit(),
      suffix: PasswordVisibilityToggle(
        obscured: _obscure,
        onPressed: () => setState(() => _obscure = !_obscure),
      ),
      validator: (v) {
        if (v == null || v.isEmpty) return 'Mot de passe requis';
        if (_isSignUp && v.length < 6) return '6 caractères minimum';
        return null;
      },
    );
  }

  String? _emailValidator(String? v) {
    final value = v?.trim() ?? '';
    if (value.isEmpty) return 'Email requis';
    if (!value.contains('@')) return 'Email invalide';
    return null;
  }

  Widget _buildModeToggle() {
    Widget tab(String label, bool signUp) {
      final selected = _isSignUp == signUp;
      return Expanded(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _loading ? null : () => _switchMode(signUp),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(vertical: 11),
            decoration: BoxDecoration(
              color: selected ? Colors.white : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: AuthPalette.forestDeep.withValues(alpha: 0.14),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: selected
                    ? AuthPalette.forestDeep
                    : AuthPalette.forest.withValues(alpha: 0.75),
              ),
              child: Text(label, textAlign: TextAlign.center),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AuthPalette.background,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(children: [tab('Connexion', false), tab('Inscription', true)]),
    );
  }

  Widget _buildSwitchLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          _isSignUp ? 'Vous avez déjà un compte ?' : 'Pas encore de compte ?',
          style: const TextStyle(fontSize: 13, color: AuthPalette.ink),
        ),
        TextButton(
          onPressed: _loading ? null : () => _switchMode(!_isSignUp),
          style: TextButton.styleFrom(
            foregroundColor: AuthPalette.forest,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            minimumSize: const Size(0, 0),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Text(
            _isSignUp ? 'Se connecter' : 'S\'inscrire',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }
}

/// Pastille glassy « ESPACE CONDUCTEUR & AGENT MSR », sous le titre.
class _TrustBadge extends StatelessWidget {
  const _TrustBadge();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 280),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AuthPalette.sage.withValues(alpha: 0.5),
            ),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(LucideIcons.shieldCheck, size: 12.5, color: AuthPalette.forest),
              SizedBox(width: 7),
              Flexible(
                child: Text(
                  "L'application des professionnels du transport",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.1,
                    color: AuthPalette.forestDeep,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Mention de réassurance en pied d'écran.
class _FooterTrust extends StatelessWidget {
  const _FooterTrust();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(LucideIcons.lock,
                size: 12, color: AuthPalette.forestDeep.withValues(alpha: 0.55)),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              'Connexion sécurisée — accès réservé aux conducteurs et agents MSR',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AuthPalette.forestDeep.withValues(alpha: 0.55),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFDECEC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF5C2C2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(LucideIcons.circleAlert,
              size: 18, color: AuthPalette.danger),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                  fontSize: 12.5, height: 1.35, color: Color(0xFF8E2A1F)),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  final String message;
  const _InfoBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F3EC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFB8DCC4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(LucideIcons.circleCheck,
              size: 18, color: AuthPalette.success),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                  fontSize: 12.5, height: 1.35, color: Color(0xFF24603F)),
            ),
          ),
        ],
      ),
    );
  }
}

class _HintNote extends StatelessWidget {
  final String text;
  const _HintNote(this.text);

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(LucideIcons.info,
            size: 14, color: AuthPalette.forestDeep.withValues(alpha: 0.7)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
                fontSize: 11.5,
                height: 1.35,
                color: AuthPalette.forestDeep.withValues(alpha: 0.8)),
          ),
        ),
      ],
    );
  }
}
