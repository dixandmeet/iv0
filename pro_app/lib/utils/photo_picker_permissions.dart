import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

/// Résultat d'une demande d'autorisation caméra / galerie.
class PhotoPickerPermissionResult {
  final bool granted;
  final bool permanentlyDenied;

  const PhotoPickerPermissionResult({
    required this.granted,
    this.permanentlyDenied = false,
  });
}

/// Demande les autorisations nécessaires avant [ImagePicker.pickImage] ou
/// [ImagePicker.pickVideo] ([forVideo] sélectionne le bon permis Android).
Future<PhotoPickerPermissionResult> ensurePhotoPickerPermission(
  ImageSource source, {
  bool forVideo = false,
}) async {
  if (source == ImageSource.camera) {
    return _request(Permission.camera);
  }

  if (Platform.isIOS) {
    return _request(Permission.photos, allowLimited: true);
  }

  if (Platform.isAndroid) {
    // Android 13+ (API 33) : READ_MEDIA_IMAGES / READ_MEDIA_VIDEO séparés.
    final permission = forVideo ? Permission.videos : Permission.photos;
    final status = await permission.request();
    if (status.isGranted || status.isLimited) {
      return const PhotoPickerPermissionResult(granted: true);
    }
    if (status.isPermanentlyDenied) {
      return const PhotoPickerPermissionResult(
        granted: false,
        permanentlyDenied: true,
      );
    }

    // Android 12 et inférieur : READ_EXTERNAL_STORAGE
    return _request(Permission.storage, allowLimited: true);
  }

  return const PhotoPickerPermissionResult(granted: true);
}

Future<PhotoPickerPermissionResult> _request(
  Permission permission, {
  bool allowLimited = false,
}) async {
  final status = await permission.request();
  final granted = status.isGranted || (allowLimited && status.isLimited);
  return PhotoPickerPermissionResult(
    granted: granted,
    permanentlyDenied: status.isPermanentlyDenied,
  );
}
