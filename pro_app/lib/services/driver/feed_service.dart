import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:video_compress/video_compress.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

import '../../models/driver/feed_comment.dart';
import '../../models/driver/feed_post.dart';
import '../supabase_service.dart';

/// Taille max envoyée après compression (marge sous le quota du bucket
/// `feed-media`, cf. migration 061) : au-delà, on préfère un message clair
/// plutôt que le 413 brut de Supabase Storage.
const _maxVideoUploadBytes = 60 * 1024 * 1024;

/// Levée quand une vidéo reste trop volumineuse même après compression.
class FeedVideoTooLargeException implements Exception {}

/// Fil d'actualité communautaire Aule Pro (table `feed_posts`).
///
/// Mur partagé : tous les utilisateurs authentifiés voient tous les posts.
/// Chacun publie en son nom (texte + image ou vidéo) et supprime ses propres
/// posts. Les médias vont dans le bucket Storage `feed-media`.
class FeedService with ChangeNotifier {
  final SupabaseService _supabase;

  FeedService({required SupabaseService supabaseService})
    : _supabase = supabaseService;

  static const _bucket = 'feed-media';
  static const _uuid = Uuid();

  List<FeedPost> _posts = [];
  bool _loading = false;
  bool _posting = false;
  bool _loaded = false;
  String? _errorMessage;

  List<FeedPost> get posts => List.unmodifiable(_posts);
  bool get loading => _loading;
  bool get posting => _posting;

  /// `true` une fois la première récupération effectuée (succès ou échec).
  bool get loaded => _loaded;
  String? get errorMessage => _errorMessage;

  /// Charge les derniers posts du fil (ordre antéchronologique), avec l'état
  /// « aimé par moi » si [driverId] est fourni.
  Future<void> fetchFeed({String? driverId, bool silent = false}) async {
    final client = _supabase.client;
    if (client == null || _supabase.isOfflineMode) {
      _loaded = true;
      return;
    }

    if (!silent) {
      _loading = true;
      notifyListeners();
    }

    try {
      final rows = await client
          .from('feed_posts')
          .select()
          .order('created_at', ascending: false)
          .limit(50);

      var posts = (rows as List)
          .map((r) => FeedPost.fromJson(r as Map<String, dynamic>))
          .toList();

      if (driverId != null && posts.isNotEmpty) {
        final likedIds = await _fetchLikedPostIds(
          client,
          driverId,
          posts.map((p) => p.id).toList(),
        );
        posts = posts
            .map((p) => p.copyWith(likedByMe: likedIds.contains(p.id)))
            .toList();
      }

      _posts = posts;
      _errorMessage = null;
    } catch (e) {
      debugPrint('Aule: feed fetch failed ($e)');
      _errorMessage = 'Impossible de charger le fil';
    } finally {
      _loading = false;
      _loaded = true;
      notifyListeners();
    }
  }

  Future<Set<String>> _fetchLikedPostIds(
    SupabaseClient client,
    String driverId,
    List<String> postIds,
  ) async {
    try {
      final rows = await client
          .from('feed_post_likes')
          .select('post_id')
          .eq('driver_id', driverId)
          .inFilter('post_id', postIds);
      return (rows as List)
          .map((r) => (r as Map<String, dynamic>)['post_id'] as String)
          .toSet();
    } catch (e) {
      debugPrint('Aule: feed likes fetch failed ($e)');
      return {};
    }
  }

  /// Ajoute ou retire le like du conducteur courant sur [post] (optimiste).
  Future<void> toggleLike(FeedPost post, String driverId) async {
    final client = _supabase.client;
    if (client == null || _supabase.isOfflineMode) return;

    final index = _posts.indexWhere((p) => p.id == post.id);
    if (index < 0) return;

    final wasLiked = _posts[index].likedByMe;
    _posts[index] = _posts[index].copyWith(
      likedByMe: !wasLiked,
      likesCount: wasLiked
          ? (_posts[index].likesCount - 1).clamp(0, 1 << 30)
          : _posts[index].likesCount + 1,
    );
    notifyListeners();

    try {
      if (wasLiked) {
        await client
            .from('feed_post_likes')
            .delete()
            .eq('post_id', post.id)
            .eq('driver_id', driverId);
      } else {
        await client.from('feed_post_likes').insert({
          'post_id': post.id,
          'driver_id': driverId,
        });
      }
    } catch (e) {
      debugPrint('Aule: feed like toggle failed ($e)');
      final revert = _posts.indexWhere((p) => p.id == post.id);
      if (revert >= 0) {
        _posts[revert] = _posts[revert].copyWith(
          likedByMe: wasLiked,
          likesCount: post.likesCount,
        );
        notifyListeners();
      }
    }
  }

