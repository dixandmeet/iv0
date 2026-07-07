import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';

/// Connexion professionnelle (Aule Pro). Seuls les comptes conducteur ou
/// agent MSR sont acceptés (contrôle dans [AuthService.signIn]).
///
/// Design épuré « espace pro » fidèle à la maquette : pastille de promesse en
/// haut, scène urbaine stylisée (skyline + tracé GPS pointillé animé avec
/// épingles), logo, titre, badge de confiance, puis carte de connexion claire
/// et bandeau de réassurance en pied de page.
class ProLoginScreenOtp extends StatefulWidget {
  const ProLoginScreenOtp({super.key});

  @override
  State<ProLoginScreenOtp> createState() => _ProLoginScreenState();
}

class _ProLoginScreenState extends State<ProLoginScreenOtp>
    with TickerProviderStateMixin {
  // Palette « vert sauge » premium.
  static const _sage = Color(0xFF9FC8A9); // vert sauge doux
  static const _forest = Color(0xFF5E8B7E); // vert forêt léger
  static const _forestDeep = Color(0xFF3F6457); // vert profond (texte)
  static const _bg = Color(0xFFEAF2EC); // fond vert très clair
  static const _ink = Color(0xFF14241C); // noir vert profond

  // Longueur du code OTP (doit correspondre au réglage Auth du projet Supabase).
  static const int _otpLength = 8;

  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();

  // Inscription (mode « S'inscrire »).
  final _matriculeController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _matriculeFocus = FocusNode();

  // Connexion/inscription par code à usage unique (OTP) reçu par e-mail.
  final _otpController = TextEditingController();
  final _otpFocus = FocusNode();

  bool _isSignUp = false;
  bool _loading = false;
  String? _error;
  String? _info; // message de succès/information (ex. code envoyé)

  // Étape « saisie du code » : le code a été envoyé, on attend sa vérification.
  bool _otpSent = false;
  String _otpEmail = ''; // adresse à laquelle le code a été envoyé

  // Anti-spam : compte à rebours avant de pouvoir renvoyer un code.
  Timer? _resendTimer;
  int _resendIn = 0;

  // Vérification live du matricule.
  Timer? _matriculeDebounce;
  bool _checkingMatricule = false;
  MatriculeCheck? _matriculeCheck;

  // Le nom n'est demandé que si le matricule n'est pas reconnu (sinon il est
  // déjà connu via l'immatriculation) ou si la vérification a échoué.
  bool get _needsIdentity =>
      _matriculeCheck?.status == MatriculeStatus.unknown ||
      _matriculeCheck?.status == MatriculeStatus.error;

  // Animations : entrée en fondu/glissé + flux GPS le long du tracé.
  late final AnimationController _introController;
  late final AnimationController _flowController;

  @override
  void initState() {
    super.initState();
    _introController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
    _flowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _matriculeController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _matriculeFocus.dispose();
    _otpController.dispose();
    _otpFocus.dispose();
    _matriculeDebounce?.cancel();
    _resendTimer?.cancel();
    _introController.dispose();
    _flowController.dispose();
    super.dispose();
  }

  void _switchMode(bool signUp) {
    if (_isSignUp == signUp) return;
    context.read<AuthService>().clearAccessDenial();
    setState(() {
      _isSignUp = signUp;
      _error = null;
      _info = null;
      // On repart de l'étape « saisie » à chaque changement de mode.
      _resetOtpStep();
    });
  }

  // Réinitialise l'étape de saisie du code (revient au premier écran).
  void _resetOtpStep() {
    _otpSent = false;
    _otpEmail = '';
    _otpController.clear();
    _resendTimer?.cancel();
    _resendIn = 0;
  }

  // ----------------------------------------------------------------------
  // E-mail professionnel dérivé de l'identité (1re lettre prénom + nom).
  // Reconnu via le roster → identité du matricule ; sinon → identité saisie.
  // ----------------------------------------------------------------------
  // Message de refus d'accès porté par AuthService (mode connexion seulement).
  String? get _accessDenial =>
      _isSignUp ? null : context.watch<AuthService>().accessDenialMessage;

  String? get _signUpEmail {
    if (_matriculeCheck?.status == MatriculeStatus.available) {
      return AuthService.deriveProEmail(
          _matriculeCheck!.firstName, _matriculeCheck!.lastName);
    }
    if (_needsIdentity) {
      return AuthService.deriveProEmail(
          _firstNameController.text, _lastNameController.text);
    }
    return null;
  }

  // Métadonnées de compte transmises lors de l'envoi du code d'inscription.
  Map<String, dynamic> _signUpMetadata() {
    final recognized = _matriculeCheck?.status == MatriculeStatus.available;
    final first =
        (recognized ? _matriculeCheck?.firstName : _firstNameController.text) ??
            '';
    final last =
        (recognized ? _matriculeCheck?.lastName : _lastNameController.text) ?? '';
    final display = [first, last]
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .join(' ');
    return {
      'signup_type': 'driver',
      'employee_id': _matriculeController.text.trim(),
      if (first.trim().isNotEmpty) 'first_name': first.trim(),
      if (last.trim().isNotEmpty) 'last_name': last.trim(),
      if (display.isNotEmpty) 'display_name': display,
    };
  }

  void _startResendCooldown([int seconds = 60]) {
    _resendTimer?.cancel();
    setState(() => _resendIn = seconds);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      if (_resendIn <= 1) {
        t.cancel();
        setState(() => _resendIn = 0);
      } else {
        setState(() => _resendIn--);
      }
    });
  }

  // Action du bouton principal : envoi du code (étape 1) ou vérification du
  // code (étape 2).
  Future<void> _submit() => _otpSent ? _verifyOtp() : _requestOtp();

  // Étape 1 : valide le formulaire puis envoie un code OTP à l'adresse cible.
  // Connexion → e-mail saisi ; inscription → e-mail dérivé du matricule.
  Future<void> _requestOtp() async {
    FocusScope.of(context).unfocus();
    context.read<AuthService>().clearAccessDenial();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    late final String email;
    var createUser = false;
    Map<String, dynamic>? data;

    if (_isSignUp) {
      if (_matriculeCheck?.status == MatriculeStatus.alreadyUsed) {
        setState(() => _error =
            'Cette immatriculation est déjà utilisée. Contactez votre exploitation.');
        return;
      }
      final derived = _signUpEmail;
      if (derived == null) {
        setState(() => _error =
            'Impossible de déterminer votre adresse e-mail. Vérifiez votre identité.');
        return;
      }
      email = derived;
      createUser = true;
      data = _signUpMetadata();
    } else {
      email = _emailController.text.trim().toLowerCase();
    }

    setState(() {
      _loading = true;
      _error = null;
      _info = null;
    });

    final err = await context
        .read<AuthService>()
        .sendEmailOtp(email, createUser: createUser, data: data);

    if (!mounted) return;
    setState(() => _loading = false);

    if (err != null) {
      setState(() => _error = err);
      return;
    }

    setState(() {
      _otpSent = true;
      _otpEmail = email;
      _otpController.clear();
      _info = 'Code envoyé à $email. Vérifiez votre boîte de réception.';
    });
    _startResendCooldown();
    _otpFocus.requestFocus();
  }

  // Étape 2 : vérifie le code saisi, puis finalise l'accès selon le mode.
  Future<void> _verifyOtp() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _loading = true;
      _error = null;
      _info = null;
    });

    final auth = context.read<AuthService>();
    final err = await auth.verifyEmailOtp(_otpEmail, _otpController.text.trim());
    if (!mounted) return;

    if (err != null) {
      setState(() {
        _loading = false;
        _error = err;
      });
      return;
    }

    // Session établie. Inscription → revendication du matricule ;
    // connexion → contrôle d'accès terrain. ProRoot bascule ensuite.
    if (_isSignUp) {
      final result =
          await auth.claimDriverAccess(employeeId: _matriculeController.text.trim());
      if (!mounted) return;
      setState(() => _loading = false);
      switch (result.status) {
        case DriverSignUpStatus.validated:
        case DriverSignUpStatus.pending:
          // ProRoot bascule (espace conducteur ou écran d'attente).
          break;
        case DriverSignUpStatus.alreadyUsed:
          setState(() {
            _error =
                'Cette immatriculation est déjà utilisée. Contactez votre exploitation.';
            _resetOtpStep();
          });
          break;
        case DriverSignUpStatus.emailConfirmationRequired:
        case DriverSignUpStatus.error:
          setState(() => _error = result.message ?? 'Erreur d\'inscription');
          break;
      }
    } else {
      final accessErr = await auth.ensureMobileStaffAccess();
      if (!mounted) return;
      setState(() => _loading = false);
      if (accessErr != null) {
        setState(() {
          _error = accessErr;
          _resetOtpStep();
        });
      }
    }
  }

  // Renvoi d'un nouveau code (même destinataire / mêmes métadonnées).
  Future<void> _resendOtp() async {
    if (_resendIn > 0 || _loading) return;
    setState(() {
      _error = null;
      _info = null;
    });
    final err = await context.read<AuthService>().sendEmailOtp(
          _otpEmail,
          createUser: _isSignUp,
          data: _isSignUp ? _signUpMetadata() : null,
        );
    if (!mounted) return;
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    setState(() => _info = 'Nouveau code envoyé à $_otpEmail.');
    _startResendCooldown();
  }

  // Vérification live du matricule (anti-rebond) : statut + nom du titulaire.
  void _onMatriculeChanged(String value) {
    _matriculeDebounce?.cancel();
    final mat = value.trim();
    if (mat.isEmpty) {
      setState(() {
        _matriculeCheck = null;
        _checkingMatricule = false;
      });
      return;
    }
    setState(() => _checkingMatricule = true);
    _matriculeDebounce = Timer(const Duration(milliseconds: 500), () async {
      final result = await context.read<AuthService>().checkMatricule(mat);
      if (!mounted || _matriculeController.text.trim() != mat) return;
      // On ne révèle pas l'identité du titulaire : seul le statut (icône)
      // est affiché à côté du champ.
      setState(() {
        _matriculeCheck = result;
        _checkingMatricule = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);

    return Scaffold(
      backgroundColor: _bg,
      resizeToAvoidBottomInset: true,
      // Le réglage « grande police » du système peut agrandir tout le texte
      // jusqu'au débordement : on borne l'échelle pour un rendu maîtrisé.
      body: MediaQuery.withClampedTextScaling(
        maxScaleFactor: 1.1,
        child: Stack(
          children: [
            // Fond : photo Citadis atténuée + dégradé clair + skyline.
            const Positioned.fill(child: _LoginBackground()),

            // Contenu défilable.
            SafeArea(
              bottom: false,
              child: FadeTransition(
                opacity: CurvedAnimation(
                  parent: _introController,
                  curve: Curves.easeOut,
                ),
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.03),
                    end: Offset.zero,
                  ).animate(CurvedAnimation(
                    parent: _introController,
                    curve: Curves.easeOutCubic,
                  )),
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      20,
                      8,
                      20,
                      media.padding.bottom + 20,
                    ),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 460),
                      child: Center(
                        child: Form(
                          key: _formKey,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildHero(),
                              const SizedBox(height: 14),
                              _buildLoginCard(),
                              const SizedBox(height: 6),
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
      ),
    );
  }

  // ----------------------------------------------------------------------
  // Hero : pastille promesse + scène GPS animée + logo + titre + badge
  // ----------------------------------------------------------------------
  Widget _buildHero() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 190,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Scène : skyline stylisée + tracé GPS pointillé animé.
              Positioned.fill(
                child: RepaintBoundary(
                  child: AnimatedBuilder(
                    animation: _flowController,
                    builder: (context, _) => CustomPaint(
                      painter: _HeroScenePainter(progress: _flowController.value),
                    ),
                  ),
                ),
              ),

              // Pastille de promesse, en haut à gauche.
              const Positioned(
                top: 4,
                left: 0,
                child: _SoftPill(text: 'Trajets optimisés,\nvoyageurs informés.'),
              ),

              // Épingles de la scène (horloge, voyageurs, position).
              const Positioned(
                top: 0,
                right: 6,
                child: _ScenePin(icon: LucideIcons.clock, size: 28),
              ),
              const Positioned(
                top: 52,
                right: 24,
                child: _ScenePin(icon: LucideIcons.users, size: 34),
              ),
              const Positioned(
                top: 72,
                left: 4,
                child: _ScenePin(icon: LucideIcons.mapPin, size: 30),
              ),

              // Logo + titre + sous-titre, ancrés en bas de la scène.
              Align(
                alignment: Alignment.bottomCenter,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 62,
                      height: 62,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [_sage, _forest],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: _forest.withValues(alpha: 0.40),
                            blurRadius: 20,
                            offset: const Offset(0, 9),
                          ),
                        ],
                      ),
                      child: const Icon(LucideIcons.busFront,
                          color: Colors.white, size: 32),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Aule Pro',
                      style: TextStyle(
                        fontSize: 27,
                        fontWeight: FontWeight.w800,
                        color: _ink,
                        letterSpacing: -0.8,
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(height: 5),
                    const Text(
                      'ESPACE CONDUCTEUR & AGENT MSR',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        color: _forest,
                        letterSpacing: 1.6,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ----------------------------------------------------------------------
  // Carte de connexion (claire)
  // ----------------------------------------------------------------------
  Widget _buildLoginCard() {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.9)),
        boxShadow: [
          BoxShadow(
            color: _forestDeep.withValues(alpha: 0.12),
            blurRadius: 32,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // --- Bascule Connexion / Inscription ---
          _buildModeToggle(),
          const SizedBox(height: 16),

          if (_error != null) ...[
            _ErrorBanner(message: _error!),
            const SizedBox(height: 14),
          ],
          // Refus d'accès porté par AuthService (survit à la reconstruction de
          // l'écran après la déconnexion d'un compte non autorisé).
          if (_error == null && _accessDenial != null) ...[
            _ErrorBanner(message: _accessDenial!),
            const SizedBox(height: 14),
          ],
          if (_info != null) ...[
            _InfoBanner(message: _info!),
            const SizedBox(height: 14),
          ],

          // --- Étape 1 : saisie / Étape 2 : code reçu par e-mail ---
          if (!_otpSent)
            ...(_isSignUp ? _buildSignUpEntry() : _buildLoginEntry())
          else
            ..._buildOtpEntry(),
          const SizedBox(height: 16),

          // --- Bouton principal ---
          _buildPrimaryButton(),
          const SizedBox(height: 12),

          // --- Bascule textuelle bas de carte ---
          _buildSwitchLink(),
        ],
      ),
    );
  }

  // ----------------------------------------------------------------------
  // Étape 1 — Connexion : e-mail → envoi du code
  // ----------------------------------------------------------------------
  List<Widget> _buildLoginEntry() {
    return [
      _fieldLabel('Email professionnel', LucideIcons.circleUser),
      const SizedBox(height: 6),
      TextFormField(
        controller: _emailController,
        keyboardType: TextInputType.emailAddress,
        textInputAction: TextInputAction.done,
        autocorrect: false,
        enabled: !_loading,
        onFieldSubmitted: (_) => _submit(),
        decoration: _decoration(
          hint: 'prenom.nom@semitan.fr',
          icon: LucideIcons.mail,
        ),
        validator: (v) {
          final value = v?.trim().toLowerCase() ?? '';
          if (value.isEmpty) return 'Email requis';
          if (!value.contains('@')) return 'Email invalide';
          return null;
        },
      ),
      const SizedBox(height: 10),
      _HintNote(
        icon: LucideIcons.mailCheck,
        text: 'Un code de connexion à usage unique vous sera envoyé par '
            'e-mail. Aucun mot de passe n\'est nécessaire.',
      ),
    ];
  }

  // ----------------------------------------------------------------------
  // Étape 1 — Inscription : matricule (→ e-mail dérivé) → envoi du code
  // ----------------------------------------------------------------------
  List<Widget> _buildSignUpEntry() {
    final derivedEmail = _signUpEmail;
    return [
      _fieldLabel('Matricule (immatriculation)', LucideIcons.idCard),
      const SizedBox(height: 6),
      TextFormField(
        controller: _matriculeController,
        keyboardType: TextInputType.text,
        textInputAction: TextInputAction.next,
        autocorrect: false,
        enabled: !_loading,
        textCapitalization: TextCapitalization.characters,
        onChanged: _onMatriculeChanged,
        decoration: _decoration(
          hint: 'Ex. 1234',
          icon: LucideIcons.badgeCheck,
          suffix: _matriculeSuffix(),
        ),
        validator: (v) =>
            (v == null || v.trim().isEmpty) ? 'Matricule requis' : null,
      ),
      const SizedBox(height: 12),

      // Identité demandée uniquement si le matricule n'est pas reconnu.
      // Si l'immatriculation est connue, le nom est déjà associé côté
      // exploitation : inutile (et indiscret) de le redemander.
      if (_needsIdentity) ...[
        _IdentityNote(),
        const SizedBox(height: 10),
        // Prénom et nom sur deux lignes distinctes.
        _fieldLabel('Prénom', LucideIcons.user),
        const SizedBox(height: 6),
        TextFormField(
          controller: _firstNameController,
          textInputAction: TextInputAction.next,
          enabled: !_loading,
          textCapitalization: TextCapitalization.words,
          onChanged: (_) => setState(() {}),
          decoration: _decoration(hint: 'Prénom', icon: LucideIcons.user),
          validator: (v) =>
              (v == null || v.trim().isEmpty) ? 'Prénom requis' : null,
        ),
        const SizedBox(height: 12),
        _fieldLabel('Nom', LucideIcons.user),
        const SizedBox(height: 6),
        TextFormField(
          controller: _lastNameController,
          textInputAction: TextInputAction.next,
          enabled: !_loading,
          textCapitalization: TextCapitalization.words,
          onChanged: (_) => setState(() {}),
          decoration: _decoration(hint: 'Nom', icon: LucideIcons.user),
          validator: (v) =>
              (v == null || v.trim().isEmpty) ? 'Nom requis' : null,
        ),
        const SizedBox(height: 12),
      ],

      // Adresse e-mail dérivée automatiquement (1re lettre prénom + nom).
      // L'utilisateur n'a pas à la saisir : le code y sera envoyé.
      if (derivedEmail != null) ...[
        _DerivedEmailField(email: derivedEmail),
        const SizedBox(height: 12),
      ],

      _HintNote(
        icon: LucideIcons.info,
        text: 'Votre matricule valide automatiquement votre accès. S\'il '
            'n\'est pas reconnu, votre demande sera vérifiée par '
            'l\'exploitation. Un code à usage unique vous sera envoyé pour '
            'activer votre compte — aucun mot de passe requis.',
      ),
    ];
  }

  // ----------------------------------------------------------------------
  // Étape 2 — Saisie du code reçu par e-mail
  // ----------------------------------------------------------------------
  List<Widget> _buildOtpEntry() {
    return [
      // Rappel de la destination + retour à l'étape précédente.
      Row(
        children: [
          const Icon(LucideIcons.mailCheck, size: 16, color: _forest),
          const SizedBox(width: 7),
          Expanded(
            child: Text.rich(
              TextSpan(
                style: const TextStyle(fontSize: 12.5, color: _ink, height: 1.3),
                children: [
                  const TextSpan(text: 'Code envoyé à '),
                  TextSpan(
                    text: _otpEmail,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
          ),
          TextButton(
            onPressed: _loading ? null : () => setState(_resetOtpStep),
            style: TextButton.styleFrom(
              foregroundColor: _forest,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              minimumSize: const Size(0, 0),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text(
              'Modifier',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
      const SizedBox(height: 14),
      _fieldLabel('Code à $_otpLength chiffres', LucideIcons.keyRound),
      const SizedBox(height: 6),
      TextFormField(
        controller: _otpController,
        focusNode: _otpFocus,
        keyboardType: TextInputType.number,
        textInputAction: TextInputAction.done,
        enabled: !_loading,
        autofocus: true,
        maxLength: _otpLength,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w800,
          letterSpacing: 8,
          color: _ink,
        ),
        decoration: _decoration(
          hint: '•' * _otpLength,
          icon: LucideIcons.lockKeyhole,
        ).copyWith(counterText: ''),
        onChanged: (v) {
          // Vérification automatique dès que le code complet est saisi.
          if (v.trim().length == _otpLength && !_loading) _submit();
        },
        onFieldSubmitted: (_) => _submit(),
        validator: (v) {
          final t = v?.trim() ?? '';
          if (t.isEmpty) return 'Code requis';
          if (t.length < _otpLength) {
            return 'Le code comporte $_otpLength chiffres';
          }
          return null;
        },
      ),
      const SizedBox(height: 2),
      Row(
        children: [
          const Expanded(
            child: Text(
              'Vous n\'avez rien reçu ?',
              style: TextStyle(fontSize: 12, color: _forestDeep),
            ),
          ),
          TextButton(
            onPressed: (_resendIn > 0 || _loading) ? null : _resendOtp,
            style: TextButton.styleFrom(
              foregroundColor: _forest,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              minimumSize: const Size(0, 0),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              _resendIn > 0 ? 'Renvoyer ($_resendIn s)' : 'Renvoyer le code',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    ];
  }

  // Segmented control « Connexion / Inscription ».
  Widget _buildModeToggle() {
    Widget tab(String label, bool signUp) {
      final selected = _isSignUp == signUp;
      return Expanded(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _loading ? null : () => _switchMode(signUp),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: selected ? Colors.white : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: _forestDeep.withValues(alpha: 0.12),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: selected ? _forestDeep : _forest.withValues(alpha: 0.8),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF5F0),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _sage.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          tab('Connexion', false),
          tab('Inscription', true),
        ],
      ),
    );
  }

  Widget _buildSwitchLink() {
    return Center(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _loading ? null : () => _switchMode(!_isSignUp),
        child: Text.rich(
          TextSpan(
            style: const TextStyle(fontSize: 12.5, color: _ink),
            children: [
              TextSpan(
                text: _isSignUp
                    ? 'Vous avez déjà un compte ? '
                    : 'Pas encore de compte ? ',
              ),
              TextSpan(
                text: _isSignUp ? 'Se connecter' : 'S\'inscrire',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: _forest,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Suffixe du champ matricule : spinner pendant la vérif, icône de statut sinon.
  Widget? _matriculeSuffix() {
    if (_checkingMatricule) {
      return const Padding(
        padding: EdgeInsets.all(14),
        child: SizedBox(
          height: 16,
          width: 16,
          child: CircularProgressIndicator(strokeWidth: 2, color: _forest),
        ),
      );
    }
    final status = _matriculeCheck?.status;
    if (status == null) return null;

    late final IconData icon;
    late final Color color;
    late final String tip;
    switch (status) {
      case MatriculeStatus.available:
        icon = LucideIcons.circleCheck;
        color = const Color(0xFF3F8E5B);
        tip = 'Matricule reconnu — accès validé.';
        break;
      case MatriculeStatus.alreadyUsed:
        icon = LucideIcons.circleX;
        color = const Color(0xFFD64545);
        tip = 'Immatriculation déjà utilisée — inscription refusée.';
        break;
      case MatriculeStatus.unknown:
        icon = LucideIcons.clock;
        color = const Color(0xFFC9871F);
        tip = 'Matricule inconnu — demande mise en vérification.';
        break;
      case MatriculeStatus.error:
        return null;
    }

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Tooltip(
        message: tip,
        triggerMode: TooltipTriggerMode.tap,
        child: Icon(icon, size: 20, color: color),
      ),
    );
  }

  // Libellé / icône du bouton principal selon l'étape et le mode.
  String get _primaryLabel {
    if (!_otpSent) return 'Recevoir le code';
    return _isSignUp ? 'Créer mon compte' : 'Se connecter';
  }

  IconData get _primaryIcon {
    if (!_otpSent) return LucideIcons.send;
    return _isSignUp ? LucideIcons.userPlus : LucideIcons.arrowRight;
  }

  // Bouton vert sauge plein : flèche circulaire blanche + texte blanc.
  Widget _buildPrimaryButton() {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: _loading ? null : _submit,
        child: Ink(
          height: 52,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF9BC4A4), Color(0xFF6E9E83)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: _forest.withValues(alpha: 0.36),
                blurRadius: 18,
                offset: const Offset(0, 9),
              ),
            ],
          ),
          child: Center(
            child: _loading
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: Colors.white,
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.85),
                            width: 1.5,
                          ),
                        ),
                        child: Icon(_primaryIcon,
                            color: Colors.white, size: 16),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        _primaryLabel,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  // ----------------------------------------------------------------------
  // Helpers UI
  // ----------------------------------------------------------------------
  Widget _fieldLabel(String text, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 15, color: _forest),
        const SizedBox(width: 7),
        Text(
          text,
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: _ink,
          ),
        ),
      ],
    );
  }

  InputDecoration _decoration({
    required String hint,
    required IconData icon,
    Widget? suffix,
  }) {
    OutlineInputBorder border(Color c, double w) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: c, width: w),
        );
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF9AA8A0)),
      prefixIcon: Icon(icon, size: 18, color: _forest),
      suffixIcon: suffix,
      filled: true,
      fillColor: const Color(0xFFF4F8F5),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      enabledBorder: border(_sage.withValues(alpha: 0.45), 1.2),
      focusedBorder: border(_forest, 1.8),
      errorBorder: border(const Color(0xFFD64545), 1),
      focusedErrorBorder: border(const Color(0xFFD64545), 1.6),
    );
  }
}

// ========================================================================
// Fond : dégradé clair + skyline atténuée en pied d'écran
// ========================================================================
class _LoginBackground extends StatelessWidget {
  const _LoginBackground();

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Stack(
      fit: StackFit.expand,
      children: [
        // Dégradé de base.
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFFF3F8F4),
                Color(0xFFEAF2EC),
                Color(0xFFE3EEE6),
              ],
              stops: [0.0, 0.5, 1.0],
            ),
          ),
        ),

        // Photo du Citadis Naolib, très atténuée, en haut d'écran.
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: size.height * 0.46,
          child: Opacity(
            opacity: 0.16,
            child: Image.asset(
              'assets/images/citadis_naolib.jpg',
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
            ),
          ),
        ),

        // Voile clair pour fondre la photo dans le dégradé.
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                const Color(0xFFF3F8F4).withValues(alpha: 0.55),
                const Color(0xFFEAF2EC).withValues(alpha: 0.80),
                const Color(0xFFEAF2EC),
              ],
              stops: const [0.0, 0.40, 0.60],
            ),
          ),
        ),

        // Skyline atténuée en pied d'écran.
        Align(
          alignment: Alignment.bottomCenter,
          child: CustomPaint(
            size: const Size(double.infinity, 100),
            painter: _SkylinePainter(),
          ),
        ),
      ],
    );
  }
}

