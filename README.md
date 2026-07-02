# byteplus_asr_streaming

Reusable Dart/Flutter client for the BytePlus ASR Streaming (SAUC) WebSocket
protocol, plus a drop-in microphone UI page.

## Usage

```dart
import 'package:byteplus_asr_streaming/byteplus_asr_streaming.dart';

final config = AsrConfig.defaults(apiKey: 'YOUR_API_KEY');
final client = BytePlusAsrClient(config: config);

await client.createConnection();
await client.sendFullClientRequest();

final sub = client.recvMessages().listen((response) {
  final text = response.payloadMsg?['result']?['text'];
  print('partial: $text');
});

// Feed PCM audio segments:
// client.sendAudioSegment(pcmBytes);
```

Or use the built-in UI:

```dart
home: AsrStreamingPage(
  config: AsrConfig.defaults(apiKey: 'YOUR_API_KEY'),
  log: (msg, {level = AsrLogLevel.info}) {
    // forward to your own logger, or omit to silence.
  },
),
```

## Configuration

`AsrConfig.defaults(apiKey: ...)` provides a working config pointing at the
ap-southeast-1 no-stream endpoint. For a custom endpoint or audio settings,
construct `AsrConfig` directly with the parameters you need.