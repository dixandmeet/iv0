import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../theme/driver_home_palette.dart';

/// Avatar conducteur : photo réseau ou initiales, avec badge d'édition optionnel.
class DriverAvatar extends StatelessWidget {
  final String initials;
  final String? imageUrl;
  final double size;
  final bool loading;
  final bool editable;
  final VoidCallback? onTap;
  final Color? borderColor;
  final double borderWidth;

  const DriverAvatar({
    super.key,
    required this.initials,
    this.imageUrl,
    this.size = 80,
    this.loading = false,
    this.editable = false,
    this.onTap,
    this.borderColor,
    this.borderWidth = 2,
  });

  bool get _hasImage => imageUrl != null && imageUrl!.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final ring = borderColor ?? Colors.white.withValues(alpha: 0.35);

    return GestureDetector(
      onTap: loading ? null : onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              shape: BoxShape.circle,
              border: Border.all(color: ring, width: borderWidth),
            ),
            child: ClipOval(
              child: _hasImage
                  ? Image.network(
                      imageUrl!,
                      fit: BoxFit.cover,
                      width: size,
                      height: size,
                      errorBuilder: (_, _, _) => _initialsFallback(),
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        return _initialsFallback();
                      },
                    )
                  : _initialsFallback(),
            ),
          ),
          if (loading)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.35),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          if (editable && !loading)
            Positioned(
              right: -2,
              bottom: -2,
              child: Container(
                width: size * 0.34,
                height: size * 0.34,
                decoration: BoxDecoration(
                  color: DriverHomePalette.primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: Icon(
                  _hasImage ? LucideIcons.pencil : LucideIcons.camera,
                  size: size * 0.16,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _initialsFallback() {
    return Container(
      color: DriverHomePalette.softGreen.withValues(alpha: 0.35),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.34,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
        ),
      ),
    );
  }
}

/// Pastille avatar compacte pour le menu (fond vert clair).
class DriverAvatarCompact extends StatelessWidget {
  final String initials;
  final String? imageUrl;
  final double size;

  const DriverAvatarCompact({
    super.key,
    required this.initials,
    this.imageUrl,
    this.size = 56,
  });

  @override
  Widget build(BuildContext context) {
    final hasImage = imageUrl != null && imageUrl!.trim().isNotEmpty;

    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: DriverHomePalette.softGreen,
        shape: BoxShape.circle,
      ),
      child: ClipOval(
        child: hasImage
            ? Image.network(
                imageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _fallback(),
              )
            : _fallback(),
      ),
    );
  }

  Widget _fallback() {
    return Center(
      child: initials.trim().isEmpty
          ? const Icon(
              LucideIcons.userRound,
              size: 28,
              color: DriverHomePalette.primary,
            )
          : Text(
              initials,
              style: TextStyle(
                color: DriverHomePalette.primary,
                fontSize: size * 0.32,
                fontWeight: FontWeight.w800,
              ),
            ),
    );
  }
}
