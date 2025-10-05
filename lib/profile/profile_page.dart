import 'package:flutter/material.dart';
import '../widgets/glass.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _formKey = GlobalKey<FormState>();
  bool _loading = true;
  bool _saving = false;

  final _fullName = TextEditingController();
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _organization = TextEditingController();
  final _role = TextEditingController();
  final _experience = TextEditingController();
  final _language = TextEditingController();
  final _preferredTheme = TextEditingController();
  bool _newsOptIn = false;

  Map<String, dynamic>? _profile;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _fullName.dispose();
    _username.dispose();
    _email.dispose();
    _organization.dispose();
    _role.dispose();
    _experience.dispose();
    _language.dispose();
    _preferredTheme.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final uid = AuthService.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final p = await FirestoreService.instance.getUserProfile(uid: uid);
      setState(() {
        _profile = p ?? {};
        _fullName.text = (_profile?['fullName'] ?? '').toString();
        _username.text = (_profile?['username'] ?? '').toString();
        _email.text = (_profile?['email'] ?? '').toString();
        _organization.text = (_profile?['organization'] ?? '').toString();
        _role.text = (_profile?['role'] ?? '').toString();
        _experience.text = (_profile?['experience'] ?? '').toString();
        _language.text = (_profile?['language'] ?? '').toString();
        _preferredTheme.text = (_profile?['preferredTheme'] ?? '').toString();
        _newsOptIn = (_profile?['newsOptIn'] ?? false) == true;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final uid = AuthService.instance.currentUser?.uid;
    if (uid == null) return;
    setState(() => _saving = true);
    try {
      await FirestoreService.instance.updateUserProfile(uid: uid, data: {
        'fullName': _fullName.text.trim(),
        'email': _email.text.trim(),
        'organization': _organization.text.trim(),
        'role': _role.text.trim(),
        'experience': _experience.text.trim(),
        'language': _language.text.trim(),
        'preferredTheme': _preferredTheme.text.trim(),
        'newsOptIn': _newsOptIn,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Perfil actualizado')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _changeHandle() async {
    final uid = AuthService.instance.currentUser?.uid;
    if (uid == null) return;
    final newUser = _username.text.trim().toLowerCase();
    if (!RegExp(r'^[a-z0-9._]{3,20}$').hasMatch(newUser)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Usuario inválido')));
      return;
    }
    setState(() => _saving = true);
    try {
      await FirestoreService.instance.changeHandle(uid: uid, newUsername: newUser);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Usuario actualizado')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Editar perfil')),
      body: GlassBackground(
        child: SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: GlassCard(
                  child: _loading
                      ? const SizedBox(height: 200, child: Center(child: CircularProgressIndicator()))
                      : Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text('Perfil', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _fullName,
                                decoration: const InputDecoration(labelText: 'Nombre completo', prefixIcon: Icon(Icons.person_outline_rounded)),
                                validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _email,
                                decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.mail_outline_rounded)),
                                validator: (v) => (v == null || v.trim().isEmpty || !v.contains('@')) ? 'Email inválido' : null,
                              ),
                              const SizedBox(height: 8),
                              LayoutBuilder(
                                builder: (context, constraints) {
                                  final isWide = constraints.maxWidth > 480;
                                  final field = TextFormField(
                                    controller: _username,
                                    decoration: const InputDecoration(
                                      labelText: 'Usuario (handle)',
                                      prefixIcon: Icon(Icons.alternate_email_rounded),
                                    ),
                                  );
                                  final button = FilledButton.icon(
                                    onPressed: _saving ? null : _changeHandle,
                                    icon: const Icon(Icons.check_rounded),
                                    label: const Text('Cambiar'),
                                  );
                                  if (isWide) {
                                    return Row(
                                      children: [
                                        Expanded(child: field),
                                        const SizedBox(width: 8),
                                        button,
                                      ],
                                    );
                                  }
                                  return Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      field,
                                      const SizedBox(height: 8),
                                      button,
                                    ],
                                  );
                                },
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _organization,
                                decoration: const InputDecoration(labelText: 'Organización', prefixIcon: Icon(Icons.business_outlined)),
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _role,
                                decoration: const InputDecoration(labelText: 'Rol', prefixIcon: Icon(Icons.badge_outlined)),
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _experience,
                                decoration: const InputDecoration(labelText: 'Experiencia', prefixIcon: Icon(Icons.timeline_outlined)),
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _language,
                                decoration: const InputDecoration(labelText: 'Idioma', prefixIcon: Icon(Icons.language_outlined)),
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _preferredTheme,
                                decoration: const InputDecoration(labelText: 'Tema preferido', prefixIcon: Icon(Icons.dark_mode_outlined)),
                              ),
                              const SizedBox(height: 8),
                              SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                title: const Text('Recibir noticias y actualizaciones'),
                                value: _newsOptIn,
                                onChanged: (v) => setState(() => _newsOptIn = v),
                              ),
                              const SizedBox(height: 12),
                              Align(
                                alignment: Alignment.centerRight,
                                child: FilledButton.icon(
                                  onPressed: _saving ? null : _save,
                                  icon: _saving
                                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                                      : const Icon(Icons.save_rounded),
                                  label: const Text('Guardar cambios'),
                                ),
                              ),
                            ],
                          ),
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
