import 'dart:convert';
import 'dart:io' show gzip;
import 'dart:typed_data';

import 'package:uuid/uuid.dart';

import 'asr_config.dart';
import 'asr_request_header.dart';
import 'protocol_constants.dart';

/// Assembles binary request frames for the SAUC protocol. Stateless apart
/// from the [AsrConfig] and an injectable [Uuid] for tests.
class RequestBuilder {
  RequestBuilder({required this.config, Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  final AsrConfig config;
  final Uuid _uuid;

  Map<String, String> newAuthHeaders() {
    return <String, String>{
      'X-Api-Key': config.apiKey,
      'X-Api-Resource-Id': config.resourceId,
      'X-Api-Connect-Id': _uuid.v4(),
    };
  }

  /// Full-client request frame containing the connection handshake JSON.
  Uint8List newFullClientRequest(int seq) {
    final header = AsrRequestHeader.defaultHeader();

    final payload = <String, dynamic>{
      'user': {'uid': config.userUid},
      'audio': {
        'format': config.audioFormat,
        'codec': config.audioCodec,
        'rate': config.sampleRate,
        'bits': config.bitsPerSample,
        'channel': config.numChannels,
        'language': config.language,
      },
      'request': {
        'model_name': config.modelName,
        'enable_auto_lang': config.enableAutoLang,
        'enable_itn': config.enableItn,
        'enable_punc': config.enablePunc,
        'result_type': config.resultType,
        'end_window_size': config.endWindowMs,
      },
    };

    final payloadBytes = utf8.encode(jsonEncode(payload));
    final compressedPayload = gzip.encode(payloadBytes);
    final payloadSize = compressedPayload.length;

    final builder = BytesBuilder()
      ..add(header.toBytes())
      ..add(_int32BigEndian(seq))
      ..add(_uint32BigEndian(payloadSize))
      ..add(compressedPayload);

    return builder.toBytes();
  }

  /// Audio-only frame for one PCM segment. When [isLast] is true the
  /// sequence number is negated to signal end-of-stream.
  Uint8List newAudioOnlyRequest(int seq, Uint8List segment,
      {bool isLast = false}) {
    final base = AsrRequestHeader.defaultHeader();
    final header = isLast
        ? base
            .withMessageType(MessageType.clientAudioOnlyRequest)
            .withMessageTypeSpecificFlags(
                MessageTypeSpecificFlags.negWithSequence)
        : base
            .withMessageType(MessageType.clientAudioOnlyRequest)
            .withMessageTypeSpecificFlags(MessageTypeSpecificFlags.posSequence);

    final seqToSend = isLast ? -seq : seq;
    final compressedSegment = gzip.encode(segment);

    final builder = BytesBuilder()
      ..add(header.toBytes())
      ..add(_int32BigEndian(seqToSend))
      ..add(_uint32BigEndian(compressedSegment.length))
      ..add(compressedSegment);

    return builder.toBytes();
  }

  static Uint8List _int32BigEndian(int value) {
    final bd = ByteData(4)..setInt32(0, value, Endian.big);
    return bd.buffer.asUint8List();
  }

  static Uint8List _uint32BigEndian(int value) {
    final bd = ByteData(4)..setUint32(0, value, Endian.big);
    return bd.buffer.asUint8List();
  }
}