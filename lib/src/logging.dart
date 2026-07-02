import 'dart:developer' as developer;

/// Severity levels for [AsrLog] callbacks.
enum AsrLogLevel { debug, info, warn, error }

/// Lightweight logging contract so consumers can plug in their own logger
/// (or stay silent) without forcing a transitive dependency on
/// `package:logger`.
typedef AsrLog = void Function(
  String message, {
  AsrLogLevel level,
  Object? error,
  StackTrace? stackTrace,
});

/// Built-in [AsrLog] implementations for convenience.
class AsrLoggers {
  AsrLoggers._();

  /// Logs via `dart:developer.log` with a `byteplus_asr_streaming` name.
  /// Useful in tests or for ad-hoc debugging. Does not depend on
  /// `package:logger`.
  static AsrLog developerLogger() {
    return (message,
        {level = AsrLogLevel.info, error, stackTrace}) {
      developer.log(
        message,
        name: 'byteplus_asr_streaming.${level.name}',
        error: error,
        stackTrace: stackTrace,
        level: _levelInt(level),
      );
    };
  }

  /// Discards every message. Useful in production when you want to silence
  /// the package entirely.
  static AsrLog silent() {
    return (message, {level = AsrLogLevel.info, error, stackTrace}) {};
  }

  static int _levelInt(AsrLogLevel level) {
    switch (level) {
      case AsrLogLevel.debug:
        return 500;
      case AsrLogLevel.info:
        return 800;
      case AsrLogLevel.warn:
        return 900;
      case AsrLogLevel.error:
        return 1000;
    }
  }
}