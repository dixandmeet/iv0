import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../theme/driver_home_palette.dart';

/// Barre de recherche M3 avec animation de focus.
class TerrainSearchField extends StatefulWidget {
  final ValueChanged<String>? onChanged;
  final VoidCallback? onTap;
  final VoidCallback? onClear;
  final String query;
  final bool expanded;

  const TerrainSearchField({
    super.key,
    this.onChanged,
    this.onTap,
    this.onClear,
    this.query = '',
    this.expanded = false,
  });

  @override
  State<TerrainSearchField> createState() => _TerrainSearchFieldState();
}

class _TerrainSearchFieldState extends State<TerrainSearchField> {
  final _focus = FocusNode();
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.query);
    _focus.addListener(() => setState(() {}));
  }

  @override
  void didUpdateWidget(covariant TerrainSearchField old) {
    super.didUpdateWidget(old);
    if (widget.query != _ctrl.text) _ctrl.text = widget.query;
  }

  @override
  void dispose() {
    _focus.dispose();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final focused = _focus.hasFocus || widget.expanded;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: focused
                ? DriverHomePalette.primary.withValues(alpha: 0.12)
                : DriverHomePalette.cardShadow,
            blurRadius: focused ? 18 : 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: DriverHomePalette.card,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(24),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: focused
                    ? DriverHomePalette.primary.withValues(alpha: 0.55)
                    : DriverHomePalette.border,
                width: focused ? 1.5 : 1,
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Icon(
                  LucideIcons.search,
                  size: 19,
                  color: focused
                      ? DriverHomePalette.primary
                      : DriverHomePalette.textSecondary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    focusNode: _focus,
                    onChanged: widget.onChanged,
                    style: const TextStyle(
                      color: DriverHomePalette.textDark,
                      fontSize: 14.5,
                    ),
                    decoration: const InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      hintText:
                          'Rechercher un véhicule, une ligne, un conducteur...',
                      hintStyle: TextStyle(
                        color: DriverHomePalette.textSecondary,
                        fontSize: 14.5,
                      ),
                    ),
                  ),
                ),
                if (_ctrl.text.isNotEmpty)
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(
                      LucideIcons.x,
                      size: 18,
                      color: DriverHomePalette.textSecondary,
                    ),
                    onPressed: () {
                      _ctrl.clear();
                      widget.onClear?.call();
                      widget.onChanged?.call('');
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
