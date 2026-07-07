import 'package:flutter/material.dart';
import 'package:shared/shared.dart';

import '../../theme/driver_home_palette.dart';

class MapPanel extends StatelessWidget {
  final PlatformResource resource;

  const MapPanel({super.key, required this.resource});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.map_outlined, size: 48, color: DriverHomePalette.primary),
            const SizedBox(height: 12),
            Text(
              'Carte — ${resource.name}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            const Text(
              'Intégration cartographique terrain',
              style: TextStyle(color: DriverHomePalette.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
