import 'package:flutter/material.dart';

import '../theme/aule_theme.dart';

class AuleEtaFormat {
  final String text;
  final String num;
  final String unit;
  final bool urgent;

  const AuleEtaFormat({
    required this.text,
    required this.num,
    required this.unit,
    required this.urgent,
  });
}

/// Secondes restantes avant l'arrivée, à partir d'un timestamp absolu.
int auleEtaSeconds(DateTime arrivalAt, DateTime now) {
  return arrivalAt.difference(now).inSeconds.clamp(0, 99999);
}

AuleEtaFormat formatAuleEta(int etaSeconds) {
  if (etaSeconds <= 10) {
    return const AuleEtaFormat(
      text: 'À quai',
      num: 'À quai',
      unit: '',
      urgent: true,
    );
  }
  if (etaSeconds < 60) {
    return const AuleEtaFormat(
      text: '1 min',
      num: '1',
      unit: 'min',
      urgent: true,
    );
  }
  final m = (etaSeconds / 60).ceil();
  return AuleEtaFormat(
    text: '$m min',
    num: '$m',
    unit: 'min',
    urgent: etaSeconds < 150,
  );
}

Color etaColor(AuleColors c, bool urgent) => urgent ? c.ok : c.text;
