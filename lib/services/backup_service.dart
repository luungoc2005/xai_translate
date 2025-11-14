import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BackupService {
  static const String _backupVersion = '1.0';

  /// Exports all app data to a JSON file
  Future<Map<String, dynamic>> exportAllData() async {
    final prefs = await SharedPreferences.getInstance();
    final allKeys = prefs.getKeys();
    
    final dataMap = <String, dynamic>{};
    
    // Export all shared preferences data
    for (String key in allKeys) {
      final value = prefs.get(key);
      if (value != null) {
        dataMap[key] = value;
      }
    }

    Map<String, dynamic> backupData = {
      'version': _backupVersion,
      'exportDate': DateTime.now().toIso8601String(),
      'data': dataMap,
    };

    return backupData;
  }

  /// Imports data from a backup JSON object
  Future<bool> importData(Map<String, dynamic> backupData) async {
    try {
      // Validate backup structure
      if (!backupData.containsKey('version') || !backupData.containsKey('data')) {
        throw Exception('Invalid backup format');
      }

      final prefs = await SharedPreferences.getInstance();
      final data = backupData['data'] as Map<String, dynamic>;

      // Clear existing data
      await prefs.clear();

      // Import all data
      for (var entry in data.entries) {
        final key = entry.key;
        final value = entry.value;

        if (value is String) {
          await prefs.setString(key, value);
        } else if (value is int) {
          await prefs.setInt(key, value);
        } else if (value is double) {
          await prefs.setDouble(key, value);
        } else if (value is bool) {
          await prefs.setBool(key, value);
        } else if (value is List) {
          await prefs.setStringList(key, value.cast<String>());
        }
      }

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Exports data and saves to a file, then shares it
  Future<bool> exportToFile() async {
    try {
      final backupData = await exportAllData();
      final jsonString = const JsonEncoder.withIndent('  ').convert(backupData);
      
      // Get temporary directory
      final directory = await getTemporaryDirectory();
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.')[0];
      final fileName = 'xai_translate_backup_$timestamp.json';
      final file = File('${directory.path}/$fileName');
      
      // Write data to file
      await file.writeAsString(jsonString);
      
      // Share the file
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'AI Translate Backup',
        text: 'AI Translate app data backup from ${DateTime.now().toString()}',
      );
      
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Picks a backup file and imports it
  Future<ImportResult> importFromFile() async {
    try {
      // Pick a file
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result == null || result.files.isEmpty) {
        return ImportResult(success: false, message: 'No file selected');
      }

      final file = File(result.files.single.path!);
      
      // Read file content
      final jsonString = await file.readAsString();
      final backupData = jsonDecode(jsonString) as Map<String, dynamic>;
      
      // Import data
      final success = await importData(backupData);
      
      if (success) {
        return ImportResult(
          success: true,
          message: 'Data imported successfully',
          importDate: backupData['exportDate'] as String?,
        );
      } else {
        return ImportResult(
          success: false,
          message: 'Failed to import data',
        );
      }
    } catch (e) {
      return ImportResult(
        success: false,
        message: 'Error: ${e.toString()}',
      );
    }
  }

  /// Gets a summary of what will be exported
  Future<ExportSummary> getExportSummary() async {
    final backupData = await exportAllData();
    final data = backupData['data'] as Map<String, dynamic>;
    
    int settingsCount = 0;
    int conversationMessagesCount = 0;
    int historyCount = 0;
    int statsCount = 0;
    int apiKeysCount = 0;

    for (var key in data.keys) {
      if (key.startsWith('api_key_')) {
        apiKeysCount++;
      } else if (key == 'conversation_messages') {
        try {
          final messages = jsonDecode(data[key] as String) as List;
          conversationMessagesCount = messages.length;
        } catch (e) {
          // Ignore parsing errors
        }
      } else if (key == 'translation_history') {
        try {
          final history = jsonDecode(data[key] as String) as List;
          historyCount = history.length;
        } catch (e) {
          // Ignore parsing errors
        }
      } else if (key == 'translation_stats') {
        try {
          final stats = jsonDecode(data[key] as String) as List;
          statsCount = stats.length;
        } catch (e) {
          // Ignore parsing errors
        }
      } else {
        settingsCount++;
      }
    }

    return ExportSummary(
      settingsCount: settingsCount,
      apiKeysCount: apiKeysCount,
      conversationMessagesCount: conversationMessagesCount,
      historyCount: historyCount,
      statsCount: statsCount,
    );
  }
}

class ImportResult {
  final bool success;
  final String message;
  final String? importDate;

  ImportResult({
    required this.success,
    required this.message,
    this.importDate,
  });
}

class ExportSummary {
  final int settingsCount;
  final int apiKeysCount;
  final int conversationMessagesCount;
  final int historyCount;
  final int statsCount;

  ExportSummary({
    required this.settingsCount,
    required this.apiKeysCount,
    required this.conversationMessagesCount,
    required this.historyCount,
    required this.statsCount,
  });

  int get totalItems =>
      settingsCount +
      apiKeysCount +
      conversationMessagesCount +
      historyCount +
      statsCount;
}