  /// Charge les commentaires d'un post (ordre chronologique).
  Future<List<FeedComment>> fetchComments(String postId) async {
    final client = _supabase.client;
    if (client == null || _supabase.isOfflineMode) return [];

    try {
      final rows = await client
          .from('feed_post_comments')
          .select()
          .eq('post_id', postId)
          .order('created_at', ascending: true);
      return (rows as List)
          .map((r) => FeedComment.fromJson(r as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Aule: feed comments fetch failed ($e)');
      return [];
    }
  }

  /// Publie un commentaire. Retourne le commentaire créé, ou `null` en cas
  /// d'échec.
  Future<FeedComment?> addComment({
    required String postId,
    required String driverId,
    String? authorName,
    String? authorAvatarUrl,
    required String body,
  }) async {
    final client = _supabase.client;
    final text = body.trim();
    if (client == null || _supabase.isOfflineMode || text.isEmpty) {
      return null;
    }

    try {
      final row = await client
          .from('feed_post_comments')
          .insert({
            'post_id': postId,
            'author_driver_id': driverId,
            'author_name': authorName,
            'author_avatar_url': authorAvatarUrl,
            'body': text,
          })
          .select()
          .single();

      final comment = FeedComment.fromJson(row);
      final index = _posts.indexWhere((p) => p.id == postId);
      if (index >= 0) {
        _posts[index] = _posts[index].copyWith(
          commentsCount: _posts[index].commentsCount + 1,
        );
        notifyListeners();
      }
      return comment;
    } catch (e) {
      debugPrint('Aule: feed comment post failed ($e)');
      return null;
    }
  }

  /// Supprime un commentaire.
  Future<bool> deleteComment(FeedComment comment) async {
    final client = _supabase.client;
    if (client == null || _supabase.isOfflineMode) return false;

    try {
      await client.from('feed_post_comments').delete().eq('id', comment.id);
      final index = _posts.indexWhere((p) => p.id == comment.postId);
      if (index >= 0) {
        _posts[index] = _posts[index].copyWith(
          commentsCount: (_posts[index].commentsCount - 1).clamp(0, 1 << 30),
        );
        notifyListeners();
      }
      return true;
    } catch (e) {
      debugPrint('Aule: feed comment delete failed ($e)');
      return false;
    }
  }

  /// Publie un post. Retourne `true` en cas de succès.
  ///
  /// [image] et [video] sont mutuellement exclusifs (un seul média par post).
  Future<bool> createPost({
    required String driverId,
    String? authorName,
    String? authorAvatarUrl,
    String? body,
    XFile? image,
    XFile? video,
  }) async {
    final client = _supabase.client;
    final user = client?.auth.currentUser;
    if (client == null || _supabase.isOfflineMode) {
      _errorMessage = 'Publication indisponible hors ligne';
      notifyListeners();
      return false;
    }
    if (user == null || user.isAnonymous) {
      _errorMessage = 'Session invalide — reconnectez-vous';
      notifyListeners();
      return false;
    }

    final text = body?.trim();
    final hasText = text != null && text.isNotEmpty;
    if (!hasText && image == null && video == null) {
      _errorMessage = 'Ajoutez un texte, une photo ou une vidéo';
      notifyListeners();
      return false;
    }

    _posting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      String? mediaUrl;
      String? thumbnailUrl;
      var mediaType = FeedMediaType.none;
      if (video != null) {
        final upload = await _uploadVideo(client, user.id, video);
        mediaUrl = upload.videoUrl;
        thumbnailUrl = upload.thumbnailUrl;
        mediaType = FeedMediaType.video;
      } else if (image != null) {
        mediaUrl = await _uploadImage(client, user.id, image);
        mediaType = FeedMediaType.image;
      }

      final row = await client
          .from('feed_posts')
          .insert({
            'author_driver_id': driverId,
            'author_name': authorName,
            'author_avatar_url': authorAvatarUrl,
            'body': hasText ? text : null,
            'media_url': mediaUrl,
            'media_thumbnail_url': thumbnailUrl,
            'media_type': mediaType.dbValue,
          })
          .select()
          .single();

      _posts.insert(0, FeedPost.fromJson(row));
      _posting = false;
      notifyListeners();
      return true;
    } on FeedVideoTooLargeException {
      _errorMessage = 'Vidéo trop volumineuse — réduisez la durée et réessayez';
      _posting = false;
      notifyListeners();
      return false;
    } on StorageException catch (e) {
      debugPrint('Aule: feed media upload failed (${e.statusCode}) $e');
      _errorMessage = video != null
          ? 'Échec de l\'envoi de la vidéo'
          : 'Échec de l\'envoi de l\'image';
      _posting = false;
      notifyListeners();
      return false;
    } catch (e) {
      debugPrint('Aule: feed post failed ($e)');
      _errorMessage = 'Échec de la publication';
      _posting = false;
      notifyListeners();
      return false;
    }
  }

  /// Supprime un post (et son média associé, au mieux).
  Future<bool> deletePost(FeedPost post) async {
    final client = _supabase.client;
    if (client == null || _supabase.isOfflineMode) return false;

    try {
      await client.from('feed_posts').delete().eq('id', post.id);

      // Suppression du média best-effort : la policy Storage est limitée au
      // propriétaire du dossier, on n'échoue donc pas la suppression du post.
      final paths = [
        _storagePathFromUrl(post.mediaUrl),
        _storagePathFromUrl(post.mediaThumbnailUrl),
      ].whereType<String>().toList();
      if (paths.isNotEmpty) {
        try {
          await client.storage.from(_bucket).remove(paths);
        } catch (e) {
          debugPrint('Aule: feed media remove failed ($e)');
        }
      }

      _posts.removeWhere((p) => p.id == post.id);
      _errorMessage = null;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Aule: feed delete failed ($e)');
      _errorMessage = 'Échec de la suppression';
      notifyListeners();
      return false;
    }
  }

  /// Réinitialise l'état (déconnexion).
  void clear() {
    _posts = [];
    _loaded = false;
    _errorMessage = null;
    notifyListeners();
  }

  Future<String> _uploadImage(
    SupabaseClient client,
    String userId,
    XFile file,
  ) async {
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) throw StateError('Fichier vide');

    final ext = _imageExtension(file);
    final contentType = _imageContentType(ext);
    final path = '$userId/${_uuid.v4()}.$ext';

    await client.storage
        .from(_bucket)
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: contentType, upsert: false),
        );

    return _publicUrl(client, path);
  }

  Future<_VideoUpload> _uploadVideo(
    SupabaseClient client,
    String userId,
    XFile file,
  ) async {
    final id = _uuid.v4();

    // Les vidéos brutes des téléphones récents (4K) dépassent vite le quota
    // du bucket : on compresse toujours avant l'envoi (repli sur le fichier
    // d'origine si la compression échoue).
    var uploadFile = File(file.path);
    var ext = _videoExtension(file);
    File? compressedFile;
    try {
      final info = await VideoCompress.compressVideo(
        file.path,
        quality: VideoQuality.MediumQuality,
        deleteOrigin: false,
        includeAudio: true,
      );
      if (info?.path != null) {
        compressedFile = File(info!.path!);
        uploadFile = compressedFile;
        ext = 'mp4';
      }
    } catch (e) {
      debugPrint('Aule: feed video compression failed ($e)');
    }

    if (await uploadFile.length() > _maxVideoUploadBytes) {
      await _cleanupCompressed(compressedFile);
      throw FeedVideoTooLargeException();
    }

    final videoPath = '$userId/$id.$ext';
    try {
      await client.storage
          .from(_bucket)
          .upload(
            videoPath,
            uploadFile,
            fileOptions: FileOptions(
              contentType: _videoContentType(ext),
              upsert: false,
            ),
          );
    } finally {
      await _cleanupCompressed(compressedFile);
    }
    final videoUrl = _publicUrl(client, videoPath);

    String? thumbnailUrl;
    try {
      final thumbBytes = await VideoThumbnail.thumbnailData(
        video: file.path,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 800,
        quality: 70,
      );
      if (thumbBytes != null && thumbBytes.isNotEmpty) {
        final thumbPath = '$userId/$id.jpg';
        await client.storage
            .from(_bucket)
            .uploadBinary(
              thumbPath,
              thumbBytes,
              fileOptions: const FileOptions(
                contentType: 'image/jpeg',
                upsert: false,
              ),
            );
        thumbnailUrl = _publicUrl(client, thumbPath);
      }
    } catch (e) {
      debugPrint('Aule: feed video thumbnail failed ($e)');
    }

    return _VideoUpload(videoUrl: videoUrl, thumbnailUrl: thumbnailUrl);
  }

  Future<void> _cleanupCompressed(File? file) async {
    if (file == null) return;
    try {
      if (await file.exists()) await file.delete();
    } catch (e) {
      debugPrint('Aule: feed video compressed cleanup failed ($e)');
    }
  }

  String _publicUrl(SupabaseClient client, String path) {
    final base = client.storage.from(_bucket).getPublicUrl(path);
    return '$base?v=${DateTime.now().millisecondsSinceEpoch}';
  }

  String _imageExtension(XFile file) {
    final name = file.name.toLowerCase();
    if (name.endsWith('.png')) return 'png';
    if (name.endsWith('.webp')) return 'webp';
    return 'jpg';
  }

  String _imageContentType(String ext) {
    switch (ext) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      default:
        return 'image/jpeg';
    }
  }

  String _videoExtension(XFile file) {
    final name = file.name.toLowerCase();
    if (name.endsWith('.mov')) return 'mov';
    return 'mp4';
  }

  String _videoContentType(String ext) {
    return ext == 'mov' ? 'video/quicktime' : 'video/mp4';
  }

  /// Reconstitue le chemin Storage (`userId/fichier.ext`) depuis l'URL publique.
  String? _storagePathFromUrl(String? url) {
    if (url == null) return null;
    const marker = '/$_bucket/';
    final idx = url.indexOf(marker);
    if (idx < 0) return null;
    var path = url.substring(idx + marker.length);
    final q = path.indexOf('?');
    if (q >= 0) path = path.substring(0, q);
    return path.isEmpty ? null : path;
  }
}

class _VideoUpload {
  final String videoUrl;
  final String? thumbnailUrl;

  const _VideoUpload({required this.videoUrl, this.thumbnailUrl});
}