/// Silhouette de ville + bus, très atténuée, posée en bas d'écran.
class _SkylinePainter extends CustomPainter {
  static const _sage = Color(0xFF9FC8A9);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = _sage.withValues(alpha: 0.16);
    final base = size.height;

    // Immeubles de hauteurs variées.
    const heights = [38.0, 62.0, 30.0, 80.0, 48.0, 70.0, 34.0, 56.0, 42.0];
    final slot = size.width / heights.length;
    for (int i = 0; i < heights.length; i++) {
      final x = i * slot;
      final h = heights[i];
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          Rect.fromLTWH(x + 4, base - h, slot - 8, h),
          topLeft: const Radius.circular(3),
          topRight: const Radius.circular(3),
        ),
        paint,
      );
    }

    // Ligne de sol.
    canvas.drawRect(
      Rect.fromLTWH(0, base - 3, size.width, 3),
      Paint()..color = _sage.withValues(alpha: 0.22),
    );

    // Petit bus stylisé.
    final busPaint = Paint()..color = _sage.withValues(alpha: 0.30);
    final bx = size.width * 0.62;
    final by = base - 22;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(bx, by, 64, 19), const Radius.circular(5)),
      busPaint,
    );
    final wheel = Paint()..color = _sage.withValues(alpha: 0.45);
    canvas.drawCircle(Offset(bx + 14, by + 19), 3.4, wheel);
    canvas.drawCircle(Offset(bx + 50, by + 19), 3.4, wheel);
  }

  @override
  bool shouldRepaint(_SkylinePainter oldDelegate) => false;
}

