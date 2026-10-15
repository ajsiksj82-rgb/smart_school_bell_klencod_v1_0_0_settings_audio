import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Stores an imported bell sound inside the app's private documents directory.
class BellAudioService {
  BellAudioService._();
  static final BellAudioService instance = BellAudioService._();

  final AudioPlayer _player = AudioPlayer();
  static const _soundPathKey = 'custom_bell_sound_path';
  String? _soundPath;

  String? get soundPath => _soundPath;
  bool get hasCustomSound => _soundPath != null && File(_soundPath!).existsSync();
  String get soundName => hasCustomSound ? _soundPath!.split(Platform.pathSeparator).last : 'صوت النظام الافتراضي';

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final path = prefs.getString(_soundPathKey);
    if (path != null && await File(path).exists()) {
      _soundPath = path;
    } else {
      _soundPath = null;
      await prefs.remove(_soundPathKey);
    }
  }

  Future<String?> importSound() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['mp3', 'wav', 'm4a', 'aac', 'ogg', 'flac'],
      allowMultiple: false,
      withData: false,
    );
    if (result == null || result.files.isEmpty) return null;
    final picked = result.files.single;
    final sourcePath = picked.path;
    if (sourcePath == null || sourcePath.isEmpty) {
      throw Exception('تعذر الوصول إلى ملف الصوت المختار. حاول اختيار ملف آخر.');
    }
    final ext = picked.extension?.toLowerCase() ?? 'mp3';
    final directory = await getApplicationDocumentsDirectory();
    final target = File('${directory.path}/custom_school_bell.$ext');
    await File(sourcePath).copy(target.path);
    _soundPath = target.path;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_soundPathKey, target.path);
    return target.path;
  }

  Future<void> play({bool loop = false}) async {
    if (hasCustomSound) {
      await _player.stop();
      await _player.setReleaseMode(loop ? ReleaseMode.loop : ReleaseMode.stop);
      await _player.play(DeviceFileSource(_soundPath!));
      return;
    }
    throw StateError('لم يتم اختيار ملف صوت للجرس. افتح الإعدادات لاستيراد صوت.');
  }

  Future<void> stop() => _player.stop();

  Future<void> clearCustomSound() async {
    await _player.stop();
    final old = _soundPath;
    _soundPath = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_soundPathKey);
    if (old != null) {
      try { await File(old).delete(); } catch (_) { /* ignore cleanup errors */ }
    }
  }

  Future<void> dispose() => _player.dispose();
}
