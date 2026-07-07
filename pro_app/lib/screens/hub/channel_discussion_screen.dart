import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/driver_home_palette.dart';
import '../../widgets/resource_panels/discussion_panel.dart';

/// Écran de discussion autonome pour un canal sans ressource métier (DM, groupe).
class ChannelDiscussionScreen extends StatelessWidget {
  final String channelId;
  final String title;

  const ChannelDiscussionScreen({
    super.key,
    required this.channelId,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DriverHomePalette.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
        flexibleSpace: const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                DriverHomePalette.gradientStart,
                DriverHomePalette.gradientEnd,
              ],
            ),
          ),
        ),
      ),
      body: DiscussionPanel(
        resourceId: '',
        channelId: channelId,
      ),
    );
  }
}
