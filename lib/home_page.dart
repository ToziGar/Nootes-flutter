import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'widgets/glass.dart';
import 'services/auth_service.dart';
import 'services/firestore_service.dart';
import 'profile/profile_page.dart';
import 'profile/profiles_list_page.dart';
import 'profile/handles_list_page.dart';
import 'notes/notes_page.dart';
import 'notes/note_editor_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final displayEmail = AuthService.instance.currentUser?.email ?? FirebaseAuth.instance.currentUser?.email;
    return Scaffold(
      body: GlassBackground(
        child: SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: SingleChildScrollView(
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
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        children: [
                          FilledButton.icon(
                            onPressed: () async {
                              final uid = AuthService.instance.currentUser?.uid ?? FirebaseAuth.instance.currentUser?.uid;
                              if (uid == null) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Inicia sesión para crear notas')));
                                }
                                return;
                              }
                              try {
                                final id = await FirestoreService.instance.createNote(uid: uid, data: {
                                  'title': '',
                                  'content': '',
                                  'tags': <String>[],
                                  'links': <String>[],
                                });
                                if (context.mounted) {
                                  await Navigator.of(context).push(
                                    MaterialPageRoute(builder: (_) => NoteEditorPage(noteId: id)),
                                  );
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se pudo crear la nota: $e')));
                                }
                              }
                            },
                            icon: const Icon(Icons.note_add_rounded),
                            label: const Text('Crear nota'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => const NotesPage()),
                              );
                            },
                            icon: const Icon(Icons.library_books_rounded),
                            label: const Text('Notas'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => const ProfilePage()),
                              );
                            },
                            icon: const Icon(Icons.person_outline_rounded),
                            label: const Text('Editar perfil'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => const ProfilesListPage()),
                              );
                            },
                            icon: const Icon(Icons.people_outline_rounded),
                            label: const Text('Perfiles'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => const HandlesListPage()),
                              );
                            },
                            icon: const Icon(Icons.alternate_email_rounded),
                            label: const Text('Handles'),
                          ),
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
      ),
    );
  }
}
