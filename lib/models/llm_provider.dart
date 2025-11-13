enum LLMProvider {
  grok,
  openai,
  gemini,
}

extension LLMProviderExtension on LLMProvider {
  String get name {
    switch (this) {
      case LLMProvider.grok:
        return 'Grok';
      case LLMProvider.openai:
        return 'OpenAI';
      case LLMProvider.gemini:
        return 'Gemini';
    }
  }

  String get apiEndpoint {
    switch (this) {
      case LLMProvider.grok:
        return 'https://api.x.ai/v1/chat/completions';
      case LLMProvider.openai:
        return 'https://api.openai.com/v1/chat/completions';
      case LLMProvider.gemini:
        return 'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash-exp:generateContent';
    }
  }

  String get model {
    switch (this) {
      case LLMProvider.grok:
        return 'grok-2-vision-1212';
      case LLMProvider.openai:
        return 'gpt-4o';
      case LLMProvider.gemini:
        return 'gemini-2.0-flash-exp';
    }
  }
  
  bool get supportsVision {
    // All current models support vision
    return true;
  }

  static LLMProvider fromString(String value) {
    switch (value.toLowerCase()) {
      case 'grok':
        return LLMProvider.grok;
      case 'openai':
        return LLMProvider.openai;
      case 'gemini':
        return LLMProvider.gemini;
      default:
        return LLMProvider.grok;
    }
  }
}
