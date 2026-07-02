# 0.1.0

- Initial extraction from `lib/asr_streaming_example.dart`.
- Replaced global `Logger` with an injected `AsrLog` callback.
- Replaced module-level `Config` singleton with an immutable `AsrConfig`.
- Made `AsrRequestHeader` immutable; each `with*` returns a new instance.
  This fixes a latent bug where `RequestBuilder.newAudioOnlyRequest` was
  discarding the mutated message-type flag.