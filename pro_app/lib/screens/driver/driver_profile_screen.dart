import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../../models/driver/driver_onboarding_data.dart';
import '../../models/driver/driver_profile.dart';
import '../../services/driver/driver_onboarding_service.dart';
import '../../services/driver/driver_service.dart';
import '../../theme/driver_home_palette.dart';
import '../../utils/photo_picker_permissions.dart';
import '../../widgets/driver/driver_avatar.dart';
import '../../widgets/driver/driver_menu_item.dart';
import '../../widgets/driver/driver_status_badge.dart';

/// Fiche profil du conducteur : identité, coordonnées et statut.
class DriverProfileScreen extends StatefulWidget {
  const DriverProfileScreen({super.key});

  @override
  State<DriverProfileScreen> createState() => _DriverProfileScreenState();
}

class _DriverProfileScreenState extends State<DriverProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _imagePicker = ImagePicker();
  bool _editing = false;

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  void _copy(BuildContext context, String label, String value) {
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('$label copié'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
  }

  void _snack(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _startEditing(DriverProfile driver) {
    _firstNameCtrl.text = driver.firstName ?? '';
    _lastNameCtrl.text = driver.lastName ?? '';
    _phoneCtrl.text = driver.phone ?? '';
    setState(() => _editing = true);
  }

  void _cancelEditing() => setState(() => _editing = false);

  Future<void> _resetOnboarding() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Refaire la configuration ?'),
        content: const Text(
          'L\'assistant de configuration va se relancer. '
          'Vos choix précédents seront effacés.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: DriverHomePalette.primary,
            ),
            child: const Text('Relancer'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final service = context.read<DriverOnboardingService>();
    Navigator.of(context).popUntil((route) => route.isFirst);
    await service.reset();
  }

  Future<void> _save(DriverProfile driver) async {
    if (!_formKey.currentState!.validate()) return;

    final service = context.read<DriverService>();
    final ok = await service.updateProfile(
      firstName: _firstNameCtrl.text,
      lastName: _lastNameCtrl.text,
      phone: _phoneCtrl.text,
    );
    if (!mounted) return;

    if (ok) {
      setState(() => _editing = false);
      _snack(context, 'Profil mis à jour');
    } else {
      _snack(context, service.errorMessage ?? 'Échec de la mise à jour');
    }
  }

  String _initials(String name) {
    final parts =
        name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    if (parts.isNotEmpty) return parts.first[0].toUpperCase();
    return '?';
  }

  String _depotLabel(DriverProfile driver) {
    final id = driver.depotId;
    if (id == null || id.trim().isEmpty) return 'Non renseigné';
    if (id.contains('-')) return 'Dépôt assigné';
    return id;
  }

  String _memberSince(DateTime? createdAt) {
    if (createdAt == null) return '—';
    return DateFormat('MMMM yyyy', 'fr_FR').format(createdAt);
  }

  String _displayOrDash(String? value) {
    if (value == null || value.trim().isEmpty) return '—';
    return value.trim();
  }

  String? _phoneValidator(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    final digits = text.replaceAll(RegExp(r'[\s.\-()]'), '');
    if (!RegExp(r'^\+?\d{6,15}$').hasMatch(digits)) {
      return 'Numéro invalide';
    }
    return null;
  }

  Future<void> _showAvatarOptions(DriverProfile driver) async {
    final hasPhoto =
        driver.avatarUrl != null && driver.avatarUrl!.trim().isNotEmpty;
    final action = await showModalBottomSheet<_AvatarAction>(
      context: context,
      backgroundColor: DriverHomePalette.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: DriverHomePalette.border,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const Text(
                'Photo de profil',
                style: TextStyle(
                  color: DriverHomePalette.textDark,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              _AvatarSheetTile(
                icon: LucideIcons.camera,
                label: 'Prendre une photo',
                onTap: () => Navigator.pop(context, _AvatarAction.camera),
              ),
              _AvatarSheetTile(
                icon: LucideIcons.image,
                label: 'Choisir dans la galerie',
                onTap: () => Navigator.pop(context, _AvatarAction.gallery),
              ),
              if (hasPhoto) ...[
                const Divider(height: 20, color: DriverHomePalette.border),
                _AvatarSheetTile(
                  icon: LucideIcons.trash2,
                  label: 'Supprimer la photo',
                  destructive: true,
                  onTap: () => Navigator.pop(context, _AvatarAction.delete),
                ),
              ],
            ],
          ),
        ),
      ),
    );
    if (!mounted || action == null) return;

    switch (action) {
      case _AvatarAction.camera:
        await _pickAvatar(ImageSource.camera);
      case _AvatarAction.gallery:
        await _pickAvatar(ImageSource.gallery);
      case _AvatarAction.delete:
        await _confirmDeleteAvatar();
    }
  }

  Future<void> _pickAvatar(ImageSource source) async {
    final permission = await ensurePhotoPickerPermission(source);
    if (!mounted) return;

    if (!permission.granted) {
      if (permission.permanentlyDenied) {
        await _showPermissionSettingsDialog(source);
      } else {
        _snack(
          context,
          source == ImageSource.camera
              ? 'Autorisation caméra refusée'
              : 'Autorisation galerie refusée',
        );
      }
      return;
    }

    try {
      final file = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );
      if (file == null || !mounted) return;

      final service = context.read<DriverService>();
      final ok = await service.uploadAvatar(file);
      if (!mounted) return;

      if (ok) {
        _snack(context, 'Photo mise à jour');
      } else {
        _snack(context, service.errorMessage ?? 'Échec de l\'envoi');
      }
    } on PlatformException catch (e) {
      if (!mounted) return;
      final denied = e.code == 'camera_access_denied' ||
          e.code == 'photo_access_denied' ||
          e.code == 'permission_denied';
      if (denied) {
        await _showPermissionSettingsDialog(source);
      } else {
        _snack(
          context,
          source == ImageSource.camera
              ? 'Impossible d\'ouvrir la caméra'
              : 'Impossible d\'ouvrir la galerie',
        );
      }
    } catch (e) {
      if (!mounted) return;
      _snack(
        context,
        source == ImageSource.camera
            ? 'Impossible d\'ouvrir la caméra'
            : 'Impossible d\'ouvrir la galerie',
      );
    }
  }

  Future<void> _showPermissionSettingsDialog(ImageSource source) async {
    final label =
        source == ImageSource.camera ? 'la caméra' : 'la galerie photos';
    final open = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Autorisation requise'),
        content: Text(
          'Pour choisir une photo, autorisez l\'accès à $label '
          'dans les paramètres de l\'application.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Paramètres'),
          ),
        ],
      ),
    );
    if (open == true) {
      await openAppSettings();
    }
  }

  Future<void> _confirmDeleteAvatar() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer la photo ?'),
        content: const Text(
          'Votre photo de profil sera retirée de votre fiche conducteur.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: DriverHomePalette.danger,
            ),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final service = context.read<DriverService>();
    final ok = await service.removeAvatar();
    if (!mounted) return;

    if (ok) {
      _snack(context, 'Photo supprimée');
    } else {
      _snack(context, service.errorMessage ?? 'Échec de la suppression');
    }
  }

  @override
  Widget build(BuildContext context) {
    final driverService = context.watch<DriverService>();
    final onboarding = context.watch<DriverOnboardingService>();
    final onboardingData = onboarding.savedData;
    final driver = driverService.driver;
    final saving = driverService.updatingProfile;
    final avatarLoading = driverService.updatingAvatar;

    if (driverService.loading && driver == null) {
      return Scaffold(
        backgroundColor: DriverHomePalette.background,
        appBar: AppBar(
          title: const Text('Profil'),
          backgroundColor: DriverHomePalette.card,
          surfaceTintColor: Colors.transparent,
        ),
        body: const Center(
          child: CircularProgressIndicator(color: DriverHomePalette.primary),
        ),
      );
    }

    if (driver == null) {
      return Scaffold(
        backgroundColor: DriverHomePalette.background,
        appBar: AppBar(
          title: const Text('Profil'),
          backgroundColor: DriverHomePalette.card,
          surfaceTintColor: Colors.transparent,
        ),
        body: const Center(
          child: Text(
            'Profil introuvable',
            style: TextStyle(color: DriverHomePalette.textSecondary),
          ),
        ),
      );
    }

    final active = driverService.hasActiveService;
    final statusLabel = active ? 'En service' : driver.statusLabel;
    final service = driverService.currentService;
    final displayName = _editing
        ? _previewName(_firstNameCtrl.text, _lastNameCtrl.text, driver)
        : driver.fullName;

    return Scaffold(
      backgroundColor: DriverHomePalette.background,
      appBar: AppBar(
        backgroundColor: DriverHomePalette.card,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        title: Text(
          _editing ? 'Modifier le profil' : 'Profil',
          style: const TextStyle(
            color: DriverHomePalette.textDark,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          if (_editing)
            TextButton(
              onPressed: saving ? null : _cancelEditing,
              child: const Text(
                'Annuler',
                style: TextStyle(color: DriverHomePalette.textSecondary),
              ),
            )
          else
            IconButton(
              tooltip: 'Modifier',
              onPressed: () => _startEditing(driver),
              icon: const Icon(
                LucideIcons.pencil,
                color: DriverHomePalette.primary,
              ),
            ),
        ],
      ),
      body: RefreshIndicator(
        color: DriverHomePalette.primary,
        onRefresh: saving ? () async {} : driverService.refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            _ProfileHero(
              initials: _initials(displayName),
              name: displayName,
              email: driver.email,
              avatarUrl: driver.avatarUrl,
              avatarLoading: avatarLoading,
              statusLabel: statusLabel,
              active: active || driver.status == 'on_service',
              onAvatarTap: avatarLoading || saving
                  ? null
                  : () => _showAvatarOptions(driver),
            ),
            if (active && service != null && !_editing) ...[
              const SizedBox(height: 16),
              _ActiveServiceCard(
                line: service.lineId != null
                    ? 'Ligne ${service.lineId}'
                    : 'Service en cours',
                headsign: service.headsign,
                serviceCode: service.serviceCode,
                startedAt: service.startTimeReal ?? service.startTimePlanned,
              ),
            ],
            const SizedBox(height: 22),
            _SectionTitle(
              'Informations personnelles',
              trailing: _editing
                  ? null
                  : TextButton(
                      onPressed: () => _startEditing(driver),
                      style: TextButton.styleFrom(
                        foregroundColor: DriverHomePalette.primary,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text(
                        'Modifier',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
            ),
            const SizedBox(height: 10),
            if (_editing)
              _ProfileEditForm(
                formKey: _formKey,
                firstNameCtrl: _firstNameCtrl,
                lastNameCtrl: _lastNameCtrl,
                phoneCtrl: _phoneCtrl,
                saving: saving,
                onSave: () => _save(driver),
                phoneValidator: _phoneValidator,
                onChanged: () => setState(() {}),
              )
            else
              DriverMenuGroup(
                items: [
                  _ProfileInfoRow(
                    icon: LucideIcons.user,
                    label: 'Prénom',
                    value: _displayOrDash(driver.firstName),
                  ),
                  _ProfileInfoRow(
                    icon: LucideIcons.userRound,
                    label: 'Nom',
                    value: _displayOrDash(driver.lastName),
                  ),
                  _ProfileInfoRow(
                    icon: LucideIcons.phone,
                    label: 'Téléphone',
                    value: _displayOrDash(driver.phone),
                    onCopy: driver.phone != null && driver.phone!.isNotEmpty
                        ? () => _copy(context, 'Téléphone', driver.phone!)
                        : null,
                  ),
                  _ProfileInfoRow(
                    icon: LucideIcons.circleUser,
                    label: 'Genre',
                    value: onboardingData.gender?.label ?? '—',
                    readOnly: true,
                  ),
                ],
              ),
            const SizedBox(height: 18),
            const _SectionTitle('Informations professionnelles'),
            const SizedBox(height: 10),
            DriverMenuGroup(
              items: [
                _ProfileInfoRow(
                  icon: LucideIcons.idCard,
                  label: 'Matricule',
                  value: _displayOrDash(driver.driverNumber),
                  readOnly: true,
                  onCopy: driver.driverNumber != null &&
                          driver.driverNumber!.isNotEmpty
                      ? () => _copy(context, 'Matricule', driver.driverNumber!)
                      : null,
                ),
                _ProfileInfoRow(
                  icon: LucideIcons.mail,
                  label: 'E-mail',
                  value: driver.email,
                  readOnly: true,
                  onCopy: () => _copy(context, 'E-mail', driver.email),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                'Le matricule et l\'e-mail sont gérés par l\'exploitation.',
                style: TextStyle(
                  color: DriverHomePalette.textSecondary,
                  fontSize: 12.5,
                  height: 1.4,
                ),
              ),
            ),
            if (!_editing) ...[
              const SizedBox(height: 18),
              const _SectionTitle('Affectation'),
              const SizedBox(height: 10),
              DriverMenuGroup(
                items: [
                  _ProfileInfoRow(
                    icon: LucideIcons.mapPin,
                    label: 'Réseau',
                    value: onboardingData.network?.label ?? '—',
                    readOnly: true,
                  ),
                  _ProfileInfoRow(
                    icon: LucideIcons.building2,
                    label: 'Dépôt',
                    value: _depotLabel(driver),
                    readOnly: true,
                  ),
                  _ProfileInfoRow(
                    icon: LucideIcons.badgeCheck,
                    label: 'Rôle',
                    value: 'Conducteur',
                    readOnly: true,
                  ),
                  _ProfileInfoRow(
                    icon: LucideIcons.calendar,
                    label: 'Membre depuis',
                    value: _memberSince(driver.createdAt),
                    readOnly: true,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const _SectionTitle('Habilitations'),
              const SizedBox(height: 10),
              DriverMenuGroup(
                items: [
                  for (final hab in DriverHabilitation.values)
                    _HabilitationRow(
                      habilitation: hab,
                      enabled: _isHabEnabled(hab, driver, onboardingData),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  'Modifiable via « Reconfigurer le profil ».',
                  style: TextStyle(
                    color: DriverHomePalette.textSecondary,
                    fontSize: 12.5,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const _SectionTitle('Compte'),
              const SizedBox(height: 10),
              DriverMenuGroup(
                items: [
                  DriverMenuItem(
                    icon: LucideIcons.shield,
                    label: 'Confidentialité',
                    onTap: () => _snack(context, 'Confidentialité à venir'),
                  ),
                  DriverMenuItem(
                    icon: LucideIcons.headphones,
                    label: 'Contacter le support',
                    onTap: () => _snack(context, 'Support à venir'),
                  ),
                  DriverMenuItem(
                    icon: LucideIcons.refreshCw,
                    label: 'Reconfigurer le profil',
                    onTap: _resetOnboarding,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  bool _isHabEnabled(
    DriverHabilitation hab,
    DriverProfile driver,
    DriverOnboardingData data,
  ) {
    // controle et intervention : Supabase fait foi (mis à jour après onboarding)
    if (hab == DriverHabilitation.controle) return driver.msrControl;
    if (hab == DriverHabilitation.intervention) return driver.msrIntervention;
    // conduite et umtc : stockés localement uniquement
    return data.habilitations.contains(hab);
  }

  String _previewName(
    String first,
    String last,
    DriverProfile driver,
  ) {
    final parts = [first.trim(), last.trim()]
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isNotEmpty) return parts.join(' ');
    return driver.fullName;
  }
}

enum _AvatarAction { camera, gallery, delete }

class _AvatarSheetTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool destructive;
  final VoidCallback onTap;

  const _AvatarSheetTile({
    required this.icon,
    required this.label,
    this.destructive = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color =
        destructive ? DriverHomePalette.danger : DriverHomePalette.textDark;
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final Widget? trailing;

  const _SectionTitle(this.title, {this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: DriverHomePalette.textSecondary,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
          ),
        ),
        ?trailing,
      ],
    );
  }
}

class _ProfileEditForm extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController firstNameCtrl;
  final TextEditingController lastNameCtrl;
  final TextEditingController phoneCtrl;
  final bool saving;
  final VoidCallback onSave;
  final String? Function(String?) phoneValidator;
  final VoidCallback onChanged;

  const _ProfileEditForm({
    required this.formKey,
    required this.firstNameCtrl,
    required this.lastNameCtrl,
    required this.phoneCtrl,
    required this.saving,
    required this.onSave,
    required this.phoneValidator,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: DriverHomePalette.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: DriverHomePalette.border),
        boxShadow: const [
          BoxShadow(
            color: DriverHomePalette.cardShadow,
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _EditField(
              controller: firstNameCtrl,
              label: 'Prénom',
              icon: LucideIcons.user,
              enabled: !saving,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              onChanged: (_) => onChanged(),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Prénom requis' : null,
            ),
            const SizedBox(height: 14),
            _EditField(
              controller: lastNameCtrl,
              label: 'Nom',
              icon: LucideIcons.userRound,
              enabled: !saving,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              onChanged: (_) => onChanged(),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Nom requis' : null,
            ),
            const SizedBox(height: 14),
            _EditField(
              controller: phoneCtrl,
              label: 'Téléphone',
              icon: LucideIcons.phone,
              enabled: !saving,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.done,
              hint: 'Ex. 06 12 34 56 78',
              onChanged: (_) => onChanged(),
              validator: phoneValidator,
            ),
            const SizedBox(height: 18),
            SizedBox(
              height: 48,
              child: FilledButton(
                onPressed: saving ? null : onSave,
                style: FilledButton.styleFrom(
                  backgroundColor: DriverHomePalette.primary,
                  disabledBackgroundColor:
                      DriverHomePalette.primary.withValues(alpha: 0.45),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: saving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Enregistrer',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
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

class _EditField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool enabled;
  final TextCapitalization textCapitalization;
  final TextInputAction textInputAction;
  final TextInputType? keyboardType;
  final String? hint;
  final ValueChanged<String>? onChanged;
  final String? Function(String?)? validator;

  const _EditField({
    required this.controller,
    required this.label,
    required this.icon,
    required this.enabled,
    this.textCapitalization = TextCapitalization.none,
    this.textInputAction = TextInputAction.next,
    this.keyboardType,
    this.hint,
    this.onChanged,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: DriverHomePalette.textSecondary,
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          enabled: enabled,
          textCapitalization: textCapitalization,
          textInputAction: textInputAction,
          keyboardType: keyboardType,
          onChanged: onChanged,
          validator: validator,
          style: const TextStyle(
            color: DriverHomePalette.textDark,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(
              color: DriverHomePalette.inactiveIcon,
              fontWeight: FontWeight.w500,
            ),
            prefixIcon: Icon(icon, size: 18, color: DriverHomePalette.primary),
            filled: true,
            fillColor: DriverHomePalette.background,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: DriverHomePalette.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: DriverHomePalette.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(
                color: DriverHomePalette.primary,
                width: 1.5,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: DriverHomePalette.danger),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
          ),
        ),
      ],
    );
  }
}

class _ProfileHero extends StatelessWidget {
  final String initials;
  final String name;
  final String email;
  final String? avatarUrl;
  final bool avatarLoading;
  final String statusLabel;
  final bool active;
  final VoidCallback? onAvatarTap;

  const _ProfileHero({
    required this.initials,
    required this.name,
    required this.email,
    this.avatarUrl,
    this.avatarLoading = false,
    required this.statusLabel,
    required this.active,
    this.onAvatarTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            DriverHomePalette.gradientStart,
            DriverHomePalette.gradientEnd,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: DriverHomePalette.gradientEnd.withValues(alpha: 0.28),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: [
          DriverAvatar(
            initials: initials,
            imageUrl: avatarUrl,
            size: 88,
            loading: avatarLoading,
            editable: onAvatarTap != null,
            onTap: onAvatarTap,
          ),
          const SizedBox(height: 14),
          Text(
            name,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            email,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.78),
              fontSize: 13.5,
            ),
          ),
          const SizedBox(height: 14),
          DriverStatusBadge(label: statusLabel, active: active),
        ],
      ),
    );
  }
}

class _ActiveServiceCard extends StatelessWidget {
  final String line;
  final String? headsign;
  final String? serviceCode;
  final DateTime? startedAt;

  const _ActiveServiceCard({
    required this.line,
    this.headsign,
    this.serviceCode,
    this.startedAt,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: DriverHomePalette.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: DriverHomePalette.border),
        boxShadow: const [
          BoxShadow(
            color: DriverHomePalette.cardShadow,
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: DriverHomePalette.lightGreen,
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(
              LucideIcons.bus,
              size: 22,
              color: DriverHomePalette.primary,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Service en cours',
                  style: TextStyle(
                    color: DriverHomePalette.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  line,
                  style: const TextStyle(
                    color: DriverHomePalette.textDark,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (headsign != null && headsign!.trim().isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    headsign!.trim(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: DriverHomePalette.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
                if (serviceCode != null && serviceCode!.trim().isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Service ${serviceCode!.trim()}',
                    style: const TextStyle(
                      color: DriverHomePalette.textSecondary,
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (startedAt != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text(
                  'Début',
                  style: TextStyle(
                    color: DriverHomePalette.textSecondary,
                    fontSize: 11,
                  ),
                ),
                Text(
                  DateFormat('HH:mm').format(startedAt!),
                  style: const TextStyle(
                    color: DriverHomePalette.primary,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _HabilitationRow extends StatelessWidget {
  final DriverHabilitation habilitation;
  final bool enabled;

  const _HabilitationRow({
    required this.habilitation,
    required this.enabled,
  });

  IconData get _icon => switch (habilitation) {
        DriverHabilitation.conduite => LucideIcons.bus,
        DriverHabilitation.controle => LucideIcons.shieldCheck,
        DriverHabilitation.intervention => LucideIcons.wrench,
        DriverHabilitation.umtc => LucideIcons.users,
      };

  @override
  Widget build(BuildContext context) {
    final color =
        enabled ? DriverHomePalette.primary : DriverHomePalette.inactiveIcon;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: enabled
                  ? DriverHomePalette.primary.withValues(alpha: 0.12)
                  : DriverHomePalette.border,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(_icon, size: 19, color: color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  habilitation.label,
                  style: TextStyle(
                    color: enabled
                        ? DriverHomePalette.textDark
                        : DriverHomePalette.textSecondary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  habilitation.description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: DriverHomePalette.textSecondary,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            enabled ? LucideIcons.circleCheck : LucideIcons.circle,
            size: 18,
            color: enabled ? DriverHomePalette.primary : DriverHomePalette.border,
          ),
        ],
      ),
    );
  }
}

class _ProfileInfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool readOnly;
  final VoidCallback? onCopy;

  const _ProfileInfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.readOnly = false,
    this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    final canCopy = onCopy != null && value != '—';

    return InkWell(
      onTap: canCopy ? onCopy : null,
      onLongPress: canCopy ? onCopy : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: DriverHomePalette.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, size: 19, color: DriverHomePalette.primary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: DriverHomePalette.textSecondary,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: DriverHomePalette.textDark,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            if (readOnly)
              const Icon(
                LucideIcons.lock,
                size: 15,
                color: DriverHomePalette.inactiveIcon,
              )
            else if (canCopy)
              const Icon(
                LucideIcons.copy,
                size: 16,
                color: DriverHomePalette.inactiveIcon,
              ),
          ],
        ),
      ),
    );
  }
}
