import 'dart:convert';
import 'dart:io' show gzip;
import 'dart:typed_data';

import 'package:byteplus_asr_streaming/byteplus_asr_streaming.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const parser = ResponseParser();

  Uint8List buildFrame({
    required int messageType,
    required int flags,
    required int serialization,
    required int compression,
    int payloadSize = 0,
    Uint8List? payload,
  }) {
    final headerSize = 1;
    final out = BytesBuilder()
      ..addByte((ProtocolVersion.v1 << 4) | headerSize)
      ..addByte((messageType << 4) | flags)
      ..addByte((serialization << 4) | compression)
      ..addByte(0x00);
    if (flags & 0x01 != 0) {
      final bd = ByteData(4)..setInt32(0, 1, Endian.big);
      out.add(bd.buffer.asUint8List());
    }
    if (messageType == MessageType.serverFullResponse) {
      final bd = ByteData(4)..setUint32(0, payloadSize, Endian.big);
      out.add(bd.buffer.asUint8List());
    } else if (messageType == MessageType.serverErrorResponse) {
      final bd = ByteData(4)..setInt32(0, 0, Endian.big);
      out.add(bd.buffer.asUint8List());
      final bd2 = ByteData(4)..setUint32(0, payloadSize, Endian.big);
      out.add(bd2.buffer.asUint8List());
    }
    if (payload != null) out.add(payload);
    return out.toBytes();
  }

  test('parses a gzip+json server full response', () {
    final body = utf8.encode(jsonEncode({'result': {'text': 'hello'}}));
    final compressed = gzip.encode(body);
    final frame = buildFrame(
      messageType: MessageType.serverFullResponse,
      flags: MessageTypeSpecificFlags.posSequence,
      serialization: SerializationType.json,
      compression: CompressionType.gzip,
      payloadSize: compressed.length,
      payload: Uint8List.fromList(compressed),
    );
    final r = parser.parseResponse(frame);
    expect(r.payloadSequence, 1);
    expect(r.payloadMsg, isNotNull);
    expect((r.payloadMsg!['result'] as Map)['text'], 'hello');
  });

  test('parses an error response and reports the code', () {
    final r = parser.parseResponse(
      buildFrame(
        messageType: MessageType.serverErrorResponse,
        flags: MessageTypeSpecificFlags.posSequence,
        serialization: SerializationType.json,
        compression: CompressionType.gzip,
        payloadSize: 0,
      ),
    );
    expect(r.code, 0);
  });

  test('returns gracefully and logs when gzip decompression fails', () {
    final calls = <AsrLogLevel>[];
    void log(String m,
        {AsrLogLevel level = AsrLogLevel.info,
        Object? error,
        StackTrace? stackTrace}) {
      calls.add(level);
    }

    final frame = buildFrame(
      messageType: MessageType.serverFullResponse,
      flags: 0,
      serialization: SerializationType.json,
      compression: CompressionType.gzip,
      payloadSize: 5,
      payload: Uint8List.fromList([1, 2, 3, 4, 5]),
    );
    final r = parser.parseResponse(frame, log: log);
    expect(r.payloadMsg, isNull);
    expect(calls, contains(AsrLogLevel.error));
  });
}