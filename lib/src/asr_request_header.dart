import 'dart:typed_data';

import 'protocol_constants.dart';

/// Immutable 4-byte SAUC protocol header.
///
/// Each `with*` returns a new instance rather than mutating `this`, which
/// preserves fluent chaining at call sites and removes the silent-mutation
/// bug that existed when this class was mutable.
class AsrRequestHeader {
  const AsrRequestHeader({
    this.messageType = MessageType.clientFullRequest,
    this.messageTypeSpecificFlags = MessageTypeSpecificFlags.posSequence,
    this.serializationType = SerializationType.json,
    this.compressionType = CompressionType.gzip,
    this.reservedData = const <int>[0x00],
  });

  final int messageType;
  final int messageTypeSpecificFlags;
  final int serializationType;
  final int compressionType;
  final List<int> reservedData;

  AsrRequestHeader withMessageType(int value) => AsrRequestHeader(
    messageType: value,
    messageTypeSpecificFlags: messageTypeSpecificFlags,
    serializationType: serializationType,
    compressionType: compressionType,
    reservedData: reservedData,
  );

  AsrRequestHeader withMessageTypeSpecificFlags(int value) => AsrRequestHeader(
    messageType: messageType,
    messageTypeSpecificFlags: value,
    serializationType: serializationType,
    compressionType: compressionType,
    reservedData: reservedData,
  );

  AsrRequestHeader withSerializationType(int value) => AsrRequestHeader(
    messageType: messageType,
    messageTypeSpecificFlags: messageTypeSpecificFlags,
    serializationType: value,
    compressionType: compressionType,
    reservedData: reservedData,
  );

  AsrRequestHeader withCompressionType(int value) => AsrRequestHeader(
    messageType: messageType,
    messageTypeSpecificFlags: messageTypeSpecificFlags,
    serializationType: serializationType,
    compressionType: value,
    reservedData: reservedData,
  );

  AsrRequestHeader withReservedData(List<int> value) => AsrRequestHeader(
    messageType: messageType,
    messageTypeSpecificFlags: messageTypeSpecificFlags,
    serializationType: serializationType,
    compressionType: compressionType,
    reservedData: value,
  );

  /// Serializes the header into the 4-byte binary layout required by the
  /// BytePlus SAUC protocol.
  Uint8List toBytes() {
    return Uint8List.fromList([
      (ProtocolVersion.v1 << 4) | 0x01,
      (messageType << 4) | messageTypeSpecificFlags,
      (serializationType << 4) | compressionType,
      ...reservedData,
    ]);
  }

  static AsrRequestHeader defaultHeader() => const AsrRequestHeader();
}
