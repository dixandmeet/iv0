/// Modèle de données de l'onboarding Aule Pro.
///
/// Conçu pour être évolutif : chaque profil professionnel ([ProProfile]) ouvre
/// un parcours conditionnel composé d'étapes indépendantes. Ajouter un profil,
/// un réseau ou une étape ne doit jamais casser les autres parcours.
library;

// ─────────────────────────────────────────────────────────────────────────────
// Profil professionnel (Écran 2 — détermine la suite du parcours)
// ─────────────────────────────────────────────────────────────────────────────

enum ProProfile {
  reseau,
  vtc,
  commercant;

  String get label => switch (this) {
        ProProfile.reseau => 'Agent du réseau',
        ProProfile.vtc => 'VTC / Taxi',
        ProProfile.commercant => 'Commerçant',
      };

  String get description => switch (this) {
        ProProfile.reseau =>
          "Personnel d'exploitation ou d'intervention d'un réseau de transport.",
        ProProfile.vtc => 'Professionnel du transport individuel de personnes.',
        ProProfile.commercant => 'Professionnel souhaitant apparaître sur Aule.',
      };

  String get emoji => switch (this) {
        ProProfile.reseau => '🚍',
        ProProfile.vtc => '🚖',
        ProProfile.commercant => '🏪',
      };
}

// ─────────────────────────────────────────────────────────────────────────────
// Réseau de transport (parcours « Agent du réseau »)
// ─────────────────────────────────────────────────────────────────────────────

/// Réseaux de transport disponibles.
///
/// ⚠️ Pensé pour accueillir plusieurs dizaines de réseaux (RATP, TCL, RTM,
/// STAR, CTS, Tisséo, TBM…). Pour la v1, seul [naolib] est actif.
enum TransportNetwork {
  naolib;

  String get label => switch (this) { TransportNetwork.naolib => 'Naolib' };

  String get description => switch (this) {
        TransportNetwork.naolib => 'Réseau de transport de Nantes Métropole.',
      };
}

// ─────────────────────────────────────────────────────────────────────────────
// Genre
// ─────────────────────────────────────────────────────────────────────────────

enum DriverGender {
  homme,
  femme,
  autre;

  String get label => switch (this) {
        DriverGender.homme => 'Homme',
        DriverGender.femme => 'Femme',
        DriverGender.autre => 'Autre',
      };

  String get emoji => switch (this) {
        DriverGender.homme => '👨',
        DriverGender.femme => '👩',
        DriverGender.autre => '👤',
      };
}

// ─────────────────────────────────────────────────────────────────────────────
// Habilitations (parcours « Agent du réseau »)
// ─────────────────────────────────────────────────────────────────────────────

enum DriverHabilitation {
  conduite,
  controle,
  intervention,
  umtc;

  String get label => switch (this) {
        DriverHabilitation.conduite => 'Conduite',
        DriverHabilitation.controle => 'Contrôle',
        DriverHabilitation.intervention => 'Intervention',
        DriverHabilitation.umtc => 'UMTC',
      };

  String get description => switch (this) {
        DriverHabilitation.conduite => 'Conduite de bus ou de tramway.',
        DriverHabilitation.controle => 'Contrôle des titres de transport.',
        DriverHabilitation.intervention => 'Intervention terrain.',
        DriverHabilitation.umtc =>
          'Unité Métropolitaine des Transports en Commun.',
      };

  String get emoji => switch (this) {
        DriverHabilitation.conduite => '🚍',
        DriverHabilitation.controle => '🎫',
        DriverHabilitation.intervention => '🦺',
        DriverHabilitation.umtc => '👮',
      };
}

// ─────────────────────────────────────────────────────────────────────────────
// Dépôt de rattachement (parcours « Agent du réseau »)
// ─────────────────────────────────────────────────────────────────────────────

/// Dépôts du réseau Naolib (Semitan).
///
/// Le [code] (BLX / TTX / SHX) est la clé de rapprochement partout ailleurs
/// dans l'app (roster, services, échange de services) : c'est lui qui est
/// persisté, pas le nom. ⚠️ Pensé pour accueillir d'autres dépôts.
enum DriverDepot {
  bele,
  trentemoult,
  semitan;

