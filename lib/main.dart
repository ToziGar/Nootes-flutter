import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'firebase_options.dart';
import 'auth/login_page.dart';
import 'auth/register_page.dart';
import 'auth/forgot_password_page.dart';
import 'home_page.dart';
import 'theme/app_theme.dart';
import 'notes/tasks_page.dart';
import 'notes/export_page.dart';
import 'notes/interactive_graph_page.dart';
import 'notes/advanced_search_page.dart';
import 'pages/toast_demo_page.dart';
import 'pages/shared_notes_page.dart';
import 'services/preferences_service.dart';
import 'services/app_service.dart';
import 'services/toast_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Object? initError;
  try {
    final isMobileOrWeb = kIsWeb ||
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
  ThemeMode _themeMode = ThemeMode.system;
  Locale _locale = const Locale('es', '');

  @override
  void initState() {
    super.initState();
    _loadPreferences();
    
    // Inicializar AppService con las funciones de cambio
    AppService.initialize(
      onChangeTheme: changeTheme,
      onChangeLocale: changeLocale,
    );
  }

  Future<void> _loadPreferences() async {
    final themeMode = await PreferencesService.getThemeMode();
    final locale = await PreferencesService.getLocale();
    
    if (mounted) {
      setState(() {
        _themeMode = themeMode;
        _locale = locale;
      });
    }
  }

  /// Método para cambiar el tema desde otras pantallas
  void changeTheme(ThemeMode themeMode) {
    setState(() {
      _themeMode = themeMode;
    });
    PreferencesService.setThemeMode(themeMode);
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
    return ToastProvider(
      child: MaterialApp(
        title: 'Nootes',
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: _themeMode,
        locale: _locale,
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('en', ''), // Inglés
          Locale('es', ''), // Español
        ],
        routes: {
          '/login': (_) => const LoginPage(),
          '/register': (_) => const RegisterPage(),
          '/forgot': (_) => const ForgotPasswordPage(),
          // Alias para compatibilidad con navegaciones existentes
          '/forgot-password': (_) => const ForgotPasswordPage(),
          '/home': (_) => const HomePage(),
          '/tasks': (_) => const TasksPage(),
          '/export': (_) => const ExportPage(),
          '/graph': (_) => const InteractiveGraphPage(),
          '/advanced-search': (_) => const AdvancedSearchPage(),
          '/shared-notes': (_) => const SharedNotesPage(),
          '/toast-demo': (_) => const ToastDemoPage(),
        },
        home: widget.initError == null ? const AuthGate() : SetupHelpPage(error: widget.initError!),
      ),
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
          return const HomePage();
        }
        return const LoginPage();
      },
    );
  }
}

class UnsupportedAuthPage extends StatelessWidget {
  const UnsupportedAuthPage({super.key});

  @override
  Widget build(BuildContext context) {
    const webUrl = String.fromEnvironment('WEB_APP_URL');
    return Scaffold(
      appBar: AppBar(title: const Text('Abrir versión Web')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Esta app se ejecuta como Web en Windows y macOS.\n'
                'Abre el navegador para continuar.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              if (webUrl.isNotEmpty)
                FilledButton.icon(
                  onPressed: () async {
                    final uri = Uri.parse(webUrl);
                    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('No se pudo abrir el navegador.')),
                      );
                    }
                  },
                  icon: const Icon(Icons.open_in_browser),
                  label: const Text('Abrir en navegador'),
                )
              else
                const Text(
                  'Configura la URL de la app web con:\n'
                  'flutter run -d windows --dart-define=WEB_APP_URL=http://localhost:5000\n'
                  'o publica tu web y pasa su URL.',
                  textAlign: TextAlign.center,
                ),
            ],
          ),
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
    final message = error.toString();
    return Scaffold(
      appBar: AppBar(title: const Text('Configurar Firebase')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'No se pudo inicializar Firebase en esta plataforma.\n'
              'Sigue estos pasos para iOS/Android/macOS, o ejecuta en Web:',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            const Text('1) Instala la CLI: dart pub global activate flutterfire_cli'),
            const Text('2) Ejecuta: flutterfire configure (elige el proyecto smartnotes-d0bdd)'),
            const Text('3) Asegúrate de colocar google-services.json (Android) y GoogleService-Info.plist (iOS).'),
            const SizedBox(height: 12),
            Text('Detalle del error:\n$message'),
          ],
        ),
      ),
    );
  }
}

