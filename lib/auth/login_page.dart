import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';
import '../theme/color_utils.dart';
import '../services/auth_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  
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
    _emailController.dispose();
    _passwordController.dispose();
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;
    
    // Feedback háptico
    HapticFeedback.lightImpact();
    
    setState(() => _loading = true);
    try {
      await AuthService.instance
          .signInWithEmailAndPassword(_emailController.text.trim(), _passwordController.text);
      if (mounted) {
        // Feedback de éxito
        HapticFeedback.mediumImpact();
        Navigator.of(context).pushReplacementNamed('/home');
      }
    } catch (e) {
      // Feedback de error
      HapticFeedback.heavyImpact();
      
      String msg = 'Error al iniciar sesión';
      final errorStr = e.toString().toLowerCase();
      
      if (errorStr.contains('invalid-email')) {
        msg = 'Email inválido';
      } else if (errorStr.contains('wrong-password') || errorStr.contains('invalid-credential')) {
        msg = 'Email o contraseña incorrectos';
      } else if (errorStr.contains('user-not-found')) {
        msg = 'Usuario no encontrado. ¿Deseas crear una cuenta?';
      } else if (errorStr.contains('user-disabled')) {
        msg = 'Esta cuenta ha sido deshabilitada';
      } else if (errorStr.contains('too-many-requests')) {
        msg = 'Demasiados intentos. Intenta más tarde';
      } else if (errorStr.contains('network')) {
        msg = 'Error de conexión. Verifica tu internet';
      } else {
        msg = 'Error: ${errorStr.split(':').last.trim()}';
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            action: errorStr.contains('user-not-found')
                ? SnackBarAction(
                    label: 'Crear cuenta',
                    textColor: Colors.white,
                    onPressed: () => Navigator.of(context).pushNamed('/register'),
                  )
                : null,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
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
              AppColors.primary.withOpacityCompat(0.1),
              AppColors.secondary.withOpacityCompat(0.1),
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
                    constraints: const BoxConstraints(maxWidth: 400),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).scaffoldBackgroundColor,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withOpacityCompat(0.1),
                            blurRadius: 30,
                            offset: const Offset(0, 15),
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
                                height: 60,
                                width: 60,
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) {
                                  return const Icon(
                                    Icons.note_alt_rounded, 
                                    size: 60, 
                                    color: Colors.white,
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 24),
                            
                            // Título mejorado
                            ShaderMask(
                              shaderCallback: (bounds) => LinearGradient(
                                colors: [AppColors.primary, AppColors.primaryLight],
                              ).createShader(bounds),
                              child: Text(
                                'Nootes',
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Bienvenido de vuelta',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacityCompat(0.7),
                              ),
                            ),
                            const SizedBox(height: 32),
                            
                            // Campo email mejorado
                            _buildModernTextField(
                              key: const Key('login_email_field'),
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
                            const SizedBox(height: 20),
                            
                            // Campo contraseña mejorado
                            _buildModernTextField(
                              controller: _passwordController,
                              label: 'Contraseña',
                              icon: Icons.lock_outline_rounded,
                              obscureText: _obscure,
                              autofillHints: const [AutofillHints.password],
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
                            const SizedBox(height: 32),
                            
                            // Botón de login mejorado
                            _buildModernButton(),
                            const SizedBox(height: 20),
                            
                            // Enlaces (responsivo, evita overflow horizontal)
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final isNarrow = constraints.maxWidth < 380;
                                final children = [
                                  TextButton(
                                    onPressed: () => Navigator.pushNamed(context, '/register'),
                                    child: Text(
                                      'Crear cuenta',
                                      style: TextStyle(color: AppColors.primary),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.pushNamed(context, '/forgot-password'),
                                    child: Text(
                                      'Olvidé mi contraseña',
                                      style: TextStyle(color: AppColors.secondary),
                                    ),
                                  ),
                                ];
                                if (isNarrow) {
                                  return Wrap(
                                    alignment: WrapAlignment.spaceBetween,
                                    runAlignment: WrapAlignment.center,
                                    spacing: 12,
                                    runSpacing: 8,
                                    children: children,
                                  );
                                }
                                return Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: children,
                                );
                              },
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
    Key? key,
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
      key: key,
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
        style: Theme.of(context).textTheme.bodyLarge,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: AppColors.primary),
          suffixIcon: suffixIcon,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.transparent,
          labelStyle: TextStyle(color: AppColors.primary.withOpacityCompat(0.8)),
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
        onPressed: _loading ? null : _signIn,
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
                'Iniciar Sesión',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }
}

