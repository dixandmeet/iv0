import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/app_user_role.dart';
import '../models/user_profile.dart';
import 'supabase_service.dart';

class AuthService with ChangeNotifier {
  /// Schéma de redirection OAuth (cf. Info.plist iOS / AndroidManifest).
  static const String _oauthRedirectUrl =
      'io.aule.app://login-callback/';

  final SupabaseService _supabaseService;

  UserProfile? _profile;
  bool _loading = true;

  UserProfile? get profile => _profile;
  bool get loading => _loading;
  AppUserRole get role => _profile?.role ?? AppUserRole.passenger;

  /// Utilisateur connecté avec un vrai compte (≠ session anonyme).
  bool get isSignedIn {
    final user = _supabaseService.client?.auth.currentUser;
    return user != null && !user.isAnonymous;
  }

  String? get email => _supabaseService.client?.auth.currentUser?.email;

  /// Nom à afficher : profil > métadonnée OAuth > partie locale de l'email.
  String? get displayName {
    if (_profile?.displayName != null && _profile!.displayName!.isNotEmpty) {
      return _profile!.displayName;
    }
    final user = _supabaseService.client?.auth.currentUser;
    final metaName = user?.userMetadata?['full_name'] ??
        user?.userMetadata?['name'] ??
        user?.userMetadata?['display_name'];
    if (metaName is String && metaName.isNotEmpty) return metaName;
    final mail = user?.email;
    if (mail != null && mail.contains('@')) return mail.split('@').first;
    return null;
  }

  AuthService({required SupabaseService supabaseService})
      : _supabaseService = supabaseService {
    _init();
  }

  Future<void> _init() async {
    if (_supabaseService.isOfflineMode || _supabaseService.client == null) {
      _loading = false;
      notifyListeners();
      return;
    }

    _supabaseService.client!.auth.onAuthStateChange.listen((event) async {
      await _loadProfile();
    });

    await _loadProfile();
  }

  Future<void> _loadProfile() async {
    final client = _supabaseService.client;
    if (client == null || _supabaseService.isOfflineMode) {
      _profile = null;
      _loading = false;
      notifyListeners();
      return;
    }

    final user = client.auth.currentUser;
    if (user == null || user.isAnonymous) {
      _profile = null;
      _loading = false;
      notifyListeners();
      return;
    }

    try {
      final row = await client
          .from('user_profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      _profile = row != null ? UserProfile.fromJson(row) : null;
    } catch (e) {
      debugPrint('Aule: profile load error ($e)');
      _profile = null;
    }

    _loading = false;
    notifyListeners();
  }

  /// Inscription passager (email + mot de passe). Retourne `null` en cas de
  /// succès avec session active, [PassengerAuthResult.emailConfirmationRequired]
  /// si l'email doit être confirmé, ou un message d'erreur.
  Future<PassengerAuthResult> signUpPassenger(
    String email,
    String password, {
    String? displayName,
  }) async {
    final client = _supabaseService.client;
    if (client == null || _supabaseService.isOfflineMode) {
      return PassengerAuthResult.error('Inscription indisponible hors ligne');
    }

    try {
      final res = await client.auth.signUp(
        email: email,
        password: password,
        data: {
          if (displayName != null && displayName.trim().isNotEmpty)
            'display_name': displayName.trim(),
        },
      );
      // Session immédiate (confirmation email désactivée) → connecté.
      if (res.session != null) {
        await _loadProfile();
        return PassengerAuthResult.success();
      }
      // Confirmation email requise : pas de session tant que non vérifié.
      return PassengerAuthResult.emailConfirmationRequired();
    } on AuthException catch (e) {
      return PassengerAuthResult.error(e.message);
    } catch (e) {
      return PassengerAuthResult.error('Erreur d\'inscription ($e)');
    }
  }

  /// Connexion passager (email + mot de passe), sans restriction de rôle.
  Future<String?> signInPassenger(String email, String password) async {
    final client = _supabaseService.client;
    if (client == null || _supabaseService.isOfflineMode) {
      return 'Connexion indisponible hors ligne';
    }

    try {
      await client.auth.signInWithPassword(email: email, password: password);
      await _loadProfile();
      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      return 'Erreur de connexion ($e)';
    }
  }

  Future<String?> signInWithGoogle() => _signInWithOAuth(OAuthProvider.google);
  Future<String?> signInWithApple() => _signInWithOAuth(OAuthProvider.apple);

  Future<String?> _signInWithOAuth(OAuthProvider provider) async {
    final client = _supabaseService.client;
    if (client == null || _supabaseService.isOfflineMode) {
      return 'Connexion indisponible hors ligne';
    }
    try {
      // Ouvre le navigateur ; le retour passe par le deep link et met à jour
      // la session via onAuthStateChange (qui rechargera le profil).
      await client.auth.signInWithOAuth(
        provider,
        redirectTo: _oauthRedirectUrl,
      );
      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      return 'Connexion ${provider.name} indisponible ($e)';
    }
  }

  Future<void> signOut() async {
    final client = _supabaseService.client;
    if (client == null) return;

    await client.auth.signOut();
    _profile = null;
    notifyListeners();

    // Reprend une session anonyme pour les fonctions passager
    try {
      await client.auth.signInAnonymously();
      await _supabaseService.updateBackgroundConsent(
        _supabaseService.consentBackground,
      );
    } catch (e) {
      debugPrint('Aule: anonymous re-auth failed ($e)');
    }
  }
}

/// Issue d'une inscription passager.
enum PassengerAuthStatus { success, emailConfirmationRequired, error }

class PassengerAuthResult {
  final PassengerAuthStatus status;
  final String? message;

  const PassengerAuthResult._(this.status, [this.message]);

  factory PassengerAuthResult.success() =>
      const PassengerAuthResult._(PassengerAuthStatus.success);
  factory PassengerAuthResult.emailConfirmationRequired() =>
      const PassengerAuthResult._(PassengerAuthStatus.emailConfirmationRequired);
  factory PassengerAuthResult.error(String message) =>
      PassengerAuthResult._(PassengerAuthStatus.error, message);

  bool get isSuccess => status == PassengerAuthStatus.success;
  bool get needsEmailConfirmation =>
      status == PassengerAuthStatus.emailConfirmationRequired;
  bool get isError => status == PassengerAuthStatus.error;
}
