import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import '../../models/driver/service_exchange_author_profile.dart';
import '../../models/driver/service_exchange_filters.dart';
import '../../models/driver/service_exchange_post.dart';
import '../../models/driver/service_exchange_stats.dart';
import '../supabase_service.dart';

/// Résultat d'une action de contact : canal DM ouvert + titre de l'annonce.
class ServiceExchangeContactResult {
  final String channelId;
  final String title;
  const ServiceExchangeContactResult({
    required this.channelId,
    required this.title,
  });
}

/// Service de la bourse d'échanges de service.
class ServiceExchangeService with ChangeNotifier {
  ServiceExchangeService({required SupabaseService supabaseService})
      : _supabase = supabaseService;

  final SupabaseService _supabase;

  // Contexte viewer (alimenté depuis l'onboarding local).
  List<String> _habilitations = const ['conduite'];
  String _networkCode = 'naolib';

  List<ServiceExchangePost> _available = [];
  List<ServiceExchangePost> _mine = [];
  List<ServiceExchangePost> _receivedContacts = [];
  ServiceExchangeStats _stats = const ServiceExchangeStats();
  bool _loading = false;
  bool _saving = false;
  String? _error;

  List<ServiceExchangePost> get available => List.unmodifiable(_available);
  List<ServiceExchangePost> get mine => List.unmodifiable(_mine);
  List<ServiceExchangePost> get receivedContacts =>
      List.unmodifiable(_receivedContacts);
  ServiceExchangeStats get stats => _stats;
  bool get loading => _loading;
  bool get saving => _saving;
  String? get error => _error;

  /// Sections du feed « Disponibles ».
  List<ServiceExchangePost> get newPosts =>
      _available.where((p) => p.isNew).toList();
  List<ServiceExchangePost> get expiringPosts =>
      _available.where((p) => p.isExpiringSoon).toList();

  /// Alimente le contexte viewer (réseau + habilitations) depuis l'onboarding.
  void configure({List<String>? habilitations, String? networkCode}) {
    if (habilitations != null && habilitations.isNotEmpty) {
      _habilitations = habilitations;
    }
    if (networkCode != null && networkCode.isNotEmpty) {
      _networkCode = networkCode;
    }
  }

  // ── Lecture ────────────────────────────────────────────────────────────────

