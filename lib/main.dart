import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart'
    show FlutterQuillLocalizations;

import 'firebase_options.dart';
import 'auth/login_page.dart';
import 'auth/register_page.dart';
import 'auth/forgot_password_page.dart';
import 'home_page.dart';
import 'notes/tasks_page.dart';
import 'notes/export_page.dart';
import 'notes/note_editor_page.dart';
import 'notes/interactive_graph_page.dart';
import 'notes/advanced_search_page.dart';
import 'pages/shared_notes_page.dart';
import 'pages/toast_demo_page.dart';
import 'services/preferences_service.dart';
import 'services/app_service.dart';
import 'services/toast_service.dart';
import 'services/presence_service.dart';
import 'public_note_page.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Object? initError;
  try {
    final isMobileOrWeb =
        kIsWeb ||
        defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.windows;
    if (isMobileOrWeb) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  } catch (e) {
    initError = e;
  }

  runApp(MyApp(initError: initError));
}

class MyApp extends StatefulWidget {
  const MyApp({super.key, this.initError});

  final Object? initError;

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  Locale _locale = const Locale('es', '');
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    _loadPreferences();

    // Inicializar AppService con las funciones de cambio
    AppService.initialize(
      onChangeTheme: (mode) {},
      onChangeLocale: changeLocale,
    );

    // Register ToastService context after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = _navigatorKey.currentContext;
      if (context != null) {
        ToastService.registerContext(context);
      }
      ToastService.registerNavigatorKey(_navigatorKey);
    });
  }

  Future<void> _loadPreferences() async {
    final locale = await PreferencesService.getLocale();

    if (mounted) {
      setState(() {
        _locale = locale;
      });
    }
  }

  /// Método para cambiar el idioma desde otras pantallas
  void changeLocale(Locale locale) {
    setState(() {
      _locale = locale;
    });
    PreferencesService.setLocale(locale);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: 'Nootes',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.light,
      locale: _locale,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        FlutterQuillLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en', ''), // Inglés
        Locale('es', ''), // Español
      ],
      routes: {
        '/login': (_) => const LoginPage(),
        '/register': (_) => const RegisterPage(),
        '/forgot': (_) => const ForgotPasswordPage(),
        '/forgot-password': (_) => const ForgotPasswordPage(),
        '/home': (_) => const HomePage(),
        '/tasks': (_) => const TasksPage(),
        '/export': (_) => const ExportPage(),
        '/graph': (_) => const InteractiveGraphPage(),
        '/advanced-search': (_) => const AdvancedSearchPage(),
        '/shared-notes': (_) => const SharedNotesPage(),
        '/toast-demo': (_) => const ToastDemoPage(),
      },
      onGenerateRoute: (settings) {
        final name = settings.name ?? '';
        if (name.startsWith('/p/')) {
          final token = name.substring(3);
          if (token.isNotEmpty) {
            return MaterialPageRoute(
              builder: (_) => PublicNotePage(token: token),
            );
          }
        }
        if (name == '/note') {
          final arguments = settings.arguments as Map<String, dynamic>?;
          if (arguments != null && arguments['noteId'] != null) {
            return MaterialPageRoute(
              builder: (_) =>
                  NoteEditorPage(noteId: arguments['noteId'] as String),
            );
          }
        }
        return null;
      },
      home: widget.initError == null
          ? const AuthGate()
          : SetupHelpPage(error: widget.initError!),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    if (defaultTargetPlatform == TargetPlatform.linux && !kIsWeb) {
      return const UnsupportedAuthPage();
    }

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasData) {
          // Inicializar PresenceService cuando el usuario está autenticado
          _initializePresenceService();
          return const HomePage();
        } else {
          // Limpiar PresenceService cuando el usuario sale
          _cleanupPresenceService();
        }
        return const LoginPage();
      },
    );
  }

  void _initializePresenceService() async {
    try {
      await PresenceService().initialize();
    } catch (e) {
      debugPrint('❌ Error inicializando PresenceService: $e');
    }
  }

  void _cleanupPresenceService() async {
    try {
      await PresenceService().goOffline();
    } catch (e) {
      debugPrint('❌ Error limpiando PresenceService: $e');
    }
  }
}

class UnsupportedAuthPage extends StatelessWidget {
  const UnsupportedAuthPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Authentication Not Supported')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.orange),
            const SizedBox(height: 16),
            const Text(
              'Authentication Not Supported on Linux',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            const Text(
              'Firebase Authentication is not available on Linux desktop applications. '
              'Please use the web version or mobile app.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () async {
                const url =
                    'https://nootes-app.web.app'; // Replace with your web app URL
                if (await canLaunchUrl(Uri.parse(url))) {
                  await launchUrl(Uri.parse(url));
                }
              },
              child: const Text('Open Web Version'),
            ),
          ],
        ),
      ),
    );
  }
}

class SetupHelpPage extends StatelessWidget {
  const SetupHelpPage({super.key, required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Setup Error')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            const Text(
              'Firebase Setup Error',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text('Error: $error', textAlign: TextAlign.center),
            const SizedBox(height: 24),
            const Text(
              'Please check your Firebase configuration and try again.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
