# AI Translate

A Google Translate-like Flutter application that uses LLM providers (Grok, OpenAI, Gemini) for translation. Built using Test-Driven Development (TDD).

## Features

- 🌍 Multi-language translation support (12+ languages)
- 🤖 Multiple LLM provider support:
  - **Grok** (xAI) - Default provider
  - **OpenAI** (GPT-4)
  - **Gemini** (Google)
- 🔄 Language swap functionality
- ⚙️ Settings page for API key configuration
- 📱 Clean, Material Design 3 UI
- ✅ Comprehensive test coverage

## Architecture

The app follows TDD principles and clean architecture:

```
lib/
├── models/
│   └── llm_provider.dart      # LLM provider enum and extensions
├── services/
│   ├── translation_service.dart  # Translation logic
│   └── settings_service.dart     # Settings management
├── screens/
│   ├── translation_screen.dart   # Main translation UI
│   └── settings_screen.dart      # Settings configuration UI
└── main.dart                   # App entry point

test/
├── services/
│   ├── translation_service_test.dart
│   └── settings_service_test.dart
└── screens/
    ├── translation_screen_test.dart
    └── settings_screen_test.dart
```

## Getting Started

### Prerequisites

- Flutter SDK (3.10.0 or higher)
- Dart SDK (3.10.0 or higher)
- API keys from at least one provider:
  - [Grok API Key](https://x.ai) (xAI)
  - [OpenAI API Key](https://platform.openai.com)
  - [Gemini API Key](https://aistudio.google.com)

### Installation

1. Clone the repository
2. Install dependencies:
   ```bash
   flutter pub get
   ```

3. Run tests:
   ```bash
   flutter test
   ```

4. Run the app:
   ```bash
   flutter run
   ```

## Usage

### First-Time Setup

1. Launch the app
2. Tap the settings icon (⚙️) in the top-right corner
3. Select your preferred LLM provider (Grok is default)
4. Enter your API key(s) for the provider(s) you want to use
5. Tap "Save Settings"

### Translating Text

1. Select source and target languages from the dropdowns
2. Enter text in the top text field
3. Tap "Translate"
4. View the translation in the bottom text field
5. Use the swap button (⇄) to swap source and target languages

## Testing

The project follows TDD with comprehensive test coverage:

```bash
# Run all tests
flutter test

# Generate mock files (if needed)
dart run build_runner build
```

Test coverage includes:
- ✅ Translation service unit tests
- ✅ Settings service unit tests
- ✅ Translation screen widget tests
- ✅ Settings screen widget tests

## API Configuration

### Grok (xAI)
- Endpoint: `https://api.x.ai/v1/chat/completions`
- Model: `grok-beta`

### OpenAI
- Endpoint: `https://api.openai.com/v1/chat/completions`
- Model: `gpt-4o-mini`

### Gemini
- Endpoint: `https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent`
- Model: `gemini-pro`

## Dependencies

```yaml
dependencies:
  flutter: sdk
  http: ^1.2.0
  shared_preferences: ^2.2.2
  cupertino_icons: ^1.0.8

dev_dependencies:
  flutter_test: sdk
  mockito: ^5.4.4
  build_runner: ^2.4.8
  flutter_lints: ^6.0.0
```

## Supported Languages

- English
- Spanish
- French
- German
- Italian
- Portuguese
- Russian
- Japanese
- Chinese
- Korean
- Arabic
- Hindi

## Development

### TDD Workflow

This project was built using Test-Driven Development:

1. Write failing tests first
2. Implement minimum code to pass tests
3. Refactor while keeping tests green
4. Repeat

### Adding New Features

1. Write tests in the appropriate `test/` directory
2. Implement the feature to make tests pass
3. Update documentation

## License

This project is open source and available under the MIT License.

## Contributing

Contributions are welcome! Please ensure:
- All tests pass
- New features include tests
- Code follows Flutter best practices

## Troubleshooting

### API Key Issues
- Ensure your API key is valid and has sufficient credits
- Check that you've selected the correct provider in settings
- Verify the API key is saved properly

### Translation Errors
- Check your internet connection
- Ensure the API service is not experiencing downtime
- Try a different LLM provider

### Build Issues
```bash
# Clean and rebuild
flutter clean
flutter pub get
dart run build_runner build --delete-conflicting-outputs
```

