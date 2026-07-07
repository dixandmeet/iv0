import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../services/auth_service.dart';
import '../../services/driver/driver_service.dart';

/// Écran affiché à un agent dont le matricule n'a pas été reconnu dans la liste
/// de référence : sa demande est en attente de vérification manuelle par
/// l'exploitation. Tant que la demande n'est pas validée, l'app reste bloquée.
class DriverPendingScreen extends StatelessWidget {
  const DriverPendingScreen({super.key});

  static const _sage = Color(0xFF9FC8A9);
  static const _forest = Color(0xFF5E8B7E);
  static const _forestDeep = Color(0xFF3F6457);
  static const _bg = Color(0xFFEAF2EC);
  static const _ink = Color(0xFF14241C);

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthService>();
    final driver = context.read<DriverService>();
    final email = auth.email;

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 78,
                      height: 78,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [_sage, _forest],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: [
                          BoxShadow(
                            color: _forest.withValues(alpha: 0.35),
                            blurRadius: 22,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: const Icon(LucideIcons.clock,
                          color: Colors.white, size: 38),
                    ),
                  ),
                  const SizedBox(height: 22),
                  const Text(
                    'Demande en cours de vérification',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                      color: _ink,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Votre matricule n\'a pas été reconnu automatiquement. '
                    'Votre demande d\'accès a été transmise à l\'exploitation '
                    'pour vérification.\n\nVous pourrez accéder à l\'application '
                    'dès qu\'un responsable aura validé votre compte.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.45,
                      color: _forestDeep.withValues(alpha: 0.9),
                    ),
                  ),
                  if (email != null) ...[
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: _sage.withValues(alpha: 0.5)),
                      ),
                      child: Row(
                        children: [
                          const Icon(LucideIcons.mail,
                              size: 17, color: _forest),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              email,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: _ink,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 26),
                  OutlinedButton.icon(
                    onPressed: () => driver.refresh(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _forestDeep,
                      side: BorderSide(color: _forest.withValues(alpha: 0.6)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: const Icon(LucideIcons.refreshCw, size: 18),
                    label: const Text(
                      'Vérifier mon statut',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextButton.icon(
                    onPressed: () => auth.signOut(),
                    style: TextButton.styleFrom(foregroundColor: _forest),
                    icon: const Icon(LucideIcons.logOut, size: 17),
                    label: const Text('Se déconnecter'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
