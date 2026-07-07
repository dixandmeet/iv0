import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../widgets/onboarding_header.dart';
import '../widgets/onboarding_text_field.dart';

/// Écran — Informations de l'établissement (parcours « Commerçant »).
///
/// Nom et adresse requis ; téléphone optionnel. Les contrôleurs sont
/// initialisés depuis les données pour ne rien perdre au retour arrière.
class MerchantInfoStep extends StatefulWidget {
  final String name;
  final String address;
  final String phone;
  final void Function({String? name, String? address, String? phone}) onChanged;

  const MerchantInfoStep({
    super.key,
    required this.name,
    required this.address,
    required this.phone,
    required this.onChanged,
  });

  @override
  State<MerchantInfoStep> createState() => _MerchantInfoStepState();
}

class _MerchantInfoStepState extends State<MerchantInfoStep> {
  late final TextEditingController _nameCtrl =
      TextEditingController(text: widget.name);
  late final TextEditingController _addressCtrl =
      TextEditingController(text: widget.address);
  late final TextEditingController _phoneCtrl =
      TextEditingController(text: widget.phone);

  @override
  void dispose() {
    _nameCtrl.dispose();
    _addressCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const OnboardingHeader(
            title: 'Votre établissement',
            subtitle:
                'Ces informations permettront de vous présenter sur Aule.',
          ),
          const SizedBox(height: 28),
          OnboardingTextField(
            label: "Nom de l'établissement",
            hint: 'Boulangerie du Centre',
            icon: LucideIcons.store,
            controller: _nameCtrl,
            onChanged: (v) => widget.onChanged(name: v),
          ),
          const SizedBox(height: 20),
          OnboardingTextField(
            label: 'Adresse',
            hint: '12 rue de la Paix, Nantes',
            icon: LucideIcons.mapPin,
            controller: _addressCtrl,
            onChanged: (v) => widget.onChanged(address: v),
          ),
          const SizedBox(height: 20),
          OnboardingTextField(
            label: 'Téléphone',
            hint: '02 40 00 00 00',
            icon: LucideIcons.phone,
            optional: true,
            keyboardType: TextInputType.phone,
            controller: _phoneCtrl,
            onChanged: (v) => widget.onChanged(phone: v),
          ),
        ],
      ),
    );
  }
}
