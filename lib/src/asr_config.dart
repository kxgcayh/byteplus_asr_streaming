import 'protocol_constants.dart';

/// Immutable configuration for a [BytePlusAsrClient] and the audio recorder
/// it feeds. Holds credentials, the WebSocket endpoint, audio parameters,
/// and the request-payload knobs that were previously hardcoded inside
/// `RequestBuilder.newFullClientRequest`.
class AsrConfig {
  const AsrConfig({
    required this.apiKey,
    required this.wsUrl,
    this.resourceId = 'volc.seedasr.sauc.duration',
    this.sampleRate = kDefaultSampleRate,
    this.bitsPerSample = 16,
    this.numChannels = 1,
    this.audioFormat = 'pcm',
    this.audioCodec = 'raw',
    this.language = 'id-ID',
    this.userUid = 'demo_uid',
    this.modelName = 'bigmodel',
    this.enableItn = true,
    this.enablePunc = true,
    this.enableAutoLang = false,
    this.resultType = 'full',
    this.endWindowMs = 800,
    this.segmentDurationMs = 200,
  });

  /// Sensible defaults — same endpoint the demo app was using. Pass your
  /// own [apiKey]; everything else can stay default.
  factory AsrConfig.defaults({
    required String apiKey,
    String path = 'bigmodel_nostream',
  }) {
    return AsrConfig(
      apiKey: apiKey,
      wsUrl: 'wss://voice.ap-southeast-1.bytepluses.com/api/v3/sauc/$path',
    );
  }

  final String apiKey;
  final String wsUrl;
  final String resourceId;

  final int sampleRate;
  final int bitsPerSample;
  final int numChannels;
  final String audioFormat;
  final String audioCodec;

  final String language;
  final String userUid;
  final String modelName;
  final bool enableItn;
  final bool enablePunc;
  final bool enableAutoLang;
  final String resultType;
  final int endWindowMs;

  final int segmentDurationMs;
}
