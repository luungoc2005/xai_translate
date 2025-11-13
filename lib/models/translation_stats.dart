import 'llm_provider.dart';

class TranslationStats {
  final LLMProvider provider;
  final String sourceLanguage;
  final int wordCount;
  final int imageCount;
  final int responseTimeMs;
  final bool regionalPreferenceEnabled;
  final DateTime timestamp;

  TranslationStats({
    required this.provider,
    required this.sourceLanguage,
    required this.wordCount,
    this.imageCount = 0,
    required this.responseTimeMs,
    required this.regionalPreferenceEnabled,
    required this.timestamp,
  });

  double get timePerWord => wordCount > 0 ? responseTimeMs / wordCount : 0;
  double get timePerImage => imageCount > 0 ? responseTimeMs / imageCount : 0;
  bool get hasImage => imageCount > 0;

  Map<String, dynamic> toJson() {
    return {
      'provider': provider.toString().split('.').last,
      'sourceLanguage': sourceLanguage,
      'wordCount': wordCount,
      'imageCount': imageCount,
      'responseTimeMs': responseTimeMs,
      'regionalPreferenceEnabled': regionalPreferenceEnabled,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory TranslationStats.fromJson(Map<String, dynamic> json) {
    return TranslationStats(
      provider: LLMProviderExtension.fromString(json['provider']),
      sourceLanguage: json['sourceLanguage'],
      wordCount: json['wordCount'],
      imageCount: json['imageCount'] ?? 0,
      responseTimeMs: json['responseTimeMs'],
      regionalPreferenceEnabled: json['regionalPreferenceEnabled'],
      timestamp: DateTime.parse(json['timestamp']),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TranslationStats &&
          runtimeType == other.runtimeType &&
          provider == other.provider &&
          sourceLanguage == other.sourceLanguage &&
          wordCount == other.wordCount &&
          imageCount == other.imageCount &&
          responseTimeMs == other.responseTimeMs &&
          regionalPreferenceEnabled == other.regionalPreferenceEnabled &&
          timestamp == other.timestamp;

  @override
  int get hashCode =>
      provider.hashCode ^
      sourceLanguage.hashCode ^
      wordCount.hashCode ^
      imageCount.hashCode ^
      responseTimeMs.hashCode ^
      regionalPreferenceEnabled.hashCode ^
      timestamp.hashCode;
}
