import 'dart:typed_data';

import 'package:byteplus_asr_streaming/byteplus_asr_streaming.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AsrRequestHeader.toBytes', () {
    test('default header matches expected 4-byte layout', () {
      final header = AsrRequestHeader.defaultHeader();
      expect(header.toBytes(), Uint8List.fromList([0x11, 0x11, 0x11, 0x00]));
    });

    test('upper-nibble messageType is encoded into byte[1]', () {
      final header = AsrRequestHeader.defaultHeader()
          .withMessageType(MessageType.clientAudioOnlyRequest);
      final bytes = header.toBytes();
      expect(bytes[1] >> 4, MessageType.clientAudioOnlyRequest);
    });

    test('flags byte carries posSequence by default', () {
      final bytes = AsrRequestHeader.defaultHeader().toBytes();
      expect(bytes[1] & 0x0f, MessageTypeSpecificFlags.posSequence);
    });
  });

  group('AsrRequestHeader immutability', () {
    test('with* methods return new instances; original is unchanged', () {
      final h1 = AsrRequestHeader.defaultHeader();
      final h2 = h1.withMessageType(MessageType.clientAudioOnlyRequest);
      expect(identical(h1, h2), isFalse);
      expect(h1.messageType, MessageType.clientFullRequest);
      expect(h2.messageType, MessageType.clientAudioOnlyRequest);
    });

    test('chained with* preserves previously-set fields', () {
      final h = AsrRequestHeader.defaultHeader()
          .withMessageType(MessageType.clientAudioOnlyRequest)
          .withMessageTypeSpecificFlags(MessageTypeSpecificFlags.negWithSequence);
      expect(h.messageType, MessageType.clientAudioOnlyRequest);
      expect(
        h.messageTypeSpecificFlags,
        MessageTypeSpecificFlags.negWithSequence,
      );
      expect(h.serializationType, SerializationType.json);
      expect(h.compressionType, CompressionType.gzip);
    });
  });
}