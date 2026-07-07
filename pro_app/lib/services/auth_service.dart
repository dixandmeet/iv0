import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared/shared.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  bool get isAuthenticatedStaff =>
      _profile != null && _profile!.role.isMobileStaff;
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

  /// Domaine professionnel imposé pour les comptes conducteur / MSR.
  static const String proEmailDomain = 'semitan.fr';

  /// Dérive l'adresse e-mail professionnelle à partir de l'identité :
  /// première lettre du prénom + nom complet, normalisés (sans accents,
  /// minuscules, sans espaces ni ponctuation). Ex. « Marc Dupond » →
  /// `mdupond@semitan.fr`. Renvoie `null` si l'identité est incomplète.
  static String? deriveProEmail(String? firstName, String? lastName) {
    final first = _normalizeForEmail(firstName);
    final last = _normalizeForEmail(lastName);
    if (first.isEmpty || last.isEmpty) return null;
    return '${first[0]}$last@$proEmailDomain';
  }

  /// Minuscule + suppression des accents et de tout ce qui n'est pas a–z.
  static String _normalizeForEmail(String? value) {
    final lower = (value ?? '').trim().toLowerCase();
    final buffer = StringBuffer();
    for (final ch in lower.split('')) {
      buffer.write(_diacritics[ch] ?? ch);
    }
    return buffer.toString().replaceAll(RegExp(r'[^a-z]'), '');
  }

  static const Map<String, String> _diacritics = {
    'à': 'a', 'á': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a', 'å': 'a',
    'ç': 'c',
    'è': 'e', 'é': 'e', 'ê': 'e', 'ë': 'e',
    'ì': 'i', 'í': 'i', 'î': 'i', 'ï': 'i',
    'ñ': 'n',
    'ò': 'o', 'ó': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o',
    'ù': 'u', 'ú': 'u', 'û': 'u', 'ü': 'u',
    'ý': 'y', 'ÿ': 'y',
    'œ': 'oe', 'æ': 'ae',
  };

  Future<String?> signIn(String email, String password) async {
    final client = _supabaseService.client;
    if (client == null || _supabaseService.isOfflineMode) {
      return 'Connexion indisponible hors ligne';
    }

    try {
      await client.auth.signInWithPassword(email: email, password: password);
      return ensureMobileStaffAccess();
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      return 'Erreur de connexion ($e)';
    }
  }

  /// Envoie un code à usage unique (OTP) par e-mail. [createUser] = `true`
  /// pour l'inscription (crée le compte si besoin), [data] porte les
  /// métadonnées de compte (inscription conducteur). Renvoie `null` en cas de
  /// succès, sinon un message d'erreur.
  Future<String?> sendEmailOtp(
    String email, {
    bool createUser = false,
    Map<String, dynamic>? data,
  }) async {
    final client = _supabaseService.client;
    if (client == null || _supabaseService.isOfflineMode) {
      return 'Envoi du code indisponible hors ligne';
    }
    try {
      await client.auth.signInWithOtp(
        email: email.trim().toLowerCase(),
        shouldCreateUser: createUser,
        data: data,
      );
      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      return 'Erreur d\'envoi du code ($e)';
    }
  }

  /// Vérifie le code OTP saisi : établit la session si correct. Renvoie `null`
  /// en cas de succès, sinon un message d'erreur.
  Future<String?> verifyEmailOtp(String email, String token) async {
    final client = _supabaseService.client;
    if (client == null || _supabaseService.isOfflineMode) {
      return 'Vérification indisponible hors ligne';
    }
    try {
      await client.auth.verifyOTP(
        type: OtpType.email,
        email: email.trim().toLowerCase(),
        token: token.trim(),
      );
      await _loadProfile();
      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      return 'Code invalide ($e)';
    }
  }

  /// Message de refus d'accès terrain à réafficher après une déconnexion.
  ///
  /// Quand [ensureMobileStaffAccess] déconnecte un compte non autorisé, l'écran
  /// de connexion est reconstruit par le routeur (son état local est perdu) :
  /// on porte donc la raison du refus ici pour qu'elle reste visible.
  String? _accessDenialMessage;
  String? get accessDenialMessage => _accessDenialMessage;

  void clearAccessDenial() {
    if (_accessDenialMessage == null) return;
    _accessDenialMessage = null;
    notifyListeners();
  }

  /// Contrôle d'accès post-connexion : seul un conducteur validé, un agent MSR
  /// ou une demande d'accès en attente est autorisé sur l'app terrain. Tout
  /// autre compte est déconnecté. Renvoie `null` si l'accès est accordé.
  Future<String?> ensureMobileStaffAccess() async {
    _accessDenialMessage = null;
    await _loadProfile();

    // Conducteur validé ou agent MSR (via le profil) : accès direct.
    if (_profile?.role.isMobileStaff ?? false) return null;

    // Repli robuste sur l'état d'accès conducteur (RPC sur la table `drivers`
    // et les demandes) : couvre les comptes conducteur dont le profil n'est pas
    // encore renseigné, et laisse entrer une demande en attente pour qu'elle
    // voie l'écran « en attente de vérification ». Tout autre compte est refusé.
    final status = await driverAccessStatus();
    if (status == DriverAccessStatus.driver ||
        status == DriverAccessStatus.pending) {
      return null;
    }

    final msg = status == DriverAccessStatus.rejected
        ? 'Votre demande d\'accès conducteur a été refusée. '
            'Contactez votre exploitation.'
        : 'Ce compte n\'est pas autorisé sur l\'app mobile terrain';
    // Mémorisé AVANT la déconnexion : le notifyListeners de signOut propage le
    // message au nouvel écran de connexion reconstruit par le routeur.
    _accessDenialMessage = msg;
    await signOut();
    return msg;
  }

  /// État d'accès conducteur de l'utilisateur courant (routage / connexion).
  Future<DriverAccessStatus> driverAccessStatus() async {
    final client = _supabaseService.client;
    if (client == null || _supabaseService.isOfflineMode) {
      return DriverAccessStatus.none;
    }
    try {
      final res = await client.rpc('my_driver_access_status');
      return DriverAccessStatusX.fromDb(res as String?);
    } catch (e) {
      debugPrint('Aule: driverAccessStatus error ($e)');
      return DriverAccessStatus.none;
    }
  }

  /// Pré-vérifie un matricule avant la création de compte (statut + nom du
  /// titulaire si reconnu). Appelable hors authentification.
  Future<MatriculeCheck> checkMatricule(String employeeId) async {
    final client = _supabaseService.client;
    if (client == null || _supabaseService.isOfflineMode) {
      return const MatriculeCheck(MatriculeStatus.error);
    }
    try {
      final res = await client
          .rpc('check_driver_matricule', params: {'p_employee_id': employeeId});
      final row = (res is List && res.isNotEmpty)
          ? res.first as Map<String, dynamic>
          : (res as Map<String, dynamic>?);
      if (row == null) return const MatriculeCheck(MatriculeStatus.error);
      return MatriculeCheck(
        MatriculeStatusX.fromDb(row['status'] as String?),
        firstName: row['first_name'] as String?,
        lastName: row['last_name'] as String?,
      );
    } catch (e) {
      debugPrint('Aule: checkMatricule error ($e)');
      return const MatriculeCheck(MatriculeStatus.error);
    }
  }

  /// Inscription conducteur (e-mail + mot de passe + matricule). Crée le compte
  /// puis revendique le matricule. Le matricule décide de l'issue : reconnu →
  /// accès validé ; déjà utilisé → refus ; inconnu → mise en attente. Si la
  /// confirmation e-mail est requise, la revendication se fera à la première
  /// connexion.
  Future<DriverSignUpResult> signUpDriver({
    required String email,
    required String password,
    required String employeeId,
    String? firstName,
    String? lastName,
    String? phone,
  }) async {
    final client = _supabaseService.client;
    if (client == null || _supabaseService.isOfflineMode) {
      return DriverSignUpResult.error('Inscription indisponible hors ligne');
    }

    final matricule = employeeId.trim();
    final normalizedEmail = email.trim().toLowerCase();

    // Pour l'instant, seules les adresses internes du réseau sont acceptées.
    if (!normalizedEmail.endsWith('@$proEmailDomain')) {
      return DriverSignUpResult.error(
          'Seules les adresses e-mail @$proEmailDomain sont autorisées.');
    }

    // Refus immédiat si le matricule est déjà revendiqué (pas de compte créé).
    final pre = await checkMatricule(matricule);
    if (pre.status == MatriculeStatus.alreadyUsed) {
      return DriverSignUpResult.alreadyUsed();
    }

    final displayName = [firstName, lastName]
        .where((p) => (p ?? '').trim().isNotEmpty)
        .join(' ');

    try {
      final res = await client.auth.signUp(
        email: normalizedEmail,
        password: password,
        data: {
          'signup_type': 'driver',
          'employee_id': matricule,
          if (firstName != null && firstName.trim().isNotEmpty)
            'first_name': firstName.trim(),
          if (lastName != null && lastName.trim().isNotEmpty)
            'last_name': lastName.trim(),
          if (displayName.trim().isNotEmpty) 'display_name': displayName.trim(),
        },
      );

      // Confirmation e-mail requise : pas de session, la revendication se fera
      // à la première connexion.
      if (res.session == null) {
        return DriverSignUpResult.emailConfirmationRequired();
      }

      return claimDriverAccess(employeeId: matricule, phone: phone);
    } on AuthException catch (e) {
      return DriverSignUpResult.error(e.message);
    } catch (e) {
      return DriverSignUpResult.error('Erreur d\'inscription ($e)');
    }
  }

  /// Revendique le matricule pour l'utilisateur **déjà connecté** (après
  /// vérification de l'OTP d'inscription). Le matricule décide de l'issue :
  /// reconnu → accès validé ; déjà utilisé → refus (déconnexion) ; inconnu →
  /// mise en attente de vérification (la fiche n'est pas créée tant que le
  /// staff n'a pas validé). Idempotente côté RPC.
  Future<DriverSignUpResult> claimDriverAccess({
    required String employeeId,
    String? phone,
  }) async {
    final client = _supabaseService.client;
    if (client == null || _supabaseService.isOfflineMode) {
      return DriverSignUpResult.error('Revendication indisponible hors ligne');
    }

    final matricule = employeeId.trim();
    if (matricule.isEmpty) return DriverSignUpResult.error('Matricule requis');

    try {
      final outcome = await client.rpc('claim_driver_access', params: {
        'p_employee_id': matricule,
        if (phone != null && phone.trim().isNotEmpty) 'p_phone': phone.trim(),
      });
      await _loadProfile();

      switch (outcome as String?) {
        case 'validated':
          return DriverSignUpResult.validated();
        case 'pending':
          return DriverSignUpResult.pending();
        case 'already_used':
          // Course rare : matricule pris entre la pré-vérif et la revendication.
          await signOut();
          return DriverSignUpResult.alreadyUsed();
        default:
          return DriverSignUpResult.error('Matricule invalide');
      }
    } catch (e) {
      return DriverSignUpResult.error('Erreur de revendication ($e)');
    }
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

  /// Déconnexion pro : pas de reprise de session anonyme — l'app Pro exige
  /// un compte professionnel, l'utilisateur retombe sur l'écran de connexion.
  Future<void> signOut() async {
    final client = _supabaseService.client;
    if (client == null) return;

    await client.auth.signOut();
    _profile = null;
    notifyListeners();
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

/// État d'accès conducteur d'un utilisateur (RPC `my_driver_access_status`).
enum DriverAccessStatus { driver, pending, rejected, none }

extension DriverAccessStatusX on DriverAccessStatus {
  static DriverAccessStatus fromDb(String? value) {
    switch (value) {
      case 'driver':
        return DriverAccessStatus.driver;
      case 'pending':
        return DriverAccessStatus.pending;
      case 'rejected':
        return DriverAccessStatus.rejected;
      default:
        return DriverAccessStatus.none;
    }
  }
}

/// Statut d'un matricule lors de la pré-vérification d'inscription.
enum MatriculeStatus { available, alreadyUsed, unknown, error }

extension MatriculeStatusX on MatriculeStatus {
  static MatriculeStatus fromDb(String? value) {
    switch (value) {
      case 'available':
        return MatriculeStatus.available;
      case 'already_used':
        return MatriculeStatus.alreadyUsed;
      case 'unknown':
        return MatriculeStatus.unknown;
      default:
        return MatriculeStatus.error;
    }
  }
}

class MatriculeCheck {
  final MatriculeStatus status;
  final String? firstName;
  final String? lastName;

  const MatriculeCheck(this.status, {this.firstName, this.lastName});

  String? get fullName {
    final n = [firstName, lastName]
        .where((p) => (p ?? '').trim().isNotEmpty)
        .map((p) => p!.trim())
        .join(' ');
    return n.isEmpty ? null : n;
  }
}

/// Issue d'une inscription conducteur.
enum DriverSignUpStatus {
  validated, // matricule reconnu → accès immédiat
  pending, // matricule inconnu → en attente de vérification
  alreadyUsed, // matricule déjà revendiqué → refus
  emailConfirmationRequired,
  error,
}

class DriverSignUpResult {
  final DriverSignUpStatus status;
  final String? message;

  const DriverSignUpResult._(this.status, [this.message]);

  factory DriverSignUpResult.validated() =>
      const DriverSignUpResult._(DriverSignUpStatus.validated);
  factory DriverSignUpResult.pending() =>
      const DriverSignUpResult._(DriverSignUpStatus.pending);
  factory DriverSignUpResult.alreadyUsed() =>
      const DriverSignUpResult._(DriverSignUpStatus.alreadyUsed);
  factory DriverSignUpResult.emailConfirmationRequired() =>
      const DriverSignUpResult._(DriverSignUpStatus.emailConfirmationRequired);
  factory DriverSignUpResult.error(String message) =>
      DriverSignUpResult._(DriverSignUpStatus.error, message);
}
