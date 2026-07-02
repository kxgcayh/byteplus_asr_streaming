import 'package:flutter/material.dart';

import 'src/asr_config.dart';
import 'src/asr_response.dart';
import 'src/asr_session_controller.dart';
import 'src/logging.dart';

/// Drop-in page that streams microphone audio into a [AsrSessionController]
/// and renders the latest transcription.
class AsrStreamingPage extends StatefulWidget {
  const AsrStreamingPage({
    super.key,
    required this.config,
    this.log,
    this.onTranscription,
    this.onResponse,
    this.appBarTitle = 'BytePlus ASR',
  });

  final AsrConfig config;
  final AsrLog? log;
  final ValueChanged<String>? onTranscription;
  final ValueChanged<AsrResponse>? onResponse;
  final String appBarTitle;

  @override
  State<AsrStreamingPage> createState() => _AsrStreamingPageState();
}

class _AsrStreamingPageState extends State<AsrStreamingPage> {
  late final AsrSessionController _controller;

  String _lastFiredTranscription = '';
  AsrResponse? _lastFiredResponse;

  @override
  void initState() {
    super.initState();
    _controller = AsrSessionController(config: widget.config, log: widget.log);
    _controller.addListener(_fireCallbacks);
  }

  @override
  void dispose() {
    _controller.removeListener(_fireCallbacks);
    _controller.dispose();
    super.dispose();
  }

  void _fireCallbacks() {
    final response = _controller.lastResponse;
    if (!identical(response, _lastFiredResponse)) {
      _lastFiredResponse = response;
      widget.onResponse?.call(response!);
    }
    final text = _controller.transcription;
    if (text != _lastFiredTranscription) {
      _lastFiredTranscription = text;
      widget.onTranscription?.call(text);
    }
  }

  Future<void> _onStart() async {
    final ok = await _controller.start();
    if (!ok && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_controller.error?.toString() ?? 'Failed to start')));
    }
  }

  Future<void> _onStop() => _controller.stop();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final isRecording = _controller.isRecording;
        final transcription = _controller.transcription;
        return Scaffold(
          appBar: AppBar(title: Text(widget.appBarTitle)),
          body: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton(onPressed: isRecording ? null : _onStart, child: const Text('Start Recording')),
                    const SizedBox(width: 16),
                    ElevatedButton(
                      onPressed: isRecording ? _onStop : null,
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade100),
                      child: const Text('Stop Recording'),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  'Status: ${isRecording ? "Recording & Connected" : "Disconnected"}',
                  style: TextStyle(color: isRecording ? Colors.green : Colors.red, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Transcription Output:', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade400),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: SingleChildScrollView(
                      child: Text(
                        transcription.isEmpty ? 'Waiting for transcription...' : transcription,
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
