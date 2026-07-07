import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../models/driver/driver_onboarding_data.dart';
import '../../models/driver/service_exchange_post.dart';
import '../../services/driver/driver_onboarding_service.dart';
import '../../services/driver/service_exchange_service.dart';
import '../../theme/driver_home_palette.dart';
import '../../widgets/driver/driver_time_picker.dart';

/// Création / édition d'une annonce d'échange de service.
class ServiceExchangeCreateScreen extends StatefulWidget {
  final ServiceExchangePost? editPost;

  const ServiceExchangeCreateScreen({super.key, this.editPost});

  @override
  State<ServiceExchangeCreateScreen> createState() =>
      _ServiceExchangeCreateScreenState();
}

class _ServiceExchangeCreateScreenState
    extends State<ServiceExchangeCreateScreen> {
  late ServiceExchangePostKind _kind;
  late ServiceExchangeServiceType _serviceType;
  DateTime? _date;
  TimeOfDay? _start;
  TimeOfDay? _end;
  final _serviceNumber = TextEditingController();
  final _lineCode = TextEditingController();
  final _vehicleCode = TextEditingController();
  final _message = TextEditingController();
  bool _urgent = false;
  int _expiryPreset = 0; // 0 = aucune, 1 = 24h, 2 = 48h, 3 = jusqu'au service

  bool get _isEdit => widget.editPost != null;

  List<ServiceExchangeServiceType> _allowedTypes = const [];

  @override
  void initState() {
    super.initState();
    final post = widget.editPost;
    _kind = post?.postKind ?? ServiceExchangePostKind.request;
    _serviceType = post?.serviceType ?? ServiceExchangeServiceType.bus;
    _date = post?.serviceDate;
    if (post != null) {
      _start = _parseTime(post.startTime);
      _end = _parseTime(post.endTime);
      _serviceNumber.text = post.serviceNumber ?? '';
      _lineCode.text = post.lineCode ?? '';
      _vehicleCode.text = post.vehicleCode ?? '';
      _message.text = post.message ?? '';
      _urgent = post.isUrgent;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final onboarding = context.read<DriverOnboardingService>();
    _allowedTypes = _typesFromHabilitations(onboarding.savedData.habilitations);
    if (_allowedTypes.isNotEmpty && !_allowedTypes.contains(_serviceType)) {
      _serviceType = _allowedTypes.first;
    }
  }

  List<ServiceExchangeServiceType> _typesFromHabilitations(
      Set<DriverHabilitation> habs) {
    final types = <ServiceExchangeServiceType>{};
    if (habs.contains(DriverHabilitation.conduite)) {
      types.add(ServiceExchangeServiceType.bus);
      types.add(ServiceExchangeServiceType.tram);
    }
    if (habs.contains(DriverHabilitation.controle)) {
      types.add(ServiceExchangeServiceType.controle);
    }
    if (habs.contains(DriverHabilitation.intervention)) {
      types.add(ServiceExchangeServiceType.intervention);
    }
    if (habs.contains(DriverHabilitation.umtc)) {
      types.add(ServiceExchangeServiceType.umtc);
    }
    if (types.isEmpty) {
      return ServiceExchangeServiceType.values;
    }
    return types.toList();
  }

  TimeOfDay? _parseTime(String hhmm) {
    final parts = hhmm.split(':');
    if (parts.length < 2) return null;
    return TimeOfDay(
      hour: int.tryParse(parts[0]) ?? 0,
      minute: int.tryParse(parts[1]) ?? 0,
    );
  }

  String _fmtTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  @override
  void dispose() {
    _serviceNumber.dispose();
    _lineCode.dispose();
    _vehicleCode.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? now,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 90)),
      locale: const Locale('fr', 'FR'),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime(bool isStart) async {
    final picked = await showDriverTimePicker(
      context: context,
      initialTime: (isStart ? _start : _end) ??
          TimeOfDay(hour: isStart ? 6 : 14, minute: 0),
      title: isStart ? 'Heure de début' : 'Heure de fin',
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _start = picked;
        } else {
          _end = picked;
        }
      });
    }
  }

  DateTime? _resolveExpiry() {
    switch (_expiryPreset) {
      case 1:
        return DateTime.now().add(const Duration(hours: 24));
      case 2:
        return DateTime.now().add(const Duration(hours: 48));
      case 3:
        if (_date == null) return null;
        return DateTime(_date!.year, _date!.month, _date!.day, 23, 59);
      default:
        return null;
    }
  }

  Future<void> _submit() async {
    final messenger = ScaffoldMessenger.of(context);
    if (_date == null || _start == null || _end == null) {
      messenger.showSnackBar(const SnackBar(
          content: Text('Renseignez la date et les horaires.')));
      return;
    }
    if (_end!.hour * 60 + _end!.minute <= _start!.hour * 60 + _start!.minute) {
      messenger.showSnackBar(const SnackBar(
          content: Text('L\'heure de fin doit être après le début.')));
      return;
    }

    final service = context.read<ServiceExchangeService>();
    final navigator = Navigator.of(context);
    ServiceExchangePost? result;

    if (_isEdit) {
      result = await service.updatePost(
        postId: widget.editPost!.id,
        serviceDate: _date,
        startTime: _fmtTime(_start!),
        endTime: _fmtTime(_end!),
        serviceNumber: _isRequest ? _serviceNumber.text : null,
        lineCode: _isRequest ? _lineCode.text : null,
        vehicleCode: _isRequest ? _vehicleCode.text : null,
        message: _message.text,
        isUrgent: _urgent,
        expiresAt: _resolveExpiry(),
      );
    } else {
      result = await service.createPost(
        postKind: _kind,
        serviceType: _serviceType,
        serviceDate: _date!,
        startTime: _fmtTime(_start!),
        endTime: _fmtTime(_end!),
        serviceNumber: _isRequest ? _serviceNumber.text : null,
        lineCode: _isRequest ? _lineCode.text : null,
        vehicleCode: _isRequest ? _vehicleCode.text : null,
        message: _message.text,
        isUrgent: _urgent,
        expiresAt: _resolveExpiry(),
      );
    }

    if (!mounted) return;
    if (result != null) {
      navigator.pop(true);
    } else {
      messenger.showSnackBar(
        SnackBar(content: Text(service.error ?? 'Échec de l\'enregistrement')),
      );
    }
  }

  bool get _isRequest => _kind == ServiceExchangePostKind.request;

  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final saving = context.watch<ServiceExchangeService>().saving;
    return Scaffold(
      backgroundColor: DriverHomePalette.background,
      body: CustomScrollView(
        slivers: [
          _heroAppBar(),
          SliverToBoxAdapter(child: _form()),
        ],
      ),
      bottomNavigationBar: _submitBar(saving),
    );
  }

  // ---------------------------------------------------------------------------
  // Hero
  // ---------------------------------------------------------------------------

  Widget _heroAppBar() {
    return SliverAppBar(
      pinned: true,
      expandedHeight: 150,
      backgroundColor: DriverHomePalette.gradientEnd,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle.light,
      leadingWidth: 60,
      leading: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: Material(
          color: Colors.white.withValues(alpha: 0.18),
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () => Navigator.of(context).maybePop(),
            child: const Padding(
              padding: EdgeInsets.all(9),
              child:
                  Icon(LucideIcons.arrowLeft, size: 19, color: Colors.white),
            ),
          ),
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        titlePadding:
            const EdgeInsetsDirectional.only(start: 56, bottom: 16, end: 20),
        title: Text(
          _isEdit ? 'Modifier l\'annonce' : 'Nouvelle annonce',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 18,
            letterSpacing: -0.3,
          ),
        ),
        background: Stack(
          fit: StackFit.expand,
          children: [
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    DriverHomePalette.gradientStart,
                    DriverHomePalette.gradientEnd,
                  ],
                ),
              ),
            ),
            Positioned(
              top: -40,
              right: -30,
              child: Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Formulaire
  // ---------------------------------------------------------------------------

  Widget _form() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!_isEdit) ...[
            _sectionLabel('Type d\'annonce', LucideIcons.repeat),
            const SizedBox(height: 10),
            Row(
              children: ServiceExchangePostKind.values.map((k) {
                final selected = _kind == k;
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                        right: k == ServiceExchangePostKind.values.first
                            ? 10
                            : 0),
                    child: _kindCard(k, selected),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 22),
            _sectionLabel('Service concerné', LucideIcons.bus),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _allowedTypes.map((t) {
                final selected = _serviceType == t;
                return GestureDetector(
                  onTap: () => setState(() => _serviceType = t),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: selected
                          ? t.color
                          : DriverHomePalette.card,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: selected ? t.color : DriverHomePalette.border,
                      ),
                      boxShadow: selected
                          ? [
                              BoxShadow(
                                color: t.color.withValues(alpha: 0.3),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ]
                          : null,
                    ),
                    child: Text(
                      '${t.emoji}  ${t.label}',
                      style: TextStyle(
                        color: selected
                            ? Colors.white
                            : DriverHomePalette.textSecondary,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 22),
          ],
          _sectionLabel('Date & horaires', LucideIcons.calendarDays),
          const SizedBox(height: 10),
          _fieldTile(
            icon: LucideIcons.calendarDays,
            color: DriverHomePalette.primary,
            label: _date == null
                ? 'Choisir une date'
                : _capitalize(
                    DateFormat('EEEE d MMMM', 'fr_FR').format(_date!)),
            placeholder: _date == null,
            onTap: _pickDate,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _fieldTile(
                  icon: LucideIcons.clock,
                  color: DriverHomePalette.blue,
                  label: _start == null ? 'Début' : _fmtTime(_start!),
                  placeholder: _start == null,
                  onTap: () => _pickTime(true),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _fieldTile(
                  icon: LucideIcons.clock,
                  color: DriverHomePalette.blue,
                  label: _end == null ? 'Fin' : _fmtTime(_end!),
                  placeholder: _end == null,
                  onTap: () => _pickTime(false),
                ),
              ),
            ],
          ),
          if (_isRequest) ...[
            const SizedBox(height: 22),
            _sectionLabel('Service complet', LucideIcons.hash,
                trailing: 'optionnel'),
            const SizedBox(height: 10),
            _textField(_serviceNumber, 'N° de service', LucideIcons.hash),
            const SizedBox(height: 10),
            _textField(_lineCode, 'Ligne', LucideIcons.route),
            const SizedBox(height: 10),
            _textField(_vehicleCode, 'Véhicule', LucideIcons.bus),
          ],
          const SizedBox(height: 22),
          _sectionLabel('Message', LucideIcons.messageSquare,
              trailing: 'optionnel'),
          const SizedBox(height: 10),
          _textField(
            _message,
            'Précisez votre demande…',
            LucideIcons.messageSquare,
            maxLines: 3,
          ),
          const SizedBox(height: 22),
          _sectionLabel('Options', LucideIcons.settings2),
          const SizedBox(height: 10),
          _urgentTile(),
          const SizedBox(height: 10),
          _expiryTile(),
          const SizedBox(height: 16),
          _infoBanner(),
        ],
      ),
    );
  }

  Widget _infoBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: DriverHomePalette.lightGreen,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: DriverHomePalette.primary.withValues(alpha: 0.12)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(LucideIcons.info, size: 17, color: DriverHomePalette.primary),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Cette annonce sera visible par les agents compatibles de '
              'votre dépôt. La négociation se fait dans la messagerie.',
              style: TextStyle(
                color: DriverHomePalette.textSecondary,
                fontSize: 12.5,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Barre de soumission
  // ---------------------------------------------------------------------------

  Widget _submitBar(bool saving) {
    return Container(
      decoration: const BoxDecoration(
        color: DriverHomePalette.card,
        border: Border(top: BorderSide(color: DriverHomePalette.border)),
        boxShadow: [
          BoxShadow(
            color: DriverHomePalette.cardShadow,
            blurRadius: 20,
            offset: Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: saving
                  ? null
                  : const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        DriverHomePalette.gradientStart,
                        DriverHomePalette.gradientEnd,
                      ],
                    ),
              color: saving ? DriverHomePalette.inactiveIcon : null,
              boxShadow: saving
                  ? null
                  : [
                      BoxShadow(
                        color: DriverHomePalette.primary.withValues(alpha: 0.32),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: saving ? null : _submit,
                child: SizedBox(
                  height: 54,
                  child: Center(
                    child: saving
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _isEdit
                                    ? LucideIcons.check
                                    : LucideIcons.megaphone,
                                size: 18,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _isEdit
                                    ? 'Enregistrer'
                                    : 'Publier l\'annonce',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Composants
  // ---------------------------------------------------------------------------

  Widget _kindCard(ServiceExchangePostKind k, bool selected) {
    return GestureDetector(
      onTap: () => setState(() => _kind = k),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
        decoration: BoxDecoration(
          color: selected ? DriverHomePalette.lightGreen : DriverHomePalette.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected
                ? DriverHomePalette.primary
                : DriverHomePalette.border,
            width: selected ? 1.6 : 1,
          ),
          boxShadow: selected
              ? null
              : const [
                  BoxShadow(
                    color: DriverHomePalette.cardShadow,
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ],
        ),
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Text(k.emoji, style: const TextStyle(fontSize: 26)),
                if (selected)
                  Positioned(
                    right: -10,
                    top: -6,
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: const BoxDecoration(
                        color: DriverHomePalette.primary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(LucideIcons.check,
                          size: 12, color: Colors.white),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              k.label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: selected
                    ? DriverHomePalette.primary
                    : DriverHomePalette.textDark,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text, IconData icon, {String? trailing}) {
    return Row(
      children: [
        Icon(icon, size: 16, color: DriverHomePalette.primary),
        const SizedBox(width: 8),
        Text(
          text,
          style: const TextStyle(
            color: DriverHomePalette.textDark,
            fontSize: 15,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.2,
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: DriverHomePalette.background,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: DriverHomePalette.border),
            ),
            child: Text(
              trailing,
              style: const TextStyle(
                color: DriverHomePalette.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _fieldTile({
    required IconData icon,
    required Color color,
    required String label,
    required bool placeholder,
    required VoidCallback onTap,
  }) {
    return Material(
      color: DriverHomePalette.card,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: DriverHomePalette.border),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Icon(icon, size: 18, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: placeholder
                        ? DriverHomePalette.textSecondary
                        : DriverHomePalette.textDark,
                    fontSize: 14.5,
                    fontWeight:
                        placeholder ? FontWeight.w500 : FontWeight.w700,
                  ),
                ),
              ),
              const Icon(LucideIcons.chevronRight,
                  size: 16, color: DriverHomePalette.textSecondary),
            ],
          ),
        ),
      ),
    );
  }

  Widget _textField(
    TextEditingController controller,
    String hint,
    IconData icon, {
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(fontSize: 14.5),
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, size: 18, color: DriverHomePalette.textSecondary),
        filled: true,
        fillColor: DriverHomePalette.card,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: DriverHomePalette.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: DriverHomePalette.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide:
              const BorderSide(color: DriverHomePalette.primary, width: 1.4),
        ),
      ),
    );
  }

  Widget _urgentTile() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: DriverHomePalette.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _urgent
              ? DriverHomePalette.warning.withValues(alpha: 0.5)
              : DriverHomePalette.border,
        ),
      ),
      child: SwitchListTile(
        contentPadding: EdgeInsets.zero,
        activeThumbColor: DriverHomePalette.warning,
        title: const Text(
          '⚡ Marquer comme urgent',
          style: TextStyle(
            color: DriverHomePalette.textDark,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: const Text(
          'Notifie en priorité (1 max / 24 h)',
          style: TextStyle(
            color: DriverHomePalette.textSecondary,
            fontSize: 12.5,
          ),
        ),
        value: _urgent,
        onChanged: (v) => setState(() => _urgent = v),
      ),
    );
  }

  Widget _expiryTile() {
    const presets = ['Aucune', '24 h', '48 h', 'Jusqu\'au service'];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: DriverHomePalette.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: DriverHomePalette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.timer,
                  size: 16, color: DriverHomePalette.textSecondary),
              const SizedBox(width: 8),
              const Text(
                'Expiration',
                style: TextStyle(
                  color: DriverHomePalette.textDark,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(presets.length, (i) {
              final selected = _expiryPreset == i;
              return GestureDetector(
                onTap: () => setState(() => _expiryPreset = i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
                  decoration: BoxDecoration(
                    color: selected
                        ? DriverHomePalette.primary
                        : DriverHomePalette.background,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: selected
                          ? DriverHomePalette.primary
                          : DriverHomePalette.border,
                    ),
                  ),
                  child: Text(
                    presets[i],
                    style: TextStyle(
                      color: selected
                          ? Colors.white
                          : DriverHomePalette.textSecondary,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}
