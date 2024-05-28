import 'dart:async';
import 'package:file/local.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

/// Audio Recorder Plugin
class FlutterVoiceRecorder {
  static const MethodChannel _channel = MethodChannel('flutter_voice_recorder');
  static const String DEFAULT_EXTENSION = '.m4a';
  static LocalFileSystem fs = const LocalFileSystem();

  String? _path;
  String? _extension;
  Recording? _recording;
  int? _sampleRate;

  late Future<void> _initRecorder;
  Future<void> get initialized => _initRecorder;
  Recording? get recording => _recording;

  FlutterVoiceRecorder(String path,
      {AudioFormat? audioFormat, int sampleRate = 16000}) {
    _initRecorder = _init(path, audioFormat, sampleRate);
  }

  Future<void> _init(
      String? path, AudioFormat? audioFormat, int sampleRate) async {
    String extension;
    String extensionInPath;

    if (path != null) {
      extensionInPath = p.extension(path);
      if (audioFormat != null) {
        if (_stringToAudioFormat(extensionInPath) != audioFormat) {
          extension = _audioFormatToString(audioFormat);
          path = p.withoutExtension(path) + extension;
        } else {
          extension = extensionInPath;
        }
      } else {
        if (_isValidAudioFormat(extensionInPath)) {
          extension = extensionInPath;
        } else {
          extension = DEFAULT_EXTENSION;
          path += extension;
        }
      }

      final file = fs.file(path);
      if (await file.exists()) {
        throw Exception("A file already exists at the path: $path");
      } else if (!await file.parent.exists()) {
        throw Exception("The specified parent directory does not exist");
      }
    } else {
      extension = DEFAULT_EXTENSION;
    }

    _path = path;
    _extension = extension;
    _sampleRate = sampleRate;

    final result = await _channel.invokeMethod<Map<String, Object>>('init', {
      "path": _path,
      "extension": _extension,
      "sampleRate": _sampleRate,
    });

    _recording = Recording(
      status: _stringToRecordingStatus(result?['status'] as String?),
      metering: AudioMetering(
        averagePower: -120,
        peakPower: -120,
        isMeteringEnabled: true,
      ),
    );
  }

  Future<void> start() async {
    await _channel.invokeMethod('start');
  }

  Future<void> pause() async {
    await _channel.invokeMethod('pause');
  }

  Future<void> resume() async {
    await _channel.invokeMethod('resume');
  }

  Future<Recording?> stop() async {
    final result = await _channel.invokeMethod<Map<String, Object>>('stop');
    if (result != null) {
      _responseToRecording(result);
    }
    return _recording;
  }

  Future<Recording?> current({int channel = 0}) async {
    final result = await _channel
        .invokeMethod<Map<String, Object>>('current', {"channel": channel});
    if (result != null && _recording?.status != RecordingStatus.Stopped) {
      _responseToRecording(result);
    }
    return _recording;
  }

  static Future<bool?> get hasPermissions async {
    return await _channel.invokeMethod<bool>('hasPermissions');
  }

  void _responseToRecording(Map<String, Object>? response) {
    if (response == null) return;

    _recording = _recording?.copyWith(
      duration: Duration(milliseconds: response['duration'] as int),
      path: response['path'] as String?,
      audioFormat: _stringToAudioFormat(response['audioFormat'] as String?),
      extension: response['audioFormat'] as String?,
      metering: AudioMetering(
        peakPower: response['peakPower'] as double?,
        averagePower: response['averagePower'] as double?,
        isMeteringEnabled: response['isMeteringEnabled'] as bool?,
      ),
      status: _stringToRecordingStatus(response['status'] as String?),
    );
  }

  static bool _isValidAudioFormat(String extension) {
    return ['.wav', '.mp4', '.aac', '.m4a'].contains(extension);
  }

  static AudioFormat? _stringToAudioFormat(String? extension) {
    switch (extension) {
      case ".wav":
        return AudioFormat.WAV;
      case ".mp4":
      case ".aac":
      case ".m4a":
        return AudioFormat.AAC;
      default:
        return null;
    }
  }

  static String _audioFormatToString(AudioFormat format) {
    switch (format) {
      case AudioFormat.WAV:
        return ".wav";
      case AudioFormat.AAC:
        return ".m4a";
      default:
        return ".m4a";
    }
  }

  static RecordingStatus _stringToRecordingStatus(String? status) {
    switch (status) {
      case "unset":
        return RecordingStatus.Unset;
      case "initialized":
        return RecordingStatus.Initialized;
      case "recording":
        return RecordingStatus.Recording;
      case "paused":
        return RecordingStatus.Paused;
      case "stopped":
        return RecordingStatus.Stopped;
      default:
        return RecordingStatus.Unset;
    }
  }
}

class Recording {
  final String? path;
  final String? extension;
  final Duration? duration;
  final AudioFormat? audioFormat;
  final AudioMetering? metering;
  final RecordingStatus? status;

  Recording({
    this.path,
    this.extension,
    this.duration,
    this.audioFormat,
    this.metering,
    this.status,
  });

  Recording copyWith({
    String? path,
    String? extension,
    Duration? duration,
    AudioFormat? audioFormat,
    AudioMetering? metering,
    RecordingStatus? status,
  }) {
    return Recording(
      path: path ?? this.path,
      extension: extension ?? this.extension,
      duration: duration ?? this.duration,
      audioFormat: audioFormat ?? this.audioFormat,
      metering: metering ?? this.metering,
      status: status ?? this.status,
    );
  }
}

class AudioMetering {
  final double? peakPower;
  final double? averagePower;
  final bool? isMeteringEnabled;

  AudioMetering({
    this.peakPower,
    this.averagePower,
    this.isMeteringEnabled,
  });
}

enum RecordingStatus {
  Unset,
  Initialized,
  Recording,
  Paused,
  Stopped,
}

enum AudioFormat {
  AAC,
  WAV,
}
