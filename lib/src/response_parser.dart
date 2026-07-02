import 'dart:convert';
import 'dart:io' show gzip;
import 'dart:typed_data';

import 'asr_response.dart';
import 'logging.dart';
import 'protocol_constants.dart';

/// Parses binary response frames from the BytePlus ASR Streaming server.
///
/// Stateless; pass the same [AsrLog] you handed to the client.
class ResponseParser {
  const ResponseParser();

  AsrResponse parseResponse(Uint8List msg, {AsrLog? log}) {
    final response = AsrResponse();

    final headerSize = msg[0] & 0x0f;
    final messageType = msg[1] >> 4;
    final specificFlags = msg[1] & 0x0f;
    final serialization = msg[2] >> 4;
    final compression = msg[2] & 0x0f;

    int offset = headerSize * 4;
    final bd = ByteData.sublistView(msg);

    if ((specificFlags & 0x01) != 0) {
      response.payloadSequence = bd.getInt32(offset, Endian.big);
      offset += 4;
    }
    if ((specificFlags & 0x02) != 0) {
      response.isLastPackage = true;
    }
    if ((specificFlags & 0x04) != 0) {
      response.event = bd.getInt32(offset, Endian.big);
      offset += 4;
    }

    if (messageType == MessageType.serverFullResponse) {
      response.payloadSize = bd.getUint32(offset, Endian.big);
      offset += 4;
    } else if (messageType == MessageType.serverErrorResponse) {
      response.code = bd.getInt32(offset, Endian.big);
      offset += 4;
      response.payloadSize = bd.getUint32(offset, Endian.big);
      offset += 4;
      log?.call(
        'Server Error Code: ${response.code}',
        level: AsrLogLevel.error,
      );
    }

    if (offset >= msg.length) return response;

    List<int> payload = msg.sublist(offset);

    if (compression == CompressionType.gzip) {
      try {
        payload = gzip.decode(payload);
      } catch (e) {
        log?.call(
          'Failed to decompress payload: $e',
          level: AsrLogLevel.error,
          error: e,
        );
        return response;
      }
    }

    if (serialization == SerializationType.json) {
      try {
        response.payloadMsg =
            jsonDecode(utf8.decode(payload)) as Map<String, dynamic>;
      } catch (e) {
        log?.call(
          'Failed to parse payload JSON: $e',
          level: AsrLogLevel.error,
          error: e,
        );
      }
    }

    return response;
  }
}
