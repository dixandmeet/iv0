class NaolibFeedInfo {
  final DateTime validFrom;
  final DateTime validUntil;
  final Uri downloadUrl;
  final String filename;

  const NaolibFeedInfo({
    required this.validFrom,
    required this.validUntil,
    required this.downloadUrl,
    required this.filename,
  });

  bool get isCurrentlyValid {
    final today = DateTime.now();
    final date = DateTime(today.year, today.month, today.day);
    return !date.isBefore(validFrom) && !date.isAfter(validUntil);
  }
}
