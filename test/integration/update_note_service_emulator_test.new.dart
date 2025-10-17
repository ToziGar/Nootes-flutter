import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nootes/services/firestore_service.dart';
import 'package:nootes/firebase_options.dart';

void main() {
  final emulator = Platform.environment['FIRESTORE_EMULATOR_HOST'];

  group('FirestoreService.updateNote emulator integration', () {
    var firebaseAvailable = true;

    setUpAll(() async {
      import 'dart:io';

      import 'package:cloud_firestore/cloud_firestore.dart';
      import 'package:flutter/foundation.dart' show debugPrint;
      import 'package:firebase_core/firebase_core.dart';
      import 'package:flutter_test/flutter_test.dart';
      import 'package:nootes/services/firestore_service.dart';
      import 'package:nootes/firebase_options.dart';

      void main() {
        final emulator = Platform.environment['FIRESTORE_EMULATOR_HOST'];

        group('FirestoreService.updateNote emulator integration', () {
          var firebaseAvailable = true;

          setUpAll(() async {
            if (emulator == null) return;
            TestWidgetsFlutterBinding.ensureInitialized();
            import 'dart:io';

            import 'package:cloud_firestore/cloud_firestore.dart';
            import 'package:flutter/foundation.dart' show debugPrint;
            import 'package:firebase_core/firebase_core.dart';
            import 'package:flutter_test/flutter_test.dart';
            import 'package:nootes/services/firestore_service.dart';
            import 'package:nootes/firebase_options.dart';

            /// Integration test that runs against the Firestore emulator.
            /// Skips automatically when the environment variable
            // placeholder: removed corrupted variant
            void main() {