  /// Code métier utilisé pour le matching (colonne `default_depot` du roster,
  /// `depot_code` des services…).
  String get code => switch (this) {
        DriverDepot.bele => 'BLX',
        DriverDepot.trentemoult => 'TTX',
        DriverDepot.semitan => 'SHX',
      };

  String get label => switch (this) {
        DriverDepot.bele => 'Le Bêle',
        DriverDepot.trentemoult => 'Trentemoult',
        DriverDepot.semitan => 'Semitan',
      };

  String get description => switch (this) {
        DriverDepot.bele => 'Dépôt Le Bêle (BLX).',
        DriverDepot.trentemoult => 'Dépôt de Trentemoult (TTX).',
        DriverDepot.semitan => 'Dépôt Semitan (SHX).',
      };

  /// Retrouve un dépôt à partir de son code métier.
  static DriverDepot? fromCode(String? code) {
    if (code == null) return null;
    for (final d in DriverDepot.values) {
      if (d.code == code) return d;
    }
    return null;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Parcours « VTC / Taxi »
// ─────────────────────────────────────────────────────────────────────────────

enum VtcActivity {
  vtc,
  taxi;

  String get label => switch (this) {
        VtcActivity.vtc => 'VTC',
        VtcActivity.taxi => 'Taxi',
      };

  String get description => switch (this) {
        VtcActivity.vtc => 'Voiture de transport avec chauffeur.',
        VtcActivity.taxi => 'Taxi conventionné ou indépendant.',
      };

  String get emoji => switch (this) {
        VtcActivity.vtc => '🚖',
        VtcActivity.taxi => '🚕',
      };
}

/// Zone principale d'activité.
///
/// ⚠️ Pensé pour s'étendre à plusieurs villes / régions. Pour la v1, seule
/// [nantesMetropole] est active.
enum ActivityZone {
  nantesMetropole;

  String get label => switch (this) {
        ActivityZone.nantesMetropole => 'Nantes Métropole',
      };

  String get description => switch (this) {
        ActivityZone.nantesMetropole => 'Nantes et ses 24 communes.',
      };
}

// ─────────────────────────────────────────────────────────────────────────────
// Parcours « Commerçant »
// ─────────────────────────────────────────────────────────────────────────────

enum MerchantType {
  // Alimentation & restauration
  restaurant,
  boulangerie,
  patisserie,
  cafe,
  bar,
  boucherie,
  primeur,
  fromagerie,
  caviste,
  superette,
  tabacPresse,
  // Beauté & santé
  coiffeur,
  beaute,
  parfumerie,
  pharmacie,
  opticien,
  // Mode & culture
  pretAPorter,
  chaussures,
  bijouterie,
  fleuriste,
  librairie,
  // Services
  pressing,
  autre;

  String get label => switch (this) {
        MerchantType.restaurant => 'Restaurant',
        MerchantType.boulangerie => 'Boulangerie',
        MerchantType.patisserie => 'Pâtisserie',
        MerchantType.cafe => 'Café',
        MerchantType.bar => 'Bar',
        MerchantType.boucherie => 'Boucherie',
        MerchantType.primeur => 'Primeur',
        MerchantType.fromagerie => 'Fromagerie',
        MerchantType.caviste => 'Caviste',
        MerchantType.superette => 'Supérette',
        MerchantType.tabacPresse => 'Tabac-Presse',
        MerchantType.coiffeur => 'Coiffeur',
        MerchantType.beaute => 'Institut de beauté',
        MerchantType.parfumerie => 'Parfumerie',
        MerchantType.pharmacie => 'Pharmacie',
        MerchantType.opticien => 'Opticien',
        MerchantType.pretAPorter => 'Prêt-à-porter',
        MerchantType.chaussures => 'Chaussures',
        MerchantType.bijouterie => 'Bijouterie',
        MerchantType.fleuriste => 'Fleuriste',
        MerchantType.librairie => 'Librairie',
        MerchantType.pressing => 'Pressing',
        MerchantType.autre => 'Autre',
      };

  String get emoji => switch (this) {
        MerchantType.restaurant => '🍽️',
        MerchantType.boulangerie => '🥖',
        MerchantType.patisserie => '🧁',
        MerchantType.cafe => '☕',
        MerchantType.bar => '🍺',
        MerchantType.boucherie => '🥩',
        MerchantType.primeur => '🥬',
        MerchantType.fromagerie => '🧀',
        MerchantType.caviste => '🍷',
        MerchantType.superette => '🛒',
        MerchantType.tabacPresse => '🗞️',
        MerchantType.coiffeur => '💈',
        MerchantType.beaute => '💅',
        MerchantType.parfumerie => '🧴',
        MerchantType.pharmacie => '💊',
        MerchantType.opticien => '👓',
        MerchantType.pretAPorter => '👗',
        MerchantType.chaussures => '👟',
        MerchantType.bijouterie => '💍',
        MerchantType.fleuriste => '💐',
        MerchantType.librairie => '📚',
        MerchantType.pressing => '👔',
        MerchantType.autre => '🏬',
      };
}

// ─────────────────────────────────────────────────────────────────────────────
// État agrégé de l'onboarding
// ─────────────────────────────────────────────────────────────────────────────

class DriverOnboardingData {
  // Commun
  final ProProfile? profile;
  final DriverGender? gender;

  // Agent du réseau
  final TransportNetwork? network;
  final DriverDepot? depot;
  final Set<DriverHabilitation> habilitations;

  // VTC / Taxi
  final VtcActivity? vtcActivity;
  final ActivityZone? zone;

  // Commerçant
  final MerchantType? merchantType;
  final String merchantName;
  final String merchantAddress;
  final String merchantPhone;

  const DriverOnboardingData({
    this.profile,
    this.gender,
    this.network,
    this.depot,
    this.habilitations = const {},
    this.vtcActivity,
    this.zone,
    this.merchantType,
    this.merchantName = '',
    this.merchantAddress = '',
    this.merchantPhone = '',
  });

  DriverOnboardingData copyWith({
    ProProfile? profile,
    DriverGender? gender,
    TransportNetwork? network,
    DriverDepot? depot,
    Set<DriverHabilitation>? habilitations,
    VtcActivity? vtcActivity,
    ActivityZone? zone,
    MerchantType? merchantType,
    String? merchantName,
    String? merchantAddress,
    String? merchantPhone,
  }) =>
      DriverOnboardingData(
        profile: profile ?? this.profile,
        gender: gender ?? this.gender,
        network: network ?? this.network,
        depot: depot ?? this.depot,
        habilitations: habilitations ?? this.habilitations,
        vtcActivity: vtcActivity ?? this.vtcActivity,
        zone: zone ?? this.zone,
        merchantType: merchantType ?? this.merchantType,
        merchantName: merchantName ?? this.merchantName,
        merchantAddress: merchantAddress ?? this.merchantAddress,
        merchantPhone: merchantPhone ?? this.merchantPhone,
      );

  // ── Règles métier des habilitations ───────────────────────────────────────
  // Combinaisons autorisées : Conduite seul, Contrôle seul, Intervention seul,
  // UMTC seul, Conduite + Contrôle, Conduite + Intervention.
  // UMTC est toujours exclusive ; aucune combinaison de trois habilitations.
  static bool isHabilitationSetValid(Set<DriverHabilitation> h) {
    if (h.length <= 1) return true;
    if (h.contains(DriverHabilitation.umtc)) return false;
    if (h.length > 2) return false;
    final hasConduite = h.contains(DriverHabilitation.conduite);
    final hasControle = h.contains(DriverHabilitation.controle);
    final hasIntervention = h.contains(DriverHabilitation.intervention);
    return (hasConduite && hasControle) || (hasConduite && hasIntervention);
  }
}