  Future<void> fetchStats() async {
    final client = _supabase.client;
    if (client == null) return;
    try {
      final raw = await client.rpc('service_exchange_daily_stats',
          params: {'p_network_code': _networkCode});
      if (raw is Map) {
        _stats = ServiceExchangeStats.fromJson(Map<String, dynamic>.from(raw));
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Aule: SE stats failed ($e)');
    }
  }

  Future<void> fetchAvailable({
    ServiceExchangeFilters filters = const ServiceExchangeFilters(),
    bool silent = false,
  }) async {
    final client = _supabase.client;
    if (client == null) return;
    if (!silent) {
      _loading = true;
      _error = null;
      notifyListeners();
    }
    try {
      final raw = await client.rpc('list_service_exchange_feed', params: {
        'p_view': 'available',
        'p_network_code': _networkCode,
        'p_habilitations': _habilitations,
        'p_service_type': filters.serviceType?.dbValue,
        'p_service_date': filters.serviceDate == null
            ? null
            : DateFormat('yyyy-MM-dd').format(filters.serviceDate!),
        'p_post_kind': filters.postKind?.dbValue,
        'p_search': filters.search,
      });
      _available = _parseList(raw);
      _error = null;
    } catch (e) {
      debugPrint('Aule: SE available failed ($e)');
      _error = 'Impossible de charger les annonces';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> fetchMine({
    ServiceExchangeMineFilter filter = ServiceExchangeMineFilter.active,
    bool silent = false,
  }) async {
    final client = _supabase.client;
    if (client == null) return;
    if (!silent) {
      _loading = true;
      notifyListeners();
    }
    try {
      final raw = await client.rpc('list_service_exchange_feed', params: {
        'p_view': 'mine',
        'p_network_code': _networkCode,
        'p_habilitations': _habilitations,
        'p_mine_filter': filter.dbValue,
      });
      _mine = _parseList(raw);
      _error = null;
    } catch (e) {
      debugPrint('Aule: SE mine failed ($e)');
      _error = 'Impossible de charger vos annonces';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> fetchReceivedContacts({bool silent = false}) async {
    final client = _supabase.client;
    if (client == null) return;
    if (!silent) {
      _loading = true;
      notifyListeners();
    }
    try {
      final raw = await client.rpc('list_service_exchange_feed', params: {
        'p_view': 'received_contacts',
        'p_network_code': _networkCode,
        'p_habilitations': _habilitations,
      });
      _receivedContacts = _parseList(raw);
      _error = null;
    } catch (e) {
      debugPrint('Aule: SE received failed ($e)');
      _error = 'Impossible de charger les réponses reçues';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<ServiceExchangePost?> fetchPostDetail(String postId) async {
    final client = _supabase.client;
    if (client == null) return null;
    try {
      final raw = await client.rpc('get_service_exchange_post', params: {
        'p_post_id': postId,
        'p_habilitations': _habilitations,
      });
      if (raw is Map) {
        return ServiceExchangePost.fromJson(Map<String, dynamic>.from(raw));
      }
    } catch (e) {
      debugPrint('Aule: SE detail failed ($e)');
    }
    return null;
  }

  Future<List<ServiceExchangePost>> fetchSimilar(String postId) async {
    final client = _supabase.client;
    if (client == null) return const [];
    try {
      final raw = await client.rpc('list_similar_service_exchange_posts',
          params: {
            'p_post_id': postId,
            'p_network_code': _networkCode,
            'p_habilitations': _habilitations,
          });
      return _parseList(raw);
    } catch (e) {
      debugPrint('Aule: SE similar failed ($e)');
      return const [];
    }
  }

  Future<ServiceExchangeAuthorProfile?> fetchAuthorProfile(
      String authorId) async {
    final client = _supabase.client;
    if (client == null) return null;
    try {
      final raw = await client.rpc('get_service_exchange_author_profile',
          params: {'p_author_id': authorId});
      if (raw is Map) {
        return ServiceExchangeAuthorProfile.fromJson(
            Map<String, dynamic>.from(raw));
      }
    } catch (e) {
      debugPrint('Aule: SE author profile failed ($e)');
    }
    return null;
  }

  // ── Interactions légères ─────────────────────────────────────────────────────

  Future<void> recordView(String postId) async {
    final client = _supabase.client;
    if (client == null) return;
    try {
      await client.rpc('record_service_exchange_view',
          params: {'p_post_id': postId});
    } catch (e) {
      debugPrint('Aule: SE record view failed ($e)');
    }
  }

  Future<ServiceExchangePost?> toggleReaction(
      String postId, ServiceExchangeReaction reaction) async {
    final client = _supabase.client;
    if (client == null) return null;
    try {
      final raw = await client.rpc('toggle_service_exchange_reaction', params: {
        'p_post_id': postId,
        'p_reaction': reaction.dbValue,
      });
      if (raw is Map) {
        final post =
            ServiceExchangePost.fromJson(Map<String, dynamic>.from(raw));
        _replaceInLists(post);
        notifyListeners();
        return post;
      }
    } catch (e) {
      debugPrint('Aule: SE toggle reaction failed ($e)');
    }
    return null;
  }

  Future<bool> toggleFavorite(String postId) async {
    final client = _supabase.client;
    if (client == null) return false;
    try {
      final raw = await client.rpc('toggle_service_exchange_favorite',
          params: {'p_post_id': postId});
      return raw == true;
    } catch (e) {
      debugPrint('Aule: SE toggle favorite failed ($e)');
      return false;
    }
  }

  // ── Écriture ─────────────────────────────────────────────────────────────────

  Future<ServiceExchangePost?> createPost({
    required ServiceExchangePostKind postKind,
    required ServiceExchangeServiceType serviceType,
    required DateTime serviceDate,
    required String startTime, // HH:mm
    required String endTime, // HH:mm
    String? serviceNumber,
    String? lineCode,
    String? vehicleCode,
    String? message,
    bool isUrgent = false,
    DateTime? expiresAt,
  }) async {
    final client = _supabase.client;
    if (client == null) return null;
    _saving = true;
    _error = null;
    notifyListeners();
    try {
      final raw = await client.rpc('create_service_exchange_post', params: {
        'p_post_kind': postKind.dbValue,
        'p_service_type': serviceType.dbValue,
        'p_service_date': DateFormat('yyyy-MM-dd').format(serviceDate),
        'p_start_time': startTime,
        'p_end_time': endTime,
        'p_service_number': serviceNumber,
        'p_line_code': lineCode,
        'p_vehicle_code': vehicleCode,
        'p_message': message,
        'p_is_urgent': isUrgent,
        'p_expires_at': expiresAt?.toUtc().toIso8601String(),
        'p_network_code': _networkCode,
      });
      if (raw is Map) {
        return ServiceExchangePost.fromJson(Map<String, dynamic>.from(raw));
      }
      return null;
    } catch (e) {
      debugPrint('Aule: SE create failed ($e)');
      _error = _mapError(e);
      return null;
    } finally {
      _saving = false;
      notifyListeners();
    }
  }

  Future<ServiceExchangePost?> updatePost({
    required String postId,
    DateTime? serviceDate,
    String? startTime,
    String? endTime,
    String? serviceNumber,
    String? lineCode,
    String? vehicleCode,
    String? message,
    bool? isUrgent,
    DateTime? expiresAt,
  }) async {
    final client = _supabase.client;
    if (client == null) return null;
    _saving = true;
    _error = null;
    notifyListeners();
    try {
      final raw = await client.rpc('update_service_exchange_post', params: {
        'p_post_id': postId,
        'p_service_date': serviceDate == null
            ? null
            : DateFormat('yyyy-MM-dd').format(serviceDate),
        'p_start_time': startTime,
        'p_end_time': endTime,
        'p_service_number': serviceNumber,
        'p_line_code': lineCode,
        'p_vehicle_code': vehicleCode,
        'p_message': message,
        'p_is_urgent': isUrgent,
        'p_expires_at': expiresAt?.toUtc().toIso8601String(),
      });
      if (raw is Map) {
        final post =
            ServiceExchangePost.fromJson(Map<String, dynamic>.from(raw));
        _replaceInLists(post);
        notifyListeners();
        return post;
      }
      return null;
    } catch (e) {
      debugPrint('Aule: SE update failed ($e)');
      _error = _mapError(e);
      return null;
    } finally {
      _saving = false;
      notifyListeners();
    }
  }

  Future<ServiceExchangePost?> relancePost(String postId) async {
    final client = _supabase.client;
    if (client == null) return null;
    try {
      final raw = await client.rpc('relance_service_exchange_post',
          params: {'p_post_id': postId});
      if (raw is Map) {
        final post =
            ServiceExchangePost.fromJson(Map<String, dynamic>.from(raw));
        _replaceInLists(post);
        notifyListeners();
        return post;
      }
    } catch (e) {
      debugPrint('Aule: SE relance failed ($e)');
      _error = _mapError(e);
      notifyListeners();
    }
    return null;
  }

  Future<ServiceExchangePost?> updateStatus(String postId, String status) async {
    final client = _supabase.client;
    if (client == null) return null;
    try {
      final raw = await client.rpc('update_service_exchange_post_status',
          params: {'p_post_id': postId, 'p_status': status});
      if (raw is Map) {
        final post =
            ServiceExchangePost.fromJson(Map<String, dynamic>.from(raw));
        _replaceInLists(post);
        notifyListeners();
        return post;
      }
    } catch (e) {
      debugPrint('Aule: SE update status failed ($e)');
    }
    return null;
  }

  Future<ServiceExchangePost?> markResolved(
    String postId, {
    bool notifyContacts = false,
  }) async {
    final post = await updateStatus(postId, 'agreed');
    if (post != null && notifyContacts) {
      await closeDiscussions(postId);
    }
    return post;
  }

  Future<void> closeDiscussions(String postId, {String? message}) async {
    final client = _supabase.client;
    if (client == null) return;
    try {
      await client.rpc('close_service_exchange_discussions', params: {
        'p_post_id': postId,
        if (message != null) 'p_message': message,
      });
    } catch (e) {
      debugPrint('Aule: SE close discussions failed ($e)');
    }
  }

  Future<bool> deletePost(String postId) async {
    final client = _supabase.client;
    if (client == null) return false;
    try {
      await client
          .rpc('delete_service_exchange_post', params: {'p_post_id': postId});
      _mine.removeWhere((p) => p.id == postId);
      _available.removeWhere((p) => p.id == postId);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Aule: SE delete failed ($e)');
      return false;
    }
  }

  /// Contacte l'auteur : crée/recycle un canal 1:1 lié à l'annonce.
  Future<ServiceExchangeContactResult?> contactAuthor(String postId) async {
    final client = _supabase.client;
    if (client == null) return null;
    try {
      final raw = await client.rpc('record_service_exchange_contact',
          params: {'p_post_id': postId});
      if (raw is Map) {
        final map = Map<String, dynamic>.from(raw);
        final channelId = map['channel_id'] as String?;
        if (channelId != null) {
          return ServiceExchangeContactResult(
            channelId: channelId,
            title: map['title'] as String? ?? 'Échange de service',
          );
        }
      }
    } catch (e) {
      debugPrint('Aule: SE contact failed ($e)');
      _error = _mapError(e);
      notifyListeners();
    }
    return null;
  }

  void clear() {
    _available = [];
    _mine = [];
    _receivedContacts = [];
    _stats = const ServiceExchangeStats();
    _error = null;
    notifyListeners();
  }

  // ── Helpers internes ─────────────────────────────────────────────────────────

  List<ServiceExchangePost> _parseList(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .map((e) =>
            ServiceExchangePost.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  void _replaceInLists(ServiceExchangePost post) {
    void replace(List<ServiceExchangePost> list) {
      final i = list.indexWhere((p) => p.id == post.id);
      if (i >= 0) list[i] = post;
    }

    replace(_available);
    replace(_mine);
    replace(_receivedContacts);
  }

  String _mapError(Object e) {
    final s = e.toString();
    if (s.contains('urgent_rate_limited')) {
      return 'Vous avez déjà publié une annonce urgente dans les dernières 24 h.';
    }
    if (s.contains('relance_rate_limited')) {
      return 'Vous pourrez relancer cette annonce après 24 h.';
    }
    if (s.contains('Fiche conducteur introuvable')) {
      return 'Profil conducteur introuvable.';
    }
    return 'Une erreur est survenue. Réessayez.';
  }
}
