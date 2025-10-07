import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'widgets/glass.dart';
import 'services/auth_service.dart';
import 'services/firestore_service.dart';
import 'profile/profile_page.dart';
import 'profile/profiles_list_page.dart';
import 'profile/handles_list_page.dart';
import 'notes/workspace_page.dart';
import 'notes/note_editor_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const NotesWorkspacePage();
  }
}
