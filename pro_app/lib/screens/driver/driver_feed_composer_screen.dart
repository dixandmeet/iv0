import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

import '../../services/driver/driver_service.dart';
import '../../services/driver/feed_service.dart';
import '../../theme/driver_home_palette.dart';
import '../../utils/photo_picker_permissions.dart';
import '../../widgets/driver/driver_avatar.dart';

/// Durée maximale d'une vidéo publiée sur le fil (garde le fichier léger).
const _maxVideoDuration = Duration(seconds: 60);
const _maxChars = 1000;

/// Composition d'une publication du fil d'actualité (texte + photo ou vidéo).
class DriverFeedComposerScreen extends StatefulWidget {
  const DriverFeedComposerScreen({super.key});

  @override
  State<DriverFeedComposerScreen> createState() =>
      _DriverFeedComposerScreenState();
}

class _DriverFeedComposerScreenState extends State<DriverFeedComposerScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  final _imagePicker = ImagePicker();
  XFile? _image;
  XFile? _video;
  Uint8List? _videoThumbBytes;

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  bool get _hasMedia => _image != null || _video != null;

  bool get _canPublish => _controller.text.trim().isNotEmpty || _hasMedia;

  int get _charsRemaining => _maxChars - _controller.text.characters.length;

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _pickImage(ImageSource source) async {
    final permission = await ensurePhotoPickerPermission(source);
    if (!mounted) return;

    if (!permission.granted) {
      _snack(
        source == ImageSource.camera
            ? 'Autorisation caméra refusée'
            : 'Autorisation galerie refusée',
      );
      return;
    }

    try {
      final file = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 85,
      );
      if (file == null || !mounted) return;
      HapticFeedback.selectionClick();
      setState(() {
        _image = file;
        _video = null;
        _videoThumbBytes = null;
      });
    } on PlatformException {
      if (!mounted) return;
      _snack(
        source == ImageSource.camera
            ? 'Impossible d\'ouvrir la caméra'
            : 'Impossible d\'ouvrir la galerie',
      );
    } catch (_) {
      if (!mounted) return;
      _snack('Impossible de sélectionner l\'image');
    }
  }

  Future<void> _pickVideo(ImageSource source) async {
    final permission = await ensurePhotoPickerPermission(
      source,
      forVideo: true,
    );
    if (!mounted) return;

    if (!permission.granted) {
      _snack(
        source == ImageSource.camera
            ? 'Autorisation caméra refusée'
            : 'Autorisation galerie refusée',
      );
      return;
    }

    try {
      final file = await _imagePicker.pickVideo(
        source: source,
        maxDuration: _maxVideoDuration,
      );
      if (file == null || !mounted) return;

      Uint8List? thumb;
      try {
        thumb = await VideoThumbnail.thumbnailData(
          video: file.path,
          imageFormat: ImageFormat.JPEG,
          maxWidth: 600,
          quality: 60,
        );
      } catch (_) {
        thumb = null;
      }
      if (!mounted) return;

      HapticFeedback.selectionClick();
      setState(() {
        _video = file;
        _image = null;
        _videoThumbBytes = thumb;
      });
    } on PlatformException {
      if (!mounted) return;
      _snack(
        source == ImageSource.camera
            ? 'Impossible d\'ouvrir la caméra'
            : 'Impossible d\'ouvrir la galerie',
      );
    } catch (_) {
      if (!mounted) return;
      _snack('Impossible de sélectionner la vidéo');
    }
  }

  void _removeMedia() {
    HapticFeedback.selectionClick();
    setState(() {
      _image = null;
      _video = null;
      _videoThumbBytes = null;
    });
  }

  void _showMediaSourceSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _AttachMediaSheet(
        onPhotoCamera: () {
          Navigator.of(sheetContext).pop();
          _pickImage(ImageSource.camera);
        },
        onPhotoGallery: () {
          Navigator.of(sheetContext).pop();
          _pickImage(ImageSource.gallery);
        },
        onVideoCamera: () {
          Navigator.of(sheetContext).pop();
          _pickVideo(ImageSource.camera);
        },
        onVideoGallery: () {
          Navigator.of(sheetContext).pop();
          _pickVideo(ImageSource.gallery);
        },
      ),
    );
  }

  Future<void> _publish() async {
    final driverService = context.read<DriverService>();
    final feed = context.read<FeedService>();
    final driver = driverService.driver;

    if (driver == null) {
      _snack('Profil conducteur introuvable');
      return;
    }

    FocusScope.of(context).unfocus();
    final ok = await feed.createPost(
      driverId: driver.id,
      authorName: driver.fullName,
      authorAvatarUrl: driver.avatarUrl,
      body: _controller.text,
      image: _image,
      video: _video,
    );
    if (!mounted) return;

    if (ok) {
      HapticFeedback.lightImpact();
      Navigator.of(context).pop(true);
    } else {
      _snack(feed.errorMessage ?? 'Échec de la publication');
    }
  }

  @override
  Widget build(BuildContext context) {
    final posting = context.watch<FeedService>().posting;
    final driver = context.watch<DriverService>().driver;

    return Scaffold(
      backgroundColor: DriverHomePalette.background,
      appBar: AppBar(
        backgroundColor: DriverHomePalette.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        leadingWidth: 64,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: _RoundIconButton(
            icon: LucideIcons.x,
            onTap: () => Navigator.of(context).maybePop(),
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16, top: 10, bottom: 10),
            child: _PublishButton(
              enabled: _canPublish && !posting && _charsRemaining >= 0,
              posting: posting,
              onTap: _publish,
            ),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DriverAvatarCompact(
                        initials: _initials(driver?.fullName ?? 'C'),
                        imageUrl: driver?.avatarUrl,
                        size: 46,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              driver?.fullName.trim().isNotEmpty == true
                                  ? driver!.fullName
                                  : 'Vous',
                              style: const TextStyle(
                                color: DriverHomePalette.textDark,
                                fontSize: 15.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 9,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: DriverHomePalette.lightGreen,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    LucideIcons.users,
                                    size: 11,
                                    color: DriverHomePalette.primary,
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    'Visible par toute la communauté',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                      color: DriverHomePalette.primary
                                          .withValues(alpha: 0.9),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    autofocus: true,
                    onChanged: (_) => setState(() {}),
                    maxLines: null,
                    minLines: 3,
                    maxLength: _maxChars,
                    textCapitalization: TextCapitalization.sentences,
                    cursorColor: DriverHomePalette.primary,
                    decoration: const InputDecoration(
                      hintText: 'Quoi de neuf sur le terrain ?',
                      hintStyle: TextStyle(
                        color: DriverHomePalette.textSecondary,
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                      border: InputBorder.none,
                      counterText: '',
                      contentPadding: EdgeInsets.zero,
                      isDense: true,
                    ),
                    style: const TextStyle(
                      color: DriverHomePalette.textDark,
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 18),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    alignment: Alignment.topCenter,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      child: _image != null
                          ? _MediaPreviewCard(
                              key: const ValueKey('image'),
                              onRemove: _removeMedia,
                              child: Image.file(
                                File(_image!.path),
                                fit: BoxFit.cover,
                              ),
                            )
                          : _video != null
                          ? _MediaPreviewCard(
                              key: const ValueKey('video'),
                              isVideo: true,
                              onRemove: _removeMedia,
                              child: _videoThumbBytes != null
                                  ? Image.memory(
                                      _videoThumbBytes!,
                                      fit: BoxFit.cover,
                                    )
                                  : Container(color: Colors.black87),
                            )
                          : _EmptyMediaHint(
                              key: const ValueKey('empty'),
                              onTap: _showMediaSourceSheet,
                            ),
                    ),
                  ),
                ],
              ),
            ),
            _BottomToolbar(
              hasMedia: _hasMedia,
              charsRemaining: _charsRemaining,
              onAttach: _showMediaSourceSheet,
            ),
          ],
        ),
      ),
    );
  }

  String _initials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    if (parts.isNotEmpty) return parts.first[0].toUpperCase();
    return '?';
  }
}

