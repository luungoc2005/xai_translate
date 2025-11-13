class TranslationHistoryItem {
  final String sourceText;
  final String translatedText;
  final String sourceLanguage;
  final String targetLanguage;
  final DateTime timestamp;

  TranslationHistoryItem({
    required this.sourceText,
    required this.translatedText,
    required this.sourceLanguage,
    required this.targetLanguage,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() {
    return {
      'sourceText': sourceText,
      'translatedText': translatedText,
      'sourceLanguage': sourceLanguage,
      'targetLanguage': targetLanguage,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory TranslationHistoryItem.fromJson(Map<String, dynamic> json) {
    return TranslationHistoryItem(
      sourceText: json['sourceText'] as String,
      translatedText: json['translatedText'] as String,
      sourceLanguage: json['sourceLanguage'] as String,
      targetLanguage: json['targetLanguage'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TranslationHistoryItem &&
          runtimeType == other.runtimeType &&
          sourceText == other.sourceText &&
          translatedText == other.translatedText &&
          sourceLanguage == other.sourceLanguage &&
          targetLanguage == other.targetLanguage &&
          timestamp == other.timestamp;

  @override
  int get hashCode =>
      sourceText.hashCode ^
      translatedText.hashCode ^
      sourceLanguage.hashCode ^
      targetLanguage.hashCode ^
      timestamp.hashCode;
}
