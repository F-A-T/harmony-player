import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';

class LoggerService {
  static final LoggerService _instance = LoggerService._internal();
  factory LoggerService() => _instance;
  LoggerService._internal();

  File? _logFile;

  Future<void> init() async {
    final dir = await getApplicationDocumentsDirectory();
    _logFile = File('${dir.path}/harmony_app_logs.txt');
    if (!await _logFile!.exists()) {
      await _logFile!.create();
    }
  }

  Future<void> log(String message, {String type = "INFO"}) async {
    if (_logFile == null) await init();
    final timestamp = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
    final logLine = '[$timestamp] [$type] $message\n';
    try {
      await _logFile!.writeAsString(logLine, mode: FileMode.append);
      print(logLine); // Konsola da yazdır (Debug için)
    } catch (e) {
      print("Log yazılamadı: $e");
    }
  }

  Future<String> readLogs() async {
    if (_logFile == null) await init();
    try {
      if (await _logFile!.exists()) {
        final content = await _logFile!.readAsString();
        return content.isEmpty ? "Log dosyası boş." : content;
      }
    } catch (e) {
      return "Loglar okunamadı: $e";
    }
    return "Log dosyası bulunamadı.";
  }

  Future<void> clearLogs() async {
    if (_logFile == null) await init();
    try {
      if (await _logFile!.exists()) {
        await _logFile!.writeAsString("");
      }
    } catch (e) {
      print("Loglar temizlenemedi: $e");
    }
  }
}
