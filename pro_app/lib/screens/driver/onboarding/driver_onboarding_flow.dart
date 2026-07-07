import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/driver/driver_onboarding_data.dart';
import '../../../services/driver/driver_onboarding_service.dart';
import '../../../services/driver/driver_service.dart';
import '../../../theme/driver_home_palette.dart';
import 'steps/activity_step.dart';
import 'steps/confirmation_step.dart';
import 'steps/depot_step.dart';
import 'steps/gender_step.dart';
import 'steps/habilitations_step.dart';
import 'steps/merchant_info_step.dart';
import 'steps/merchant_type_step.dart';
import 'steps/network_step.dart';
import 'steps/vtc_activity_step.dart';
import 'steps/welcome_step.dart';
import 'steps/zone_step.dart';

/// Descripteur d'une étape d'onboarding.
///
/// Chaque étape est autonome : un identifiant (pour l'animation et la clé),
/// une règle de validité (active le bouton « Continuer ») et un constructeur.
/// Ajouter, retirer ou réordonner une étape n'impacte aucune autre.
class _OnboardingStep {
  final String id;
  final bool Function(DriverOnboardingData data) isValid;
  final Widget Function() build;

  const _OnboardingStep({
    required this.id,
    required this.isValid,
    required this.build,
  });
}

/// Flow d'onboarding Aule Pro — premium, dynamique et conditionnel.
///
/// Le parcours s'adapte automatiquement au profil professionnel choisi.
/// Les données ne sont persistées qu'à la validation finale ; revenir en
/// arrière ne perd jamais les choix précédents.
class DriverOnboardingFlow extends StatefulWidget {
  const DriverOnboardingFlow({super.key});

  @override
  State<DriverOnboardingFlow> createState() => _DriverOnboardingFlowState();
}

class _DriverOnboardingFlowState extends State<DriverOnboardingFlow> {
  DriverOnboardingData _data = const DriverOnboardingData();
  int _index = 0;
  bool _forward = true;
  bool _saving = false;

  // ── Mise à jour de l'état ──────────────────────────────────────────────────

  void _update(DriverOnboardingData next) => setState(() => _data = next);

  // ── Registre dynamique des étapes ──────────────────────────────────────────
  // Communes : Bienvenue → Activité → … parcours conditionnel … → Confirmation.

  List<_OnboardingStep> _buildSteps() {
    return [
      _OnboardingStep(
        id: 'welcome',
        isValid: (_) => true,
        build: () => const WelcomeStep(),
      ),
      _OnboardingStep(
        id: 'activity',
        isValid: (d) => d.profile != null,
        build: () => ActivityStep(
          selected: _data.profile,
          onSelected: (p) => _update(_data.copyWith(profile: p)),
        ),
      ),
      ..._profileSteps(),
      _OnboardingStep(
        id: 'confirmation',
        isValid: (_) => true,
        build: () => ConfirmationStep(data: _data),
      ),
    ];
  }

  /// Étapes spécifiques au profil sélectionné.
  List<_OnboardingStep> _profileSteps() {
    switch (_data.profile) {
      case ProProfile.reseau:
        return [
          _networkStep(),
          _depotStep(),
          _genderStep(),
          _habilitationsStep(),
        ];
      case ProProfile.vtc:
        return [_genderStep(), _vtcActivityStep(), _zoneStep()];
      case ProProfile.commercant:
        return [_merchantTypeStep(), _merchantInfoStep()];
      case null:
        return const [];
    }
  }

  _OnboardingStep _networkStep() => _OnboardingStep(
        id: 'network',
        isValid: (d) => d.network != null,
        build: () => NetworkStep(
          selected: _data.network,
          onSelected: (n) => _update(_data.copyWith(network: n)),
        ),
      );

  _OnboardingStep _genderStep() => _OnboardingStep(
        id: 'gender',
        isValid: (d) => d.gender != null,
        build: () => GenderStep(
          selected: _data.gender,
          onSelected: (g) => _update(_data.copyWith(gender: g)),
        ),
      );

  _OnboardingStep _depotStep() => _OnboardingStep(
        id: 'depot',
        isValid: (d) => d.depot != null,
        build: () => DepotStep(
          selected: _data.depot,
          onSelected: (depot) => _update(_data.copyWith(depot: depot)),
        ),
      );

  _OnboardingStep _habilitationsStep() => _OnboardingStep(
        id: 'habilitations',
        isValid: (d) => d.habilitations.isNotEmpty,
        build: () => HabilitationsStep(
          selected: _data.habilitations,
          onChanged: (h) => _update(_data.copyWith(habilitations: h)),
        ),
      );

  _OnboardingStep _vtcActivityStep() => _OnboardingStep(
        id: 'vtc_activity',
        isValid: (d) => d.vtcActivity != null,
        build: () => VtcActivityStep(
          selected: _data.vtcActivity,
          onSelected: (a) => _update(_data.copyWith(vtcActivity: a)),
        ),
      );

  _OnboardingStep _zoneStep() => _OnboardingStep(
        id: 'zone',
        isValid: (d) => d.zone != null,
        build: () => ZoneStep(
          selected: _data.zone,
          onSelected: (z) => _update(_data.copyWith(zone: z)),
        ),
      );

