import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class FloatingTopBar extends StatelessWidget {
  final VoidCallback onBack;
  final Widget titleArea;
  final Widget? trailing;

  const FloatingTopBar({
    super.key,
    required this.onBack,
    required this.titleArea,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.bg.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Material(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: onBack,
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
                ),
                child: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 15,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: titleArea),
          ?trailing,
        ],
      ),
    );
  }
}

class LiveBadge extends StatelessWidget {
  final String label;
  const LiveBadge({super.key, this.label = 'Direct'});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: const BoxDecoration(
            color: AppColors.accent,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: AppColors.accent,
          ),
        ),
      ],
    );
  }
}
