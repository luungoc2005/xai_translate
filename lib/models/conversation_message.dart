/// Represents a single message in a conversation
class ConversationMessage {
  final String text;
  final String language;
  final DateTime timestamp;
  final bool isUserInput;
  final String? translatedText;
  final String? targetLanguage;

  ConversationMessage({
    required this.text,
    required this.language,
    required this.timestamp,
    required this.isUserInput,
    this.translatedText,
    this.targetLanguage,
  });

  Map<String, dynamic> toJson() {
    return {
      'text': text,
      'language': language,
      'timestamp': timestamp.toIso8601String(),
      'isUserInput': isUserInput,
      'translatedText': translatedText,
      'targetLanguage': targetLanguage,
    };
  }

  factory ConversationMessage.fromJson(Map<String, dynamic> json) {
    return ConversationMessage(
      text: json['text'] as String,
      language: json['language'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      isUserInput: json['isUserInput'] as bool,
      translatedText: json['translatedText'] as String?,
      targetLanguage: json['targetLanguage'] as String?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ConversationMessage &&
          runtimeType == other.runtimeType &&
          text == other.text &&
          language == other.language &&
          timestamp == other.timestamp &&
          isUserInput == other.isUserInput &&
          translatedText == other.translatedText &&
          targetLanguage == other.targetLanguage;

  @override
  int get hashCode =>
      text.hashCode ^
      language.hashCode ^
      timestamp.hashCode ^
      isUserInput.hashCode ^
      (translatedText?.hashCode ?? 0) ^
      (targetLanguage?.hashCode ?? 0);
}
