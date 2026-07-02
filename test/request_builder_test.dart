import 'dart:convert';
import 'dart:io' show gzip;
import 'dart:typed_data';

import 'package:byteplus_asr_streaming/byteplus_asr_streaming.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final config = AsrConfig.defaults(apiKey: 'test-key');

  group('RequestBuilder.newAuthHeaders', () {
    test('carries API key, resource id, and a fresh connect id', () {
      final builder = RequestBuilder(config: config);
      final headers = builder.newAuthHeaders();
      expect(headers['X-Api-Key'], 'test-key');
      expect(headers['X-Api-Resource-Id'], 'volc.seedasr.sauc.duration');
      expect(headers['X-Api-Connect-Id'], isNotEmpty);
    });
  });

  group('RequestBuilder.newFullClientRequest', () {
    test('header byte[1] upper nibble is clientFullRequest (0x01)', () {
      final bytes = RequestBuilder(config: config).newFullClientRequest(1);
      expect(bytes[0] >> 4, ProtocolVersion.v1);
      expect(bytes[1] >> 4, MessageType.clientFullRequest);
      expect(bytes[1] & 0x0f, MessageTypeSpecificFlags.posSequence);
    });

    test('payload decompresses to a valid JSON map with audio + request', () {
      final bytes = RequestBuilder(config: config).newFullClientRequest(1);
      final headerSize = bytes[0] & 0x0f;
      var offset = headerSize * 4;
      final seq = ByteData.sublistView(bytes).getInt32(offset, Endian.big);
      expect(seq, 1);
      offset += 4;
      final size = ByteData.sublistView(bytes).getUint32(offset, Endian.big);
      offset += 4;
      final compressed = bytes.sublist(offset, offset + size);
      final json = jsonDecode(utf8.decode(gzip.decode(compressed)))
          as Map<String, dynamic>;
      expect((json['audio'] as Map)['rate'], config.sampleRate);
      expect((json['request'] as Map)['model_name'], config.modelName);
    });
  });

  group('RequestBuilder.newAudioOnlyRequest', () {
    test('isLast=false header has audioOnly type + posSequence', () {
      final bytes = RequestBuilder(config: config)
          .newAudioOnlyRequest(2, Uint8List.fromList([1, 2, 3]));
      expect(bytes[1] >> 4, MessageType.clientAudioOnlyRequest);
      expect(bytes[1] & 0x0f, MessageTypeSpecificFlags.posSequence);
      final seq = ByteData.sublistView(bytes).getInt32(4, Endian.big);
      expect(seq, 2);
    });

    test(
      'isLast=true header carries audioOnly + negWithSequence (regression: '
      'previously the message-type mutation was silently discarded)',
      () {
        final bytes = RequestBuilder(config: config)
            .newAudioOnlyRequest(3, Uint8List.fromList([1, 2, 3]),
                isLast: true);
        expect(bytes[1] >> 4, MessageType.clientAudioOnlyRequest);
        expect(bytes[1] & 0x0f, MessageTypeSpecificFlags.negWithSequence);
        final seq = ByteData.sublistView(bytes).getInt32(4, Endian.big);
        expect(seq, -3);
      },
    );
  });
}