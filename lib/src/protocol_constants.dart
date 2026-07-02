/// Constants mirroring the Python SAUC enum-like classes for the BytePlus
/// ASR Streaming binary protocol.
class ProtocolVersion {
  static const int v1 = 0x01;
}

class MessageType {
  static const int clientFullRequest = 0x01;
  static const int clientAudioOnlyRequest = 0x02;
  static const int serverFullResponse = 0x09;
  static const int serverErrorResponse = 0x0f;
}

class MessageTypeSpecificFlags {
  static const int noSequence = 0x00;
  static const int posSequence = 0x01;
  static const int negSequence = 0x02;
  static const int negWithSequence = 0x03;
}

class SerializationType {
  static const int noSerialization = 0x00;
  static const int json = 0x01;
}

class CompressionType {
  static const int gzip = 0x01;
}

const int kDefaultSampleRate = 16000;