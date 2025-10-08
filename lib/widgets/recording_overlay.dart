import 'package:flutter/material.dart';

class RecordingOverlay extends StatelessWidget {
  const RecordingOverlay({super.key, required this.onStop, required this.onCancel, required this.isRecording});

  final VoidCallback onStop;
  final VoidCallback onCancel;
  final bool isRecording;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Material(
          elevation: 8,
          borderRadius: BorderRadius.circular(12),
          color: Colors.black87,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(isRecording ? Icons.mic_rounded : Icons.mic_none_rounded, color: Colors.redAccent),
                const SizedBox(width: 12),
                const Text('Grabando...', style: TextStyle(color: Colors.white)),
                const SizedBox(width: 12),
                FilledButton.icon(onPressed: onStop, icon: const Icon(Icons.stop_rounded), label: const Text('Detener')),
                const SizedBox(width: 8),
                TextButton(onPressed: onCancel, child: const Text('Cancelar', style: TextStyle(color: Colors.white70))),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
