import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/app_user_role.dart';
import '../models/user_profile.dart';
import 'supabase_service.dart';

class AuthService with ChangeNotifier {
  final SupabaseService _supabaseService;

  UserProfile? _profile;
  bool _loading = true;

  UserProfile? get profile => _profile;
  bool get loading => _loading;
  bool get isAuthenticatedStaff =>
      _profile != null && _profile!.role.isMobileStaff;
  AppUserRole get role => _profile?.role ?? AppUserRole.passenger;

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
      debugPrint('Wazibus: profile load error ($e)');
      _profile = null;
    }

    _loading = false;
    notifyListeners();
  }

  Future<String?> signIn(String email, String password) async {
    final client = _supabaseService.client;
    if (client == null || _supabaseService.isOfflineMode) {
      return 'Connexion indisponible hors ligne';
    }

    try {
      await client.auth.signInWithPassword(email: email, password: password);
      await _loadProfile();
      if (_profile == null) return 'Profil utilisateur introuvable';
      if (!_profile!.role.isMobileStaff) {
        await signOut();
        return 'Ce compte n\'est pas autorisé sur l\'app mobile terrain';
      }
      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      return 'Erreur de connexion ($e)';
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
      debugPrint('Wazibus: anonymous re-auth failed ($e)');
    }
  }
}
