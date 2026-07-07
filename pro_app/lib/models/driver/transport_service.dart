/// Un service de roulement importé des feuilles de route (table
/// `transport_services`). À la prise de service, le conducteur saisit sa ligne
/// et son n° de train (= [vehicleKey], ex. « 1-31 ») et choisit, parmi les
/// services qui démarrent sur ce véhicule, celui qui correspond à sa vacation.
class TransportService {
  final String serviceKey;
  final String? serviceNo; // ex. « 01TD-3 »
  final String? rltCode; // ex. « 01TD »
  final String? depotCode; // BLX / TTX / SHX
  final String? depotName;
  final String? edition; // période : VERT / BLEU / HIVER
  final String? firstVehicle; // « 1 - 31 »
  final String? vehicleKey; // « 1-31 »
  final String? startTime; // « 3:43 »
  final String? startPlace;
  final String? endTime; // « 11:37 »
  final String? endPlace;
  final String? amplitude;

  const TransportService({
    required this.serviceKey,
    this.serviceNo,
    this.rltCode,
    this.depotCode,
    this.depotName,
    this.edition,
    this.firstVehicle,
    this.vehicleKey,
    this.startTime,
    this.startPlace,
    this.endTime,
    this.endPlace,
    this.amplitude,
  });

  factory TransportService.fromJson(Map<String, dynamic> json) {
    return TransportService(
      serviceKey: json['service_key'] as String,
      serviceNo: json['service_no'] as String?,
      rltCode: json['rlt_code'] as String?,
      depotCode: json['depot_code'] as String?,
      depotName: json['depot_name'] as String?,
      edition: json['edition'] as String?,
      firstVehicle: json['first_vehicle'] as String?,
      vehicleKey: json['vehicle_key'] as String?,
      startTime: json['start_time'] as String?,
      startPlace: json['start_place'] as String?,
      endTime: json['end_time'] as String?,
      endPlace: json['end_place'] as String?,
      amplitude: json['amplitude'] as String?,
    );
  }

  /// Heure de début en minutes depuis minuit (pour le tri ; les horaires sont
  /// stockés en texte « H:MM »). Renvoie une grande valeur si non parsable.
  int get startMinutes => _toMinutes(startTime);

  static int _toMinutes(String? hm) {
    if (hm == null) return 1 << 30;
    final parts = hm.split(':');
    if (parts.length != 2) return 1 << 30;
    final h = int.tryParse(parts[0].trim());
    final m = int.tryParse(parts[1].trim());
    if (h == null || m == null) return 1 << 30;
    return h * 60 + m;
  }

  /// Libellé court de la période (pour un badge).
  String get periodLabel {
    switch (edition?.toUpperCase()) {
      case 'VERT':
        return 'Vert';
      case 'BLEU':
        return 'Bleu';
      case 'HIVER':
        return 'Hiver';
      default:
        return edition ?? '—';
    }
  }
}