class _RoundIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _RoundIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: DriverHomePalette.lightGreen,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(9),
          child: Icon(icon, size: 18, color: DriverHomePalette.textDark),
        ),
      ),
    );
  }
}

class _PublishButton extends StatelessWidget {
  final bool enabled;
  final bool posting;
  final VoidCallback onTap;

  const _PublishButton({
    required this.enabled,
    required this.posting,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        gradient: enabled
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  DriverHomePalette.gradientStart,
                  DriverHomePalette.gradientEnd,
                ],
              )
            : null,
        color: enabled ? null : DriverHomePalette.border,
        borderRadius: BorderRadius.circular(999),
        boxShadow: enabled
            ? [
                BoxShadow(
                  color: DriverHomePalette.gradientEnd.withValues(alpha: 0.28),
                  blurRadius: 12,
                  offset: const Offset(0, 5),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: enabled ? onTap : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: posting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    'Publier',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14.5,
                      color: enabled
                          ? Colors.white
                          : DriverHomePalette.textSecondary,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _MediaPreviewCard extends StatelessWidget {
  final Widget child;
  final bool isVideo;
  final VoidCallback onRemove;

  const _MediaPreviewCard({
    super.key,
    required this.child,
    this.isVideo = false,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: DriverHomePalette.border),
        boxShadow: const [
          BoxShadow(
            color: DriverHomePalette.cardShadow,
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: AspectRatio(
          aspectRatio: 4 / 3,
          child: Stack(
            fit: StackFit.expand,
            children: [
              child,
              if (isVideo)
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.center,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.35),
                      ],
                    ),
                  ),
                ),
              if (isVideo)
                Center(
                  child: Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.92),
                      shape: BoxShape.circle,
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 10,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Icon(
                      LucideIcons.play,
                      color: DriverHomePalette.gradientEnd,
                      size: 26,
                    ),
                  ),
                ),
              if (isVideo)
                Positioned(
                  left: 12,
                  bottom: 12,
                  child: _GlassChip(
                    icon: LucideIcons.video,
                    label: 'Vidéo · 60 s max',
                  ),
                ),
              Positioned(
                top: 10,
                right: 10,
                child: _GlassRemoveButton(onTap: onRemove),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlassChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _GlassChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.32),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 12, color: Colors.white),
              const SizedBox(width: 5),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlassRemoveButton extends StatelessWidget {
  final VoidCallback onTap;

  const _GlassRemoveButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Material(
          color: Colors.black.withValues(alpha: 0.32),
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: const Padding(
              padding: EdgeInsets.all(8),
              child: Icon(LucideIcons.x, size: 16, color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyMediaHint extends StatelessWidget {
  final VoidCallback onTap;

  const _EmptyMediaHint({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: DottedBorderBox(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
          child: Column(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: DriverHomePalette.lightGreen,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  LucideIcons.imagePlus,
                  color: DriverHomePalette.primary,
                  size: 20,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Ajouter une photo ou une vidéo',
                style: TextStyle(
                  color: DriverHomePalette.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 14.5,
                ),
              ),
              const SizedBox(height: 3),
              const Text(
                'Un visuel capte davantage l\'attention de l\'équipe',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: DriverHomePalette.textSecondary,
                  fontSize: 12.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Cadre à bordure pointillée léger (sans dépendance externe).
class DottedBorderBox extends StatelessWidget {
  final Widget child;

  const DottedBorderBox({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _DashedBorderPainter(), child: child);
  }
}

class _DashedBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(20),
    );
    final paint = Paint()
      ..color = DriverHomePalette.primary.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;

    final path = Path()..addRRect(rrect);
    final metrics = path.computeMetrics();
    for (final metric in metrics) {
      const dashWidth = 6.0;
      const dashGap = 5.0;
      var distance = 0.0;
      while (distance < metric.length) {
        final next = distance + dashWidth;
        canvas.drawPath(
          metric.extractPath(distance, next.clamp(0, metric.length)),
          paint,
        );
        distance = next + dashGap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _BottomToolbar extends StatelessWidget {
  final bool hasMedia;
  final int charsRemaining;
  final VoidCallback onAttach;

  const _BottomToolbar({
    required this.hasMedia,
    required this.charsRemaining,
    required this.onAttach,
  });

  @override
  Widget build(BuildContext context) {
    final showCounter = charsRemaining <= 120;
    final overLimit = charsRemaining < 0;

    return DecoratedBox(
      decoration: const BoxDecoration(
        color: DriverHomePalette.card,
        border: Border(top: BorderSide(color: DriverHomePalette.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 16, 8),
          child: Row(
            children: [
              Material(
                color: hasMedia
                    ? DriverHomePalette.lightGreen
                    : Colors.transparent,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: onAttach,
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Icon(
                      LucideIcons.imagePlus,
                      size: 21,
                      color: hasMedia
                          ? DriverHomePalette.primary
                          : DriverHomePalette.textSecondary,
                    ),
                  ),
                ),
              ),
              const Spacer(),
              if (showCounter) ...[
                if (charsRemaining <= 20)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Text(
                      '$charsRemaining',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: overLimit
                            ? DriverHomePalette.danger
                            : DriverHomePalette.textSecondary,
                      ),
                    ),
                  ),
                SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    value: ((_maxChars - charsRemaining) / _maxChars).clamp(
                      0,
                      1,
                    ),
                    strokeWidth: 2.4,
                    backgroundColor: DriverHomePalette.border,
                    color: overLimit
                        ? DriverHomePalette.danger
                        : DriverHomePalette.primary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _AttachMediaSheet extends StatelessWidget {
  final VoidCallback onPhotoCamera;
  final VoidCallback onPhotoGallery;
  final VoidCallback onVideoCamera;
  final VoidCallback onVideoGallery;

  const _AttachMediaSheet({
    required this.onPhotoCamera,
    required this.onPhotoGallery,
    required this.onVideoCamera,
    required this.onVideoGallery,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: DriverHomePalette.card,
          borderRadius: BorderRadius.circular(24),
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 24,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: DriverHomePalette.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 14, 20, 4),
              child: Row(
                children: [
                  Text(
                    'Ajouter un média',
                    style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w800,
                      color: DriverHomePalette.textDark,
                    ),
                  ),
                ],
              ),
            ),
            _SheetTile(
              icon: LucideIcons.camera,
              title: 'Prendre une photo',
              onTap: onPhotoCamera,
            ),
            _SheetTile(
              icon: LucideIcons.image,
              title: 'Choisir une photo',
              subtitle: 'Depuis la galerie',
              onTap: onPhotoGallery,
            ),
            _SheetTile(
              icon: LucideIcons.video,
              title: 'Filmer une vidéo',
              subtitle: '60 secondes maximum',
              onTap: onVideoCamera,
            ),
            _SheetTile(
              icon: LucideIcons.film,
              title: 'Choisir une vidéo',
              subtitle: 'Depuis la galerie · 60 s maximum',
              onTap: onVideoGallery,
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _SheetTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  const _SheetTile({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: DriverHomePalette.lightGreen,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 18, color: DriverHomePalette.primary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: DriverHomePalette.textDark,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: DriverHomePalette.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Icon(
              LucideIcons.chevronRight,
              size: 16,
              color: DriverHomePalette.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}
