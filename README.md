# AI Translate

A Google Translate-like Flutter application that uses LLM providers (Grok, OpenAI, Gemini) for translation. Built using Test-Driven Development (TDD).

## Features

- 🌍 Multi-language translation support (12+ languages)
- 🔍 **Auto-detect source language** - Automatically identifies the input language
- 📜 **Translation history** - Automatically saves all translations with timestamp
- 📊 **Performance statistics** - Track latency metrics per provider with advanced filtering
  - Time to respond per word count
  - Filter by provider, source language, and regional preferences
  - Provider comparison analytics
  - Persistent across app restarts
- 🌏 **Regional preferences** - Add translator notes (T/N) for currency, units, and cultural context
  - Singapore preference: Converts to SGD, metric units, and adds contextual hints
- 🤖 Multiple LLM provider support:
  - **Grok** (xAI) - Default provider
  - **OpenAI** (GPT-5)
  - **Gemini** (Google)
- 🔄 Language swap functionality
- ⚙️ Settings page for API key configuration
- 📱 Clean, Material Design 3 UI
- ✅ Comprehensive test coverage (67 tests)

## Architecture

The app follows TDD principles and clean architecture:

```
lib/
├── models/
│   ├── llm_provider.dart           # LLM provider enum and extensions
│   ├── regional_preference.dart    # Regional preference enum for T/N
│   ├── translation_history_item.dart # Translation history data model
│   └── translation_stats.dart      # Statistics data model
├── services/
│   ├── translation_service.dart     # Translation logic with T/N support & timing
│   ├── settings_service.dart        # Settings management
│   ├── history_service.dart         # Translation history management
│   └── stats_service.dart           # Statistics tracking & analytics
├── screens/
│   ├── translation_screen.dart      # Main translation UI
│   ├── settings_screen.dart         # Settings configuration UI
│   ├── history_screen.dart          # Translation history UI
│   └── stats_screen.dart            # Performance statistics UI
└── main.dart                        # App entry point

test/
├── services/
│   ├── translation_service_test.dart
│   ├── settings_service_test.dart
│   ├── history_service_test.dart
│   └── stats_service_test.dart
└── screens/
    ├── translation_screen_test.dart
    ├── settings_screen_test.dart
    ├── history_screen_test.dart
    └── stats_screen_test.dart
```

## Getting Started

### Prerequisites

- Flutter SDK (3.10.0 or higher)
- Dart SDK (3.10.0 or higher)
- **Windows Users**: Enable Developer Mode (see [WINDOWS_SETUP.md](WINDOWS_SETUP.md))
- API keys from at least one provider:
  - [Grok API Key](https://x.ai) (xAI)
  - [OpenAI API Key](https://platform.openai.com)
  - [Gemini API Key](https://aistudio.google.com)

### Windows Setup (Important!)

If you're on Windows, you **must** enable Developer Mode before running the app:

1. Open Settings: `start ms-settings:developers`
2. Enable **Developer Mode**
3. Restart your terminal

Without this, you'll get: `MissingPluginException: No implementation found for method getAll`

See [WINDOWS_SETUP.md](WINDOWS_SETUP.md) for detailed instructions.

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
4. (Optional) Select regional preference for translator notes:
   - **None**: Standard translation without annotations
   - **Singapore**: Adds T/N for currency (SGD), metric units, and cultural context
5. Enter your API key(s) for the provider(s) you want to use
6. Tap "Save Settings"

### Translating Text

1. **Select source language**: Choose a specific language or use **"Auto-detect"** (default) to let the LLM identify the language automatically
2. **Select target language**: Choose the language you want to translate to
3. **Enter text**: Type or paste text in the top text field
4. **Tap "Translate"**: Wait for the translation to appear
5. **View result**: The translation appears in the bottom text field
6. **Swap languages** (optional): Use the swap button (⇄) to swap source and target languages

### Using Auto-detect

The **Auto-detect** feature uses the LLM to automatically identify the source language:
- Default source language option
- Works with all three LLM providers (Grok, OpenAI, Gemini)
- Automatically detects any of the 12 supported languages
- No manual language selection needed for input text

### Viewing Translation History

1. **Access history**: Tap the history icon (🕐) in the top-right corner
2. **View translations**: See all past translations with timestamps
3. **Delete entry**: Swipe left on any translation to delete it
4. **Clear all**: Tap "Clear All" to remove all history (confirmation required)
5. **Automatic saving**: All translations are automatically saved (max 100 items)
6. **Newest first**: History is sorted with newest translations at the top

### Using Regional Preferences & Translator Notes

Regional preferences add helpful **translator notes (T/N)** to translations:

**When set to Singapore:**
- **Currency conversions**: "100 USD" becomes "100 USD (T/N: ~SGD 135)"
- **Unit conversions**: "5 miles" becomes "5 miles (T/N: ~8 km)"
- **Temperature**: "75°F" becomes "75°F (T/N: ~24°C)"
- **Cultural context**: Adds relevant contextual hints for better understanding

**Example Translation:**
- Original: "The house is 2000 sq ft and costs $500,000"
- With Singapore T/N: "La casa tiene 2000 pies cuadrados (T/N: ~186 m²) y cuesta $500,000 (T/N: ~SGD 670,000)"

Configure this in **Settings → Regional Preferences**.

### Viewing Performance Statistics

1. **Access statistics**: Tap the bar chart icon (📊) in the top-right corner
2. **View metrics**: See performance data including:
   - Total translations count
   - Total words translated
   - Average response time (ms)
   - **Average time per word** (ms/word) - Key performance metric
3. **Filter data**:
   - **By Provider**: Compare Grok, OpenAI, and Gemini performance
   - **By Source Language**: See how different languages affect speed
   - **By Regional Preferences**: Compare performance with/without T/N
4. **Provider Comparison**: When "All Providers" is selected, see side-by-side comparison
5. **Clear statistics**: Tap the delete icon to clear all stats (with confirmation)
6. **Persistent data**: Statistics are saved automatically and persist across app restarts (max 1000 entries)

**Use Cases:**
- Compare which provider is fastest for your typical translations
- Identify if regional preferences significantly impact response time
- Track performance trends over time
- Optimize your provider choice based on actual usage data

## Testing

The project follows TDD with comprehensive test coverage:

```bash
# Run all tests
flutter test

# Generate mock files (if needed)
dart run build_runner build
```

Test coverage includes:
- ✅ Translation service unit tests (10 tests)
- ✅ Settings service unit tests (10 tests)
- ✅ History service unit tests (7 tests)
- ✅ Stats service unit tests (10 tests)
- ✅ Translation screen widget tests (10 tests)
- ✅ Settings screen widget tests (4 tests)
- ✅ History screen widget tests (4 tests)
- ✅ Stats screen widget tests (6 tests)
- ✅ Plugin initialization tests (4 tests)
- ✅ Auto-detect language tests (2 tests)

**Total: 67 tests passing ✅**

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

### Windows: "No implementation found for method getAll"
**This is the most common issue on Windows!**

- **Cause**: Developer Mode is not enabled
- **Solution**: Enable Developer Mode in Windows Settings
- **Details**: See [WINDOWS_SETUP.md](WINDOWS_SETUP.md)

Quick fix:
```powershell
# Open Developer Settings
start ms-settings:developers

# Then enable Developer Mode, restart terminal, and run:
flutter clean
flutter pub get
flutter run
```

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