// ========================================================================
// Scène hero : skyline + tracé GPS pointillé animé reliant les épingles
// ========================================================================
class _HeroScenePainter extends CustomPainter {
  final double progress; // 0 → 1, en boucle
  _HeroScenePainter({required this.progress});

  static const _forest = Color(0xFF5E8B7E);
  static const _sage = Color(0xFF9FC8A9);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Tracé organique reliant les épingles (position → horloge → voyageurs).
    final path = Path()
      ..moveTo(w * 0.10, h * 0.46)
      ..cubicTo(
          w * 0.18, h * 0.18, w * 0.42, h * 0.20, w * 0.55, h * 0.30)
      ..cubicTo(
          w * 0.70, h * 0.42, w * 0.80, h * 0.12, w * 0.90, h * 0.16);

    // Tracé en pointillés.
    _drawDashed(canvas, path, _forest.withValues(alpha: 0.30), 2.0);

    // Points lumineux qui circulent le long du tracé.
    for (final metric in path.computeMetrics()) {
      for (int d = 0; d < 3; d++) {
        final t = (progress + d / 3) % 1.0;
        final pos = metric.getTangentForOffset(metric.length * t)?.position;
        if (pos == null) continue;
        canvas.drawCircle(
          pos,
          5,
          Paint()
            ..color = _sage.withValues(alpha: 0.35)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
        );
        canvas.drawCircle(
            pos, 2.4, Paint()..color = Colors.white.withValues(alpha: 0.95));
      }
    }
  }

  void _drawDashed(Canvas canvas, Path path, Color color, double width) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round
      ..color = color;
    const dash = 6.0;
    const gap = 7.0;
    for (final metric in path.computeMetrics()) {
      double dist = 0;
      while (dist < metric.length) {
        final next = math.min(dist + dash, metric.length);
        canvas.drawPath(metric.extractPath(dist, next), paint);
        dist = next + gap;
      }
    }
  }

  @override
  bool shouldRepaint(_HeroScenePainter oldDelegate) =>
      oldDelegate.progress != progress;
}

