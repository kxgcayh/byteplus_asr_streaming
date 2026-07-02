import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:record/record.dart';

import 'asr_config.dart';
import 'asr_response.dart';
import 'asr_ws_client.dart';
import 'logging.dart';

/// Drop-in page that streams microphone audio into a [BytePlusAsrClient]
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
  bool _isRecording = false;
  String _transcription = '';

  BytePlusAsrClient? _client;
  final AudioRecorder _audioRecorder = AudioRecorder();
  StreamSubscription<Uint8List>? _audioStreamSubscription;
  StreamSubscription<AsrResponse>? _responseSubscription;

  AsrLog get _log => widget.log ?? AsrLoggers.silent();

  Future<void> _startRecordingAndConnect() async {
    if (!await _audioRecorder.hasPermission()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Microphone permission is required.')));
      return;
    }

    final client = BytePlusAsrClient(config: widget.config, log: widget.log);
    _client = client;

    try {
      await client.createConnection();
      await client.sendFullClientRequest();
      _responseSubscription = client.recvMessages().listen(_handleResponse);

      setState(() {
        _isRecording = true;
        _transcription = '';
      });

      final audioStream = await _audioRecorder.startStream(
        RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: widget.config.sampleRate,
          numChannels: widget.config.numChannels,
        ),
      );
      _audioStreamSubscription = audioStream.listen((data) {
        client.sendAudioSegment(data);
      });
    } catch (e, st) {
      _log.call('Connection failed: $e', level: AsrLogLevel.error, error: e, stackTrace: st);
      await _cleanup();
    }
  }

  Future<void> _stopRecordingAndDisconnect() async {
    _client?.sendAudioSegment(Uint8List(0), isLast: true);
    await _cleanup();
  }

  Future<void> _cleanup() async {
    await _audioStreamSubscription?.cancel();
    _audioStreamSubscription = null;
    await _responseSubscription?.cancel();
    _responseSubscription = null;

    if (await _audioRecorder.isRecording()) {
      await _audioRecorder.stop();
    }
    await _client?.close();
    _client = null;

    if (mounted) {
      setState(() {
        _isRecording = false;
        _transcription = '';
      });
    }
  }

  void _handleResponse(AsrResponse response) {
    final msg = response.payloadMsg;
    widget.onResponse?.call(response);
    if (msg == null) return;

    _log.call(
      'Received response: code=${response.code} '
      'seq=${response.payloadSequence} msg=$msg',
      level: AsrLogLevel.debug,
    );

    String? maybeText;
    if (msg['result'] is Map && msg['result']['text'] != null) {
      maybeText = msg['result']['text'].toString();
    } else if (msg['result'] is List && (msg['result'] as List).isNotEmpty) {
      final first = (msg['result'] as List).first;
      if (first is Map && first['text'] != null) {
        maybeText = first['text'].toString();
      }
    }
    final text = maybeText;
    if (text != null) {
      setState(() => _transcription = text);
      widget.onTranscription?.call(text);
    }

    if (response.isLastPackage) {
      _cleanup();
    }
  }

  @override
  void dispose() {
    _cleanup();
    _audioRecorder.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.appBarTitle)),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: _isRecording ? null : _startRecordingAndConnect,
                  child: const Text('Start Recording'),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: _isRecording ? _stopRecordingAndDisconnect : null,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade100),
                  child: const Text('Stop Recording'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              'Status: ${_isRecording ? "Recording & Connected" : "Disconnected"}',
              style: TextStyle(color: _isRecording ? Colors.green : Colors.red, fontWeight: FontWeight.bold),
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
                    _transcription.isEmpty ? 'Waiting for transcription...' : _transcription,
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
