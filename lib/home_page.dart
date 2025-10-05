import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'widgets/glass.dart';
import 'services/auth_service.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final displayEmail = AuthService.instance.currentUser?.email ?? FirebaseAuth.instance.currentUser?.email;
    return Scaffold(
      body: GlassBackground(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: GlassCard(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Hola,', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.textMuted)),
                    const SizedBox(height: 4),
                    Text(displayEmail ?? 'Usuario', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    const Text('Estás dentro. Pronto verás tu espacio de notas avanzadas con grafo, esquemas y más.'),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        FilledButton.icon(
                          onPressed: () {},
                          icon: const Icon(Icons.note_add_rounded),
                          label: const Text('Crear nota'),
                        ),
                        const SizedBox(width: 12),
                        OutlinedButton.icon(
                          onPressed: () async {
                            await AuthService.instance.signOut();
                            if (context.mounted) {
                              Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
                            }
                          },
                          icon: const Icon(Icons.logout_rounded),
                          label: const Text('Cerrar sesión'),
                        ),
                      ],
                    )
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
