import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:record/record.dart';

import 'asr_config.dart';
import 'asr_response.dart';
import 'asr_ws_client.dart';
import 'logging.dart';

/// Orchestrates a single recording + ASR streaming session.
///
/// Composes [BytePlusAsrClient] and [AudioRecorder]; exposes observable
/// state for UI binding and imperative [start] / [stop] for user actions.
class AsrSessionController extends ChangeNotifier {
  AsrSessionController({required this.config, AsrLog? log, BytePlusAsrClient? client, AudioRecorder? recorder})
    : _log = log ?? AsrLoggers.silent(),
      _client = client ?? BytePlusAsrClient(config: config, log: log),
      _recorder = recorder ?? AudioRecorder();

  final AsrConfig config;
  final AsrLog _log;
  final BytePlusAsrClient _client;
  final AudioRecorder _recorder;

  StreamSubscription<Uint8List>? _audioSub;
  StreamSubscription<AsrResponse>? _responseSub;

  bool _isRecording = false;
  String _transcription = '';
  AsrResponse? _lastResponse;
  Object? _error;

  bool get isRecording => _isRecording;
  String get transcription => _transcription;
  AsrResponse? get lastResponse => _lastResponse;
  Object? get error => _error;

  /// Starts a session. Returns `false` if microphone permission was denied
  /// or the connection failed.
  Future<bool> start() async {
    if (_isRecording) return true;

    if (!await _recorder.hasPermission()) {
      _error = 'Microphone permission is required.';
      _log.call(_error.toString(), level: AsrLogLevel.warn);
      notifyListeners();
      return false;
    }

    try {
      await _client.createConnection();
      await _client.sendFullClientRequest();
      _responseSub = _client.recvMessages().listen(_handleResponse);

      final stream = await _recorder.startStream(
        RecordConfig(encoder: AudioEncoder.pcm16bits, sampleRate: config.sampleRate, numChannels: config.numChannels),
      );
      _audioSub = stream.listen(_client.sendAudioSegment);

      _isRecording = true;
      _transcription = '';
      _error = null;
    } catch (e, st) {
      _log.call('Session start failed: $e', level: AsrLogLevel.error, error: e, stackTrace: st);
      _error = e;
      await _stopInternal();
    }
    notifyListeners();
    return _isRecording;
  }

  /// Signals end-of-audio to the server and tears down the session.
  Future<void> stop() async {
    if (!_isRecording) return;
    _client.sendAudioSegment(Uint8List(0), isLast: true);
    await _stopInternal();
    notifyListeners();
  }

  Future<void> _stopInternal() async {
    await _audioSub?.cancel();
    _audioSub = null;
    await _responseSub?.cancel();
    _responseSub = null;

    if (await _recorder.isRecording()) {
      await _recorder.stop();
    }
    await _client.close();

    _isRecording = false;
  }

  void _handleResponse(AsrResponse response) {
    _lastResponse = response;
    final msg = response.payloadMsg;
    if (msg != null) {
      _log.call(
        'Received response: code=${response.code} '
        'seq=${response.payloadSequence} msg=$msg',
        level: AsrLogLevel.debug,
      );
      final text = _extractText(msg);
      if (text != null) _transcription = text;
    }
    notifyListeners();

    if (response.isLastPackage) {
      _tearDownForServerEnd();
    }
  }

  void _tearDownForServerEnd() {
    _audioSub?.cancel();
    _audioSub = null;
    _responseSub?.cancel();
    _responseSub = null;
    _recorder.stop();
    _client.close();
    _isRecording = false;
  }

  String? _extractText(Map<String, dynamic> msg) {
    final result = msg['result'];
    if (result is Map && result['text'] != null) {
      return result['text'].toString();
    }
    if (result is List && result.isNotEmpty) {
      final first = result.first;
      if (first is Map && first['text'] != null) {
        return first['text'].toString();
      }
    }
    return null;
  }

  @override
  Future<void> dispose() async {
    await _stopInternal();
    await _recorder.dispose();
    super.dispose();
  }
}
