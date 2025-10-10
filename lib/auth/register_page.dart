import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../theme/app_theme.dart';
import '../theme/color_utils.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> with TickerProviderStateMixin {
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
  final bool _optInNews = false;

  final String _language = 'es';
  final String _role = 'Estudiante';
  final String _experience = 'Intermedio';
  final String _preferredTheme = 'oscuro';

  final List<String> _interests = [];

  // Animaciones para el nuevo diseño
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    
    // Configurar animaciones
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    ));
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutBack,
    ));
    
    // Iniciar animaciones
    _fadeController.forward();
    _slideController.forward();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    _orgController.dispose();
    _interestController.dispose();
    _fadeController.dispose();
    _slideController.dispose();
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
        throw FirebaseException(plugin: 'app', message: 'Usuario inválido');
      }

      final handles = FirebaseFirestore.instance.collection('handles');
      final handleDoc = await handles.doc(username).get();
      if (handleDoc.exists) {
        throw FirebaseException(plugin: 'cloud_firestore', message: 'El nombre de usuario ya está en uso');
      }

      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      final uid = cred.user!.uid;
      await FirebaseFirestore.instance.runTransaction((tx) async {
        final handleRef = handles.doc(username);
        final userRef = FirebaseFirestore.instance.collection('users').doc(uid);
        final existing = await tx.get(handleRef);
        if (existing.exists) {
          throw FirebaseException(plugin: 'cloud_firestore', message: 'El nombre de usuario ya está en uso');
        }
        tx.set(handleRef, {
          'uid': uid,
          'createdAt': FieldValue.serverTimestamp(),
        });
        tx.set(userRef, {
          'uid': uid,
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
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });

      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/home');
      }
    } on FirebaseAuthException catch (e) {
      final msg = _mapAuthError(e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
        );
      }
    } on FirebaseException catch (e) {
      try { await FirebaseAuth.instance.currentUser?.delete(); } catch (_) {}
      await FirebaseAuth.instance.signOut();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message ?? 'No se pudo guardar el perfil')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _mapAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'Este email ya está en uso';
      case 'invalid-email':
        return 'Email inválido';
      case 'weak-password':
        return 'Contraseña débil';
      default:
        return e.message ?? 'Error al registrar';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white,
              AppColors.primaryLight.withOpacityCompat(0.1),
              AppColors.accent.withOpacityCompat(0.05),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 450),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withOpacityCompat(0.15),
                            blurRadius: 40,
                            offset: const Offset(0, 20),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(32),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Logo mejorado con efecto
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [AppColors.primary, AppColors.primaryLight],
                                ),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primary.withOpacityCompat(0.3),
                                    blurRadius: 20,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: Image.asset(
                                'LOGO.webp',
                                height: 50,
                                width: 50,
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) {
                                  return const Icon(
                                    Icons.person_add_rounded, 
                                    size: 50, 
                                    color: Colors.white,
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 20),
                            
                            // Título mejorado
                              ShaderMask(
                              shaderCallback: (bounds) => LinearGradient(
                                colors: [AppColors.primary, AppColors.primaryLight],
                              ).createShader(bounds),
                              child: Text(
                                'Crear Cuenta',
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Únete a Nootes y organiza tus ideas',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                color: AppColors.primary.withOpacityCompat(0.8),
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 32),
                            
                            // Campos de formulario modernos
                            _buildModernTextField(
                              controller: _fullNameController,
                              label: 'Nombre completo',
                              icon: Icons.person_outline_rounded,
                              keyboardType: TextInputType.name,
                              autofillHints: const [AutofillHints.name],
                              validator: (value) {
                                if (value?.isEmpty ?? true) return 'Ingresa tu nombre';
                                if (value!.length < 2) return 'Mínimo 2 caracteres';
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            
                            _buildModernTextField(
                              controller: _usernameController,
                              label: 'Nombre de usuario',
                              icon: Icons.alternate_email_rounded,
                              keyboardType: TextInputType.name,
                              autofillHints: const [AutofillHints.username],
                              validator: (value) {
                                if (value?.isEmpty ?? true) return 'Ingresa tu usuario';
                                final username = value!.trim().toLowerCase();
                                if (!RegExp(r'^[a-z0-9._]{3,20}$').hasMatch(username)) {
                                  return 'Solo letras, números, puntos y guiones bajos (3-20 caracteres)';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            
                            _buildModernTextField(
                              controller: _emailController,
                              label: 'Email',
                              icon: Icons.email_outlined,
                              keyboardType: TextInputType.emailAddress,
                              autofillHints: const [AutofillHints.email],
                              validator: (value) {
                                if (value?.isEmpty ?? true) return 'Ingresa tu email';
                                if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value!)) {
                                  return 'Email inválido';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            
                            _buildModernTextField(
                              controller: _passwordController,
                              label: 'Contraseña',
                              icon: Icons.lock_outline_rounded,
                              obscureText: _obscure,
                              autofillHints: const [AutofillHints.newPassword],
                              suffixIcon: IconButton(
                                onPressed: () => setState(() => _obscure = !_obscure),
                                icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                              ),
                              validator: (value) {
                                if (value?.isEmpty ?? true) return 'Ingresa tu contraseña';
                                if (value!.length < 6) return 'Mínimo 6 caracteres';
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            
                            _buildModernTextField(
                              controller: _confirmController,
                              label: 'Confirmar contraseña',
                              icon: Icons.lock_outline_rounded,
                              obscureText: _obscureConfirm,
                              autofillHints: const [AutofillHints.newPassword],
                              suffixIcon: IconButton(
                                onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                                icon: Icon(_obscureConfirm ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                              ),
                              validator: (value) {
                                if (value?.isEmpty ?? true) return 'Confirma tu contraseña';
                                if (value != _passwordController.text) return 'Las contraseñas no coinciden';
                                return null;
                              },
                            ),
                            const SizedBox(height: 24),
                            
                            // Términos y condiciones
                            Row(
                              children: [
                                Checkbox(
                                  value: _acceptTerms,
                                  onChanged: (value) => setState(() => _acceptTerms = value ?? false),
                                  activeColor: AppColors.primary,
                                ),
                                Expanded(
                                  child: Text(
                                    'Acepto los Términos de Servicio y Política de Privacidad',
                                    style: const TextStyle(
                                      color: Colors.black87,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                            
                            // Botón de registro
                            _buildModernButton(),
                            const SizedBox(height: 20),
                            
                            // Enlace para login
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  '¿Ya tienes cuenta? ',
                                  style: const TextStyle(
                                    color: Colors.black87,
                                    fontSize: 16,
                                  ),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: Text(
                                    'Iniciar sesión',
                                    style: TextStyle(
                                      color: AppColors.primary,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
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
        ),
      ),
    );
  }

  Widget _buildModernTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscureText = false,
    TextInputType? keyboardType,
    List<String>? autofillHints,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primary.withOpacityCompat(0.2),
          width: 1,
        ),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withOpacityCompat(0.05),
            Colors.transparent,
          ],
        ),
      ),
      child: TextFormField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        autofillHints: autofillHints,
        validator: validator,
        style: const TextStyle(
          color: Colors.black87,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: AppColors.primary),
          suffixIcon: suffixIcon,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.white,
          labelStyle: TextStyle(
            color: AppColors.primary,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
      ),
    );
  }

  Widget _buildModernButton() {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primaryLight],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacityCompat(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: (_loading || !_acceptTerms) ? null : _register,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: _loading
            ? const SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Text(
                'Crear Cuenta',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }
}
