import 'dart:async';
import 'dart:typed_data';

import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'asr_config.dart';
import 'asr_response.dart';
import 'logging.dart';
import 'request_builder.dart';
import 'response_parser.dart';

/// WebSocket client wrapper for the BytePlus ASR Streaming SAUC protocol.
///
/// Audio is fed in via [sendAudioSegment]; server responses stream out via
/// [recvMessages]. Mirrors the Python reference client 1:1 but accepts PCM
/// bytes instead of a WAV file.
class BytePlusAsrClient {
  BytePlusAsrClient({
    required this.config,
    AsrLog? log,
    RequestBuilder? builder,
  }) : _log = log ?? AsrLoggers.silent(),
       _builder = builder ?? RequestBuilder(config: config) {
    _parser = ResponseParser();
  }

  final AsrConfig config;
  final AsrLog _log;
  final RequestBuilder _builder;
  late final ResponseParser _parser;

  int seq = 1;
  WebSocketChannel? conn;

  Future<void> createConnection() async {
    seq = 1;
    final headers = _builder.newAuthHeaders();
    try {
      conn = IOWebSocketChannel.connect(
        Uri.parse(config.wsUrl),
        headers: headers,
      );
      _log.call('Connected to ${config.wsUrl}', level: AsrLogLevel.info);
    } catch (e, st) {
      _log.call(
        'Failed to connect to WebSocket: $e',
        level: AsrLogLevel.error,
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  Future<AsrResponse?> sendFullClientRequest() async {
    final request = _builder.newFullClientRequest(seq);
    final sentSeq = seq;
    seq += 1;
    try {
      conn!.sink.add(request);
      _log.call(
        'Sent full client request with seq: $sentSeq',
        level: AsrLogLevel.info,
      );
      // The server may not respond until audio arrives, so don't block here.
      return null;
    } catch (e, st) {
      _log.call(
        'Failed to send full client request: $e',
        level: AsrLogLevel.error,
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  void sendAudioSegment(Uint8List segment, {bool isLast = false}) {
    final request = _builder.newAudioOnlyRequest(seq, segment, isLast: isLast);
    conn!.sink.add(request);
    if (!isLast) seq += 1;
  }

  Stream<AsrResponse> recvMessages() {
    final controller = StreamController<AsrResponse>();
    conn!.stream.listen(
      (message) {
        Uint8List? bytes;
        if (message is Uint8List) {
          bytes = message;
        } else if (message is List<int>) {
          bytes = Uint8List.fromList(message);
        } else if (message is String) {
          _log.call('Received String: $message', level: AsrLogLevel.debug);
        }
        if (bytes == null) return;
        if (bytes.length < 4) return;
        final response = _parser.parseResponse(bytes, log: _log);
        if (!controller.isClosed) {
          controller.add(response);
          if (response.isLastPackage || response.code != 0) {
            controller.close();
          }
        }
      },
      onError: (Object e, StackTrace st) {
        _log.call(
          'WebSocket error: $e',
          level: AsrLogLevel.error,
          error: e,
          stackTrace: st,
        );
        controller.addError(e, st);
        controller.close();
      },
      onDone: () {
        _log.call('WebSocket connection closed', level: AsrLogLevel.info);
        controller.close();
      },
      cancelOnError: false,
    );
    return controller.stream;
  }

  Future<void> close() async {
    await conn?.sink.close();
  }
}
