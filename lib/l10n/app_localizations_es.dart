// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appTitle => 'Nootes';

  @override
  String get login => 'Iniciar Sesión';

  @override
  String get register => 'Registrarse';

  @override
  String get email => 'Correo Electrónico';

  @override
  String get password => 'Contraseña';

  @override
  String get forgotPassword => '¿Olvidaste tu contraseña?';

  @override
  String get createAccount => 'Crear Cuenta';

  @override
  String get alreadyHaveAccount => '¿Ya tienes cuenta?';

  @override
  String get noAccount => '¿No tienes cuenta?';

  @override
  String get notes => 'Notas';

  @override
  String get folders => 'Carpetas';

  @override
  String get search => 'Buscar...';

  @override
  String get newNote => 'Nueva Nota';

  @override
  String get newFolder => 'Nueva Carpeta';

  @override
  String get edit => 'Editar';

  @override
  String get delete => 'Eliminar';

  @override
  String get cancel => 'Cancelar';

  @override
  String get save => 'Guardar';

  @override
  String get title => 'Título';

  @override
  String get content => 'Contenido';

  @override
  String get tags => 'Etiquetas';

  @override
  String get createdAt => 'Creado';

  @override
  String get updatedAt => 'Actualizado';

  @override
  String get deleteConfirmation =>
      '¿Estás seguro de que quieres eliminar esto?';

  @override
  String get noteAddedToFolder => 'Nota agregada a la carpeta';

  @override
  String get folderDeleted => 'Carpeta eliminada';

  @override
  String get error => 'Error';

  @override
  String get success => 'Éxito';
}
