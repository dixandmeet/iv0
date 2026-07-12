import 'package:flutter/material.dart';
import '../models/line.dart';
import '../models/transport_mode.dart';
import '../models/route_data.dart';
import '../services/transport_repository.dart';
import '../theme/app_theme.dart';

class PriseServiceScreen extends StatefulWidget {
  final VoidCallback onBack;
  final TransportDataSource repository;
  final void Function(
    BusLine line,
    LineDirection direction,
    RouteJourney journey,
  )
  onStart;

  const PriseServiceScreen({
    super.key,
    required this.onBack,
    required this.repository,
    required this.onStart,
  });

  @override
  State<PriseServiceScreen> createState() => _PriseServiceScreenState();
}

class _PriseServiceScreenState extends State<PriseServiceScreen> {
  int _step = 0;
  String _search = '';
  String? _ligne;
  String? _sens;
  bool _gps = false;
  bool _loadingLines = true;
  bool _starting = false;
  String? _loadError;
  List<BusLine> _lines = const [];
  final _vehiculeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadLines();
  }

  Future<void> _loadLines({bool refresh = false}) async {
    setState(() {
      _loadingLines = true;
      _loadError = null;
    });
    try {
      final lines = await widget.repository.fetchLines(refresh: refresh);
      if (!mounted) return;
      setState(() => _lines = lines);
    } catch (error) {
      if (!mounted) return;
      setState(() => _loadError = error.toString());
    } finally {
      if (mounted) setState(() => _loadingLines = false);
    }
  }

  @override
  void dispose() {
    _vehiculeController.dispose();
    super.dispose();
  }

  BusLine? get _selectedLine =>
      _ligne == null ? null : _lines.firstWhere((l) => l.key == _ligne);

  void _pickLigne(String key) {
    setState(() {
      _ligne = key;
      _sens = null;
    });
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted && _step == 0) setState(() => _step = 1);
    });
  }

  void _pickSens(String key) {
    setState(() => _sens = key);
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted && _step == 1) setState(() => _step = 2);
    });
  }

  void _back() {
    if (_step == 0) {
      widget.onBack();
    } else {
      setState(() => _step -= 1);
    }
  }

  bool get _canContinue {
    if (_step == 0) return _ligne != null;
    if (_step == 1) return _sens != null;
    if (_step == 3) return _gps;
    return true;
  }

  Future<void> _footerAction() async {
    if (!_canContinue || _starting) return;
    if (_step == 3) {
      final line = _selectedLine!;
      final dir = line.directions.firstWhere((d) => d.key == _sens);
      setState(() => _starting = true);
      try {
        final journey = await widget.repository.fetchJourney(line, dir);
        if (!mounted) return;
        widget.onStart(line, dir, journey);
      } catch (error) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Circuit indisponible : $error')),
        );
        setState(() => _starting = false);
      }
    } else {
      setState(() => _step = (_step + 1).clamp(0, 3));
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredLines = _lines
        .where(
          (l) =>
              _search.trim().isEmpty ||
              l.label.toLowerCase().contains(_search.trim().toLowerCase()),
        )
        .toList();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        backgroundColor: AppColors.bg,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: Row(
                  children: [
                    _BackButton(onTap: _back),
                    const SizedBox(width: 8),
                    const Text(
                      'Prise de service',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 22),
                child: Row(
                  children: List.generate(4, (i) {
                    return Expanded(
                      child: Container(
                        margin: EdgeInsets.only(right: i == 3 ? 0 : 6),
                        height: 4,
                        decoration: BoxDecoration(
                          color: i <= _step
                              ? AppColors.accent
                              : Colors.white.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    );
                  }),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_step == 0)
                        if (_loadingLines)
                          const Padding(
                            padding: EdgeInsets.only(top: 80),
                            child: Center(child: CircularProgressIndicator()),
                          )
                        else if (_loadError != null)
                          _buildLoadError()
                        else
                          _buildStepLigne(filteredLines),
                      if (_step == 1) _buildStepSens(),
                      if (_step == 2) _buildStepVehicule(),
                      if (_step == 3) _buildStepGps(),
                      if (_step == 2 || _step == 3) ...[
                        const SizedBox(height: 26),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _canContinue && !_starting
                                ? _footerAction
                                : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _canContinue
                                  ? AppColors.accent
                                  : Colors.white.withValues(alpha: 0.12),
                              foregroundColor: AppColors.accentDark,
                              disabledBackgroundColor: Colors.white.withValues(
                                alpha: 0.12,
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              elevation: 0,
                            ),
                            child: _starting
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppColors.accentDark,
                                    ),
                                  )
                                : Text(
                                    _step == 3
                                        ? 'Démarrer le service'
                                        : 'Continuer',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadError() {
    return Padding(
      padding: const EdgeInsets.only(top: 48),
      child: Center(
        child: Column(
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              size: 38,
              color: AppColors.amber,
            ),
            const SizedBox(height: 14),
            const Text(
              'Données Naolib indisponibles',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              _loadError!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white54, height: 1.4),
            ),
            const SizedBox(height: 18),
            OutlinedButton.icon(
              onPressed: () => _loadLines(refresh: true),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepLigne(List<BusLine> filteredLines) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quelle ligne ?',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Sélectionnez la ligne que vous prenez en charge.',
          style: TextStyle(fontSize: 14, color: Colors.white54),
        ),
        const SizedBox(height: 18),
        TextField(
          onChanged: (v) => setState(() => _search = v),
          style: const TextStyle(fontSize: 14.5, color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Rechercher une ligne…',
            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.32)),
            prefixIcon: const Icon(
              Icons.search_rounded,
              size: 18,
              color: Colors.white38,
            ),
            filled: true,
            fillColor: const Color(0xFF0D1512),
            contentPadding: const EdgeInsets.symmetric(
              vertical: 12,
              horizontal: 15,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(13),
              borderSide: BorderSide(
                color: Colors.white.withValues(alpha: 0.13),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(13),
              borderSide: BorderSide(
                color: Colors.white.withValues(alpha: 0.13),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(13),
              borderSide: const BorderSide(color: AppColors.accent),
            ),
          ),
        ),
        const SizedBox(height: 14),
        if (filteredLines.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Center(
              child: Text(
                'Aucune ligne pour « $_search ».',
                style: const TextStyle(fontSize: 13.5, color: Colors.white38),
              ),
            ),
          ),
        ...filteredLines.map((l) {
          final sel = _ligne == l.key;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Material(
              color: sel
                  ? AppColors.accent.withValues(alpha: 0.09)
                  : Colors.white.withValues(alpha: 0.02),
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => _pickLigne(l.key),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 15,
                    vertical: 13,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: sel
                          ? AppColors.accent
                          : Colors.white.withValues(alpha: 0.09),
                      width: sel ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: sel
                              ? AppColors.accent
                              : AppColors.accent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          l.mode.icon,
                          size: 19,
                          color: sel ? AppColors.accentDark : AppColors.accent,
                        ),
                      ),
                      const SizedBox(width: 13),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l.label,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              l.desc,
                              style: const TextStyle(
                                fontSize: 12.5,
                                color: Colors.white38,
                              ),
                            ),
                          ],
                        ),
                      ),
                      AnimatedOpacity(
                        opacity: sel ? 1 : 0,
                        duration: const Duration(milliseconds: 150),
                        child: Container(
                          width: 20,
                          height: 20,
                          decoration: const BoxDecoration(
                            color: AppColors.accent,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check_rounded,
                            size: 13,
                            color: AppColors.accentDark,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildStepSens() {
    final line = _selectedLine;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quel sens ?',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Direction du service pour ${line?.label ?? ''}.',
          style: const TextStyle(fontSize: 14, color: Colors.white54),
        ),
        const SizedBox(height: 18),
        ...?line?.directions.map((d) {
          final sel = _sens == d.key;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Material(
              color: sel
                  ? AppColors.accent.withValues(alpha: 0.09)
                  : Colors.white.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(15),
              child: InkWell(
                borderRadius: BorderRadius.circular(15),
                onTap: () => _pickSens(d.key),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(
                      color: sel
                          ? AppColors.accent
                          : Colors.white.withValues(alpha: 0.1),
                      width: sel ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          d.label,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      AnimatedOpacity(
                        opacity: sel ? 1 : 0,
                        duration: const Duration(milliseconds: 150),
                        child: Container(
                          width: 22,
                          height: 22,
                          decoration: const BoxDecoration(
                            color: AppColors.accent,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check_rounded,
                            size: 13,
                            color: AppColors.accentDark,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildStepVehicule() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: const TextSpan(
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
              color: Colors.white,
            ),
            children: [
              TextSpan(text: 'Véhicule '),
              TextSpan(
                text: '(facultatif)',
                style: TextStyle(
                  color: Colors.white38,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Renseignez le numéro si vous le connaissez déjà.',
          style: TextStyle(fontSize: 14, color: Colors.white54),
        ),
        const SizedBox(height: 18),
        const Text(
          'Numéro de véhicule',
          style: TextStyle(fontSize: 13, color: Colors.white70),
        ),
        const SizedBox(height: 7),
        TextField(
          controller: _vehiculeController,
          style: const TextStyle(fontSize: 15, color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Ex. 4127',
            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.32)),
            filled: true,
            fillColor: const Color(0xFF0D1512),
            contentPadding: const EdgeInsets.symmetric(
              vertical: 13,
              horizontal: 15,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Colors.white.withValues(alpha: 0.14),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Colors.white.withValues(alpha: 0.14),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.accent),
            ),
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          'Vous pourrez le confirmer plus tard si vous ne le connaissez pas encore.',
          style: TextStyle(fontSize: 12.5, color: Colors.white38),
        ),
      ],
    );
  }

  Widget _buildStepGps() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Position & suivi',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          "Aule Pro transmet votre position pendant le service pour informer les voyageurs et alimenter le Contrôle.",
          style: TextStyle(fontSize: 14, color: Colors.white54, height: 1.5),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Autoriser la transmission de ma position',
                  style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
                ),
              ),
              Switch(
                value: _gps,
                onChanged: (v) => setState(() => _gps = v),
                activeThumbColor: Colors.white,
                activeTrackColor: AppColors.accent,
                inactiveThumbColor: Colors.white,
                inactiveTrackColor: Colors.white.withValues(alpha: 0.14),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        for (final txt in const [
          'Environ toutes les 5 secondes au premier plan',
          'Toutes les 15 secondes en arrière-plan',
          'Arrêt immédiat à la fin du service',
        ])
          Padding(
            padding: const EdgeInsets.only(bottom: 9),
            child: Row(
              children: [
                Container(
                  width: 5,
                  height: 5,
                  decoration: const BoxDecoration(
                    color: AppColors.accent,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    txt,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: Colors.white54,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _BackButton extends StatelessWidget {
  final VoidCallback onTap;
  const _BackButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.04),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: const Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 17,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