// ========================================================================
// Pastille de promesse (texte multi-ligne, fond clair arrondi)
// ========================================================================
class _SoftPill extends StatelessWidget {
  final String text;
  const _SoftPill({required this.text});

  static const _forestDeep = Color(0xFF3F6457);

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: const Color(0xFF7EB89A).withValues(alpha: 0.30),
            ),
          ),
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 11,
              height: 1.2,
              fontWeight: FontWeight.w600,
              color: _forestDeep,
            ),
          ),
        ),
      ),
    );
  }
}

// ========================================================================
// Épingle de scène : cercle vert clair + icône
// ========================================================================
class _ScenePin extends StatelessWidget {
  final IconData icon;
  final double size;
  const _ScenePin({required this.icon, required this.size});

  static const _forest = Color(0xFF5E8B7E);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFFDCEBDF).withValues(alpha: 0.92),
        border: Border.all(
          color: const Color(0xFF7EB89A).withValues(alpha: 0.40),
        ),
        boxShadow: [
          BoxShadow(
            color: _forest.withValues(alpha: 0.12),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Icon(icon, size: size * 0.45, color: _forest),
    );
  }
}

// ========================================================================
// Note d'identité : affichée quand le matricule n'est pas reconnu
// ========================================================================
class _IdentityNote extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const amber = Color(0xFFB9781A);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFFFBF1DE),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: amber.withValues(alpha: 0.30)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Icon(LucideIcons.triangleAlert, size: 16, color: amber),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Matricule non reconnu : renseignez votre identité. '
              'Votre demande sera vérifiée par l\'exploitation.',
              style: TextStyle(
                fontSize: 12,
                height: 1.3,
                color: amber,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ========================================================================
// Champ « e-mail dérivé » (lecture seule) : montre l'adresse calculée
// automatiquement à partir de l'identité, destination du code OTP.
// ========================================================================
class _DerivedEmailField extends StatelessWidget {
  final String email;
  const _DerivedEmailField({required this.email});

  static const _forest = Color(0xFF5E8B7E);
  static const _ink = Color(0xFF14241C);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: const [
            Icon(LucideIcons.atSign, size: 15, color: _forest),
            SizedBox(width: 7),
            Text(
              'Votre e-mail professionnel',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: _ink,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            color: const Color(0xFFEFF5F0),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _forest.withValues(alpha: 0.35)),
          ),
          child: Row(
            children: [
              const Icon(LucideIcons.mail, size: 18, color: _forest),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  email,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: _ink,
                  ),
                ),
              ),
              const Icon(LucideIcons.circleCheck,
                  size: 18, color: Color(0xFF3F8E5B)),
            ],
          ),
        ),
        const SizedBox(height: 5),
        Text(
          'Générée automatiquement (1re lettre du prénom + nom). Le code y '
          'sera envoyé.',
          style: TextStyle(
            fontSize: 11,
            height: 1.3,
            color: _forest.withValues(alpha: 0.85),
          ),
        ),
      ],
    );
  }
}

// ========================================================================
// Note d'aide discrète (icône + texte)
// ========================================================================
class _HintNote extends StatelessWidget {
  final IconData icon;
  final String text;
  const _HintNote({required this.icon, required this.text});

  static const _forestDeep = Color(0xFF3F6457);

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: _forestDeep.withValues(alpha: 0.7)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 11.5,
              height: 1.35,
              color: _forestDeep.withValues(alpha: 0.8),
            ),
          ),
        ),
      ],
    );
  }
}

// ========================================================================
// Bandeau d'erreur
// ========================================================================
class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFDECEC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF5C2C2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(LucideIcons.circleAlert, size: 18, color: Color(0xFFD64545)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 13.5,
                color: Color(0xFF9B2C2C),
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ========================================================================
// Bandeau d'information (succès / confirmation)
// ========================================================================
class _InfoBanner extends StatelessWidget {
  final String message;
  const _InfoBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFE9F5EC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFBFE0C8)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(LucideIcons.circleCheck, size: 18, color: Color(0xFF3F8E5B)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 13.5,
                color: Color(0xFF2E5C3E),
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