  _OnboardingStep _merchantTypeStep() => _OnboardingStep(
        id: 'merchant_type',
        isValid: (d) => d.merchantType != null,
        build: () => MerchantTypeStep(
          selected: _data.merchantType,
          onSelected: (t) => _update(_data.copyWith(merchantType: t)),
        ),
      );

  _OnboardingStep _merchantInfoStep() => _OnboardingStep(
        id: 'merchant_info',
        isValid: (d) =>
            d.merchantName.trim().isNotEmpty &&
            d.merchantAddress.trim().isNotEmpty,
        build: () => MerchantInfoStep(
          name: _data.merchantName,
          address: _data.merchantAddress,
          phone: _data.merchantPhone,
          onChanged: ({String? name, String? address, String? phone}) =>
              _update(_data.copyWith(
            merchantName: name,
            merchantAddress: address,
            merchantPhone: phone,
          )),
        ),
      );

  // ── Navigation ─────────────────────────────────────────────────────────────

  void _next(int total) {
    if (_index < total - 1) {
      setState(() {
        _forward = true;
        _index++;
      });
    }
  }

  void _back() {
    if (_index > 0) {
      setState(() {
        _forward = false;
        _index--;
      });
    }
  }

  Future<void> _complete() async {
    if (_saving) return;
    setState(() => _saving = true);
    // Capture les références avant le premier await : le widget peut être
    // démonté (DriverShell rebascule) pendant les appels réseau.
    final onboarding = context.read<DriverOnboardingService>();
    final driver = context.read<DriverService>();
    try {
      await onboarding.complete(_data);
      await driver.refresh();
    } catch (e) {
      debugPrint('Onboarding: complete failed ($e)');
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final steps = _buildSteps();
    // Garde-fou : si le parcours raccourcit (changement de profil), borne
    // l'index dans la liste courante.
    final index = _index.clamp(0, steps.length - 1);
    final step = steps[index];
    final total = steps.length;
    final isLast = index == total - 1;
    final canContinue = step.isValid(_data);

    return Scaffold(
      backgroundColor: DriverHomePalette.background,
      body: Column(
        children: [
          _ProgressBar(step: index, total: total),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              transitionBuilder: (child, animation) {
                final slide = Tween<Offset>(
                  begin: Offset(_forward ? 0.08 : -0.08, 0),
                  end: Offset.zero,
                ).animate(animation);
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(position: slide, child: child),
                );
              },
              child: KeyedSubtree(
                key: ValueKey(step.id),
                child: step.build(),
              ),
            ),
          ),
          _BottomNav(
            isFirst: index == 0,
            isLast: isLast,
            canContinue: canContinue,
            saving: _saving,
            onBack: _back,
            onContinue: isLast ? _complete : () => _next(total),
          ),
        ],
      ),
    );
  }
}

// ── Barre de progression ────────────────────────────────────────────────────

class _ProgressBar extends StatelessWidget {
  final int step;
  final int total;

  const _ProgressBar({required this.step, required this.total});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Étape ${step + 1} sur $total',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: DriverHomePalette.textSecondary,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: TweenAnimationBuilder<double>(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                tween: Tween(end: (step + 1) / total),
                builder: (context, value, _) => LinearProgressIndicator(
                  value: value,
                  minHeight: 6,
                  backgroundColor: DriverHomePalette.border,
                  valueColor: const AlwaysStoppedAnimation(
                    DriverHomePalette.primary,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Navigation bas de page ──────────────────────────────────────────────────

class _BottomNav extends StatelessWidget {
  final bool isFirst;
  final bool isLast;
  final bool canContinue;
  final bool saving;
  final VoidCallback onBack;
  final VoidCallback onContinue;

  const _BottomNav({
    required this.isFirst,
    required this.isLast,
    required this.canContinue,
    required this.saving,
    required this.onBack,
    required this.onContinue,
  });

  String get _label => (isFirst || isLast) ? 'Commencer' : 'Continuer';

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: DriverHomePalette.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: isFirst
                ? Column(
                    key: const ValueKey('welcome'),
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _PrimaryButton(
                        label: _label,
                        enabled: true,
                        saving: saving,
                        onPressed: onContinue,
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Moins de 30 secondes pour terminer la configuration',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: DriverHomePalette.textSecondary,
                        ),
                      ),
                    ],
                  )
                : Row(
                    key: const ValueKey('nav'),
                    children: [
                      TextButton(
                        onPressed: onBack,
                        style: TextButton.styleFrom(
                          foregroundColor: DriverHomePalette.textSecondary,
                          minimumSize: const Size(84, 56),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          'Retour',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _PrimaryButton(
                          label: _label,
                          enabled: canContinue,
                          saving: saving,
                          onPressed: onContinue,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final bool enabled;
  final bool saving;
  final VoidCallback onPressed;

  const _PrimaryButton({
    required this.label,
    required this.enabled,
    required this.saving,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: (enabled && !saving) ? onPressed : null,
      style: FilledButton.styleFrom(
        backgroundColor: DriverHomePalette.primary,
        disabledBackgroundColor: DriverHomePalette.border,
        minimumSize: const Size(double.infinity, 60),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        elevation: 4,
        shadowColor: DriverHomePalette.primary.withValues(alpha: 0.4),
      ),
      child: saving
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2.2,
                color: Colors.white,
              ),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15.5,
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.arrow_forward_rounded, size: 18),
              ],
            ),
    );
  }
}
