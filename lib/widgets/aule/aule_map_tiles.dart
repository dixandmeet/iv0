import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';

import '../../theme/aule_theme.dart';

/// Tuiles CartoDB utilisées pour la cartographie Aule.
class AuleMapTiles {
  AuleMapTiles._();

  /// `{r}` est remplacé par `@2x` sur écrans haute densité (flutter_map 6).
  static String urlTemplate(AuleColors colors) {
    final style = colors.isDark ? 'dark_all' : 'light_all';
    return 'https://{s}.basemaps.cartocdn.com/$style/{z}/{x}/{y}{r}.png';
  }

  static const fallbackUrlTemplate =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  static const subdomains = ['a', 'b', 'c', 'd'];
  static const userAgent = 'com.aule.nantes';

  static TileLayer layer(BuildContext context, AuleColors colors) {
    return TileLayer(
      urlTemplate: urlTemplate(colors),
      fallbackUrl: fallbackUrlTemplate,
      subdomains: subdomains,
      userAgentPackageName: userAgent,
      retinaMode: RetinaMode.isHighDensity(context),
      maxNativeZoom: 20,
    );
  }
}
