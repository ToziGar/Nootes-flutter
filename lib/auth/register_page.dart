import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/glass.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();

  final _fullNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _orgController = TextEditingController();
  final _interestController = TextEditingController();

  bool _loading = false;
  bool _obscure = true;
  bool _obscureConfirm = true;
  bool _acceptTerms = false;
  bool _optInNews = false;

  String _language = 'es';
  String _role = 'Estudiante';
  String _experience = 'Intermedio';
  String _preferredTheme = 'oscuro';

  final List<String> _interests = [];

  @override
  void dispose() {
    _fullNameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    _orgController.dispose();
    _interestController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_acceptTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debes aceptar los Términos y la Privacidad')),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      final username = _usernameController.text.trim().toLowerCase();
      if (!RegExp(r'^[a-z0-9._]{3,20}$').hasMatch(username)) {
        throw Exception('Usuario inválido');
      }

      final user = await AuthService.instance.createUserWithEmailAndPassword(
        _emailController.text.trim(),
        _passwordController.text,
      );

      try {
        await FirestoreService.instance.reserveHandle(username: username, uid: user.uid);
        await FirestoreService.instance.setUserProfile(uid: user.uid, data: {
          'uid': user.uid,
          'email': _emailController.text.trim(),
          'fullName': _fullNameController.text.trim(),
          'username': username,
          'organization': _orgController.text.trim(),
          'role': _role,
          'experience': _experience,
          'interests': _interests,
          'language': _language,
          'preferredTheme': _preferredTheme,
          'timezone': DateTime.now().timeZoneName,
          'newsOptIn': _optInNews,
        });
      } catch (e) {
        await AuthService.instance.signOut();
        rethrow;
      }

      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/home');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GlassBackground(
        child: SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: GlassCard(
                  child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Crear cuenta',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Configura tu perfil de Nootes para una experiencia avanzada de notas',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textMuted),
                      ),
                      const SizedBox(height: 20),

                      Text('Cuenta', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final isWide = constraints.maxWidth > 560;
                          return Flex(
                            direction: Axis.horizontal,
                            children: [
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.only(right: 8.0, bottom: 8.0),
                                  child: TextFormField(
                                    controller: _fullNameController,
                                    decoration: const InputDecoration(
                                      labelText: 'Nombre completo',
                                      prefixIcon: Icon(Icons.person_outline_rounded),
                                    ),
                                    textInputAction: TextInputAction.next,
                                    validator: (v) {
                                      if (v == null || v.trim().isEmpty) return 'Ingresa tu nombre';
                                      if (v.trim().length < 3) return 'Nombre demasiado corto';
                                      return null;
                                    },
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.only(left: 8.0, bottom: 8.0),
                                  child: TextFormField(
                                    controller: _usernameController,
                                    decoration: const InputDecoration(
                                      labelText: 'Usuario (único)',
                                      prefixIcon: Icon(Icons.alternate_email_rounded),
                                      helperText: '3–20 chars, minúsculas, números, . o _',
                                    ),
                                    textInputAction: TextInputAction.next,
                                    validator: (v) {
                                      final value = (v ?? '').trim().toLowerCase();
                                      if (value.isEmpty) return 'Ingresa un usuario';
                                      if (!RegExp(r'^[a-z0-9._]{3,20}$').hasMatch(value)) {
                                        return 'Formato inválido';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _emailController,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          prefixIcon: Icon(Icons.mail_outline_rounded),
                        ),
                        autofillHints: const [AutofillHints.email],
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Ingresa tu email';
                          if (!v.contains('@')) return 'Email inválido';
                          return null;
                        },
                      ),
                      const SizedBox(height: 8),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final isWide = constraints.maxWidth > 560;
                          return Flex(
                            direction: Axis.horizontal,
                            children: [
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.only(right: 8.0, bottom: 8.0),
                                  child: _PasswordField(
                                    controller: _passwordController,
                                    obscure: _obscure,
                                    onToggle: () => setState(() => _obscure = !_obscure),
                                    validator: _passwordValidator,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.only(left: 8.0, bottom: 8.0),
                                  child: TextFormField(
                                    controller: _confirmController,
                                    decoration: InputDecoration(
                                      labelText: 'Confirmar contraseña',
                                      prefixIcon: const Icon(Icons.lock_outline_rounded),
                                      suffixIcon: IconButton(
                                        onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                                        icon: Icon(_obscureConfirm ? Icons.visibility_rounded : Icons.visibility_off_rounded),
                                        tooltip: _obscureConfirm ? 'Mostrar' : 'Ocultar',
                                      ),
                                    ),
                                    obscureText: _obscureConfirm,
                                    textInputAction: TextInputAction.next,
                                    validator: (v) {
                                      if (v != _passwordController.text) return 'No coincide';
                                      return null;
                                    },
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 8),
                      ValueListenableBuilder<TextEditingValue>(
                        valueListenable: _passwordController,
                        builder: (_, val, __) => _PasswordStrength(value: val.text),
                      ),

                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 8),
                      Text('Perfil', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final isWide = constraints.maxWidth > 560;
                          return Flex(
                            direction: Axis.horizontal,
                            children: [
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.only(right: 8.0, bottom: 8.0),
                                  child: TextFormField(
                                    controller: _orgController,
                                    decoration: const InputDecoration(
                                      labelText: 'Equipo/Organización (opcional)',
                                      prefixIcon: Icon(Icons.apartment_rounded),
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.only(left: 8.0, bottom: 8.0),
                                  child: DropdownButtonFormField<String>(
                                    value: _role,
                                    decoration: const InputDecoration(
                                      labelText: 'Rol',
                                      prefixIcon: Icon(Icons.badge_outlined),
                                    ),
                                    items: const [
                                      DropdownMenuItem(value: 'Estudiante', child: Text('Estudiante')),
                                      DropdownMenuItem(value: 'Investigador', child: Text('Investigador')),
                                      DropdownMenuItem(value: 'Desarrollador', child: Text('Desarrollador')),
                                      DropdownMenuItem(value: 'Producto', child: Text('Producto/PM')),
                                      DropdownMenuItem(value: 'Otro', child: Text('Otro')),
                                    ],
                                    onChanged: (v) => setState(() => _role = v ?? _role),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: _experience,
                        decoration: const InputDecoration(
                          labelText: 'Experiencia con toma de notas',
                          prefixIcon: Icon(Icons.insights_outlined),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'Principiante', child: Text('Principiante')),
                          DropdownMenuItem(value: 'Intermedio', child: Text('Intermedio')),
                          DropdownMenuItem(value: 'Avanzado', child: Text('Avanzado')),
                        ],
                        onChanged: (v) => setState(() => _experience = v ?? _experience),
                      ),
                      const SizedBox(height: 8),
                      Text('Intereses (pulsa Enter para añadir)', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textMuted)),
                      const SizedBox(height: 6),
                      LayoutBuilder(builder: (context, constraints) {
                        final maxW = constraints.maxWidth;
                        final inputMax = maxW < 260 ? maxW - 40 : 260.0;
                        return Wrap(
                          spacing: 6,
                          runSpacing: -6,
                          children: [
                            for (final tag in _interests)
                              Chip(
                                label: Text(tag),
                                onDeleted: () => setState(() => _interests.remove(tag)),
                              ),
                            ConstrainedBox(
                              constraints: BoxConstraints(maxWidth: inputMax, minWidth: 120),
                              child: TextField(
                                controller: _interestController,
                                decoration: const InputDecoration(
                                  hintText: 'Añadir interés...',
                                  prefixIcon: Icon(Icons.add_rounded),
                                ),
                                onSubmitted: _addInterest,
                              ),
                            ),
                          ],
                        );
                      }),

                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 8),
                      Text('Preferencias', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final isWide = constraints.maxWidth > 560;
                          return Flex(
                            direction: Axis.horizontal,
                            children: [
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.only(right: 8.0, bottom: 8.0),
                                  child: DropdownButtonFormField<String>(
                                    value: _language,
                                    decoration: const InputDecoration(
                                      labelText: 'Idioma',
                                      prefixIcon: Icon(Icons.language_rounded),
                                    ),
                                    items: const [
                                      DropdownMenuItem(value: 'es', child: Text('Español')),
                                      DropdownMenuItem(value: 'en', child: Text('English')),
                                    ],
                                    onChanged: (v) => setState(() => _language = v ?? _language),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.only(left: 8.0, bottom: 8.0),
                                  child: DropdownButtonFormField<String>(
                                    value: _preferredTheme,
                                    decoration: const InputDecoration(
                                      labelText: 'Tema preferido',
                                      prefixIcon: Icon(Icons.dark_mode_outlined),
                                    ),
                                    items: const [
                                      DropdownMenuItem(value: 'oscuro', child: Text('Oscuro')),
                                      DropdownMenuItem(value: 'claro', child: Text('Claro')),
                                      DropdownMenuItem(value: 'sistema', child: Text('Sistema')),
                                    ],
                                    onChanged: (v) => setState(() => _preferredTheme = v ?? _preferredTheme),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 8),
                      SwitchListTile(
                        value: _optInNews,
                        onChanged: (v) => setState(() => _optInNews = v),
                        title: const Text('Recibir novedades por email'),
                        contentPadding: EdgeInsets.zero,
                      ),
                      CheckboxListTile(
                        value: _acceptTerms,
                        onChanged: (v) => setState(() => _acceptTerms = v ?? false),
                        title: const Text('Acepto los Términos y la Política de Privacidad'),
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                      ),

                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: _loading ? null : _register,
                        child: _loading
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Text('Crear cuenta'),
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => Navigator.of(context).pushReplacementNamed('/login'),
                          child: const Text('Ya tengo una cuenta'),
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

  void _addInterest(String value) {
    final v = value.trim();
    if (v.isEmpty) return;
    if (_interests.length >= 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Máximo 10 intereses')),
      );
      return;
    }
    setState(() {
      _interests.add(v);
      _interestController.clear();
    });
  }

  String? _passwordValidator(String? v) {
    final value = v ?? '';
    if (value.isEmpty) return 'Ingresa una contraseña';
    if (value.length < 8) return 'Mínimo 8 caracteres';
    final hasUpper = value.contains(RegExp(r'[A-Z]'));
    final hasLower = value.contains(RegExp(r'[a-z]'));
    final hasNumber = value.contains(RegExp(r'\d'));
    final hasSpecial = value.contains(RegExp(r'[^A-Za-z0-9]'));
    final okCount = [hasUpper, hasLower, hasNumber, hasSpecial].where((e) => e).length;
    if (okCount < 3) return 'Usa mayúsculas, minúsculas, números o símbolos';
    return null;
  }
}

class _PasswordField extends StatelessWidget {
  const _PasswordField({
    required this.controller,
    required this.obscure,
    required this.onToggle,
    required this.validator,
  });
  final TextEditingController controller;
  final bool obscure;
  final VoidCallback onToggle;
  final String? Function(String?) validator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: 'Contraseña',
        prefixIcon: const Icon(Icons.lock_rounded),
        suffixIcon: IconButton(
          onPressed: onToggle,
          icon: Icon(obscure ? Icons.visibility_rounded : Icons.visibility_off_rounded),
          tooltip: obscure ? 'Mostrar' : 'Ocultar',
        ),
      ),
      obscureText: obscure,
      validator: validator,
    );
  }
}

class _PasswordStrength extends StatelessWidget {
  const _PasswordStrength({required this.value});
  final String value;

  @override
  Widget build(BuildContext context) {
    final length = value.length;
    final hasUpper = value.contains(RegExp(r'[A-Z]'));
    final hasLower = value.contains(RegExp(r'[a-z]'));
    final hasNumber = value.contains(RegExp(r'\d'));
    final hasSpecial = value.contains(RegExp(r'[^A-Za-z0-9]'));
    double score = 0;
    if (length >= 8) score += 0.25;
    if (hasUpper && hasLower) score += 0.25;
    if (hasNumber) score += 0.25;
    if (hasSpecial) score += 0.25;

    Color color;
    String label;
    if (score < 0.5) {
      color = Colors.redAccent;
      label = 'Débil';
    } else if (score < 0.75) {
      color = Colors.orangeAccent;
      label = 'Media';
    } else {
      color = Colors.lightGreenAccent.shade700;
      label = 'Fuerte';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LinearProgressIndicator(
          value: score == 0 ? null : score,
          minHeight: 6,
          color: color,
          backgroundColor: Colors.white10,
        ),
        const SizedBox(height: 6),
        Text(
          'Seguridad de contraseña: $label',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white70),
        ),
      ],
    );
  }
}
