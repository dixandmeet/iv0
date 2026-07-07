/// Statistiques du jour de la bourse d'échanges (RPC `service_exchange_daily_stats`).
class ServiceExchangeStats {
  final int activeCount;
  final int agreedTodayCount;
  final int urgentCount;

  const ServiceExchangeStats({
    this.activeCount = 0,
    this.agreedTodayCount = 0,
    this.urgentCount = 0,
  });

  factory ServiceExchangeStats.fromJson(Map<String, dynamic> json) {
    return ServiceExchangeStats(
      activeCount: (json['active_count'] as num?)?.toInt() ?? 0,
      agreedTodayCount: (json['agreed_today_count'] as num?)?.toInt() ?? 0,
      urgentCount: (json['urgent_count'] as num?)?.toInt() ?? 0,
    );
  }
}
