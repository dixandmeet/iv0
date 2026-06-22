import 'package:flutter/material.dart';
import '../../theme/app_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class BottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const BottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final navBg = isDark ? const Color(0xFF141A23) : Colors.white;
    final borderCol = isDark ? const Color(0x17FFFFFF) : const Color(0xFFE7EAF0);
    const activeColor = Color(0xFF1B66F5);
    final inactiveColor = isDark ? const Color(0xFF6B7889) : const Color(0xFF8F9BB3);

    return Container(
      decoration: BoxDecoration(
        color: navBg,
        border: Border(
          top: BorderSide(color: borderCol, width: 1),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 60,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(
                index: 0,
                icon: LucideIcons.home,
                activeIcon: LucideIcons.home,
                label: 'Accueil',
                activeColor: activeColor,
                inactiveColor: inactiveColor,
              ),
              _buildNavItem(
                index: 1,
                icon: LucideIcons.route,
                activeIcon: LucideIcons.route,
                label: 'Itinéraire',
                activeColor: activeColor,
                inactiveColor: inactiveColor,
              ),
              _buildNavItem(
                index: 2,
                icon: LucideIcons.clock,
                activeIcon: LucideIcons.clock,
                label: 'Horaires',
                activeColor: activeColor,
                inactiveColor: inactiveColor,
              ),
              _buildNavItem(
                index: 3,
                icon: LucideIcons.menu,
                activeIcon: LucideIcons.menu,
                label: 'Menu',
                activeColor: activeColor,
                inactiveColor: inactiveColor,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required Color activeColor,
    required Color inactiveColor,
  }) {
    final isActive = index == currentIndex;
    final itemColor = isActive ? activeColor : inactiveColor;

    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onTap(index),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isActive ? activeIcon : icon,
                color: itemColor,
                size: 22,
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: hankenGrotesk(
                  fontSize: 11,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.w600,
                  color: itemColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
