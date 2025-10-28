import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nootes/services/providers.dart';
import 'package:nootes/domain/note.dart';
import 'package:nootes/services/firestore_dev.dart';
import 'package:http/http.dart' as http;
import 'package:nootes/firebase_options.dart' as options;

/// Minimal REST client implementing only the methods we need for the test.
class _EmulatorRestClient extends DevFirestoreService {
  final String host;
  final String projectId;

  _EmulatorRestClient(this.host, this.projectId);

  Uri _docUri(String uid, String noteId) => Uri.parse('http://$host/v1/projects/$projectId/databases/(default)/documents/users/$uid/notes/$noteId');

  Uri _createUri(String uid, String noteId) => Uri.parse('http://$host/v1/projects/$projectId/databases/(default)/documents/users/$uid/notes?documentId=$noteId');

  @override
  Future<void> updateNote({required String uid, required String noteId, required Map<String, dynamic> data}) async {
    final payload = {
      'fields': data.map((k, v) => MapEntry(k, {'stringValue': v.toString()})),
    };
    final resp = await http.post(_createUri(uid, noteId), body: jsonEncode(payload), headers: {'Content-Type': 'application/json'});
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception('emulator-update-failed-${resp.statusCode}');
    }
  }

  Future<Map<String, dynamic>?> readRemote(String uid, String noteId) async {
    final resp = await http.get(_docUri(uid, noteId));
    if (resp.statusCode == 404) return null;
    if (resp.statusCode < 200 || resp.statusCode >= 300) return null;
    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    final fields = body['fields'] as Map<String, dynamic>?;
    if (fields == null) return null;
    final out = <String, dynamic>{};
    fields.forEach((k, v) {
      if (v is Map && v['stringValue'] != null) out[k] = v['stringValue'];
    });
    return out;
  }
}

void main() {
  testWidgets('sync with emulator (skips if FIRESTORE_EMULATOR_HOST not set)', (tester) async {
    final host = Platform.environment['FIRESTORE_EMULATOR_HOST'];
    if (host == null || host.isEmpty) return;

    final projectId = options.DefaultFirebaseOptions.currentPlatform.projectId;

    final rest = _EmulatorRestClient(host, projectId);

    // Use a ProviderContainer to override providers without building widgets.
    final container = ProviderContainer(overrides: [firestoreServiceProvider.overrideWithValue(rest)]);
    addTearDown(container.dispose);

    // Obtain the SyncService and enqueue a note; the provider will construct
    // SyncService using our overridden firestore service.
    final sync = container.read(syncServiceProvider) as dynamic;

    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final note = Note(id: id, title: 'INT $id', content: 'integration');
    await sync.enqueue(note);

    // Wait for up to 8 seconds for the remote document to appear.
    final timeout = DateTime.now().add(const Duration(seconds: 8));
    bool found = false;
    while (DateTime.now().isBefore(timeout)) {
      final doc = await rest.readRemote('local', id);
      if (doc != null) {
        found = true;
        break;
      }
      await Future.delayed(const Duration(milliseconds: 250));
    }

    expect(found, isTrue, reason: 'Document was not found in emulator');
  });
}
