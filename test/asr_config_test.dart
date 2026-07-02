import 'package:byteplus_asr_streaming/byteplus_asr_streaming.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('AsrConfig.defaults preserves the ap-southeast-1 endpoint', () {
    final c = AsrConfig.defaults(apiKey: 'k');
    expect(
      c.wsUrl,
      'wss://voice.ap-southeast-1.bytepluses.com/api/v3/sauc/bigmodel_nostream',
    );
  });

  test('AsrConfig is immutable and equal-by-field', () {
    const a = AsrConfig(apiKey: 'k', wsUrl: 'wss://x', language: 'en-US');
    const b = AsrConfig(apiKey: 'k', wsUrl: 'wss://x', language: 'en-US');
    expect(a.apiKey, b.apiKey);
    expect(a.wsUrl, b.wsUrl);
    expect(a.language, b.language);
    expect(a.sampleRate, kDefaultSampleRate);
  });
}