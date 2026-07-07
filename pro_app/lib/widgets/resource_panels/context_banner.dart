import 'package:flutter/material.dart';
import 'package:shared/shared.dart';

import '../../theme/driver_home_palette.dart';

class ContextBanner extends StatelessWidget {
  final PlatformResource resource;
  final List<Map<String, dynamic>> graph;

  const ContextBanner({
    super.key,
    required this.resource,
    this.graph = const [],
  });

  @override
  Widget build(BuildContext context) {
    final refs = resource.contextRefs;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: DriverHomePalette.lightGreen,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: DriverHomePalette.softGreen),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            resource.name,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: DriverHomePalette.textDark,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${resource.type} · ${resource.status}',
            style: const TextStyle(
              color: DriverHomePalette.textSecondary,
              fontSize: 13,
            ),
          ),
          if (refs.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: refs
                  .map(
                    (r) => Chip(
                      label: Text('${r['resource']}: ${r['id']}'),
                      visualDensity: VisualDensity.compact,
                    ),
                  )
                  .toList(),
            ),
          ],
          if (graph.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              '${graph.length} relation(s) liée(s)',
              style: const TextStyle(fontSize: 12, color: DriverHomePalette.textSecondary),
            ),
          ],
        ],
      ),
    );
  }
}
