/// Parsed response frame from the BytePlus ASR Streaming server.
class AsrResponse {
  int code = 0;
  int event = 0;
  bool isLastPackage = false;
  int payloadSequence = 0;
  int payloadSize = 0;
  Map<String, dynamic>? payloadMsg;
}