# Voice Input Feature Setup Guide

This app now supports voice input for translation using OpenAI's Whisper model running **on-device** for maximum privacy and offline capability.

## Architecture

The voice input feature is built using Test-Driven Development (TDD) with the following components:

### Services
- **`VoiceInputService`** (`lib/services/voice_input_service.dart`): Main service coordinating audio recording and transcription
- **`VoiceRecorder`** interface: Abstraction for audio recording
- **`FlutterAudioRecorder`**: Implementation using the `record` package
- **`WhisperClient`** interface: Abstraction for Whisper transcription
- **`OnDeviceWhisperClient`**: Implementation for on-device inference using FFI and whisper.cpp

### Tests
- Unit tests in `test/services/voice_input_service_test.dart` covering:
  - Audio recording start/stop
  - Transcription from audio files
  - Permission handling
  - Error scenarios
  - Resource cleanup

## Dependencies

The following packages have been added to `pubspec.yaml`:

```yaml
dependencies:
  permission_handler: ^11.0.1   # Handle microphone permissions
  path_provider: ^2.1.1         # Access directories for audio files and models
  record: ^5.0.4                # Audio recording
  path: ^1.8.3                  # Path manipulation
  ffi: ^2.1.0                   # FFI for native Whisper integration
```

## On-Device Whisper Setup

The voice input feature uses **on-device inference** with whisper.cpp for complete privacy. No audio data is sent to any cloud service.

### Step 1: Compile whisper.cpp as a Native Library

#### Windows

1. **Install MSVC Build Tools** (if not already installed):
   - Download from https://visualstudio.microsoft.com/downloads/
   - Install "Desktop development with C++"

2. **Clone and build whisper.cpp**:
   ```powershell
   git clone https://github.com/ggerganov/whisper.cpp.git
   cd whisper.cpp
   
   # Build as shared library
   mkdir build
   cd build
   cmake .. -DBUILD_SHARED_LIBS=ON
   cmake --build . --config Release
   ```

3. **Copy the library to your Flutter project**:
   ```powershell
   # Create directory structure
   New-Item -ItemType Directory -Force -Path "..\..\..\xai_translate\windows\whisper"
   
   # Copy DLL
   Copy-Item ".\bin\Release\whisper.dll" "..\..\..\xai_translate\windows\whisper\"
   ```

#### macOS

1. **Install Xcode Command Line Tools**:
   ```bash
   xcode-select --install
   ```

2. **Clone and build whisper.cpp**:
   ```bash
   git clone https://github.com/ggerganov/whisper.cpp.git
   cd whisper.cpp
   
   # Build as shared library
   mkdir build && cd build
   cmake .. -DBUILD_SHARED_LIBS=ON
   cmake --build . --config Release
   ```

3. **Copy to Flutter project**:
   ```bash
   mkdir -p ../xai_translate/macos/whisper
   cp libwhisper.dylib ../xai_translate/macos/whisper/
   ```

#### Linux

1. **Install build dependencies**:
   ```bash
   sudo apt-get update
   sudo apt-get install build-essential cmake
   ```

2. **Clone and build whisper.cpp**:
   ```bash
   git clone https://github.com/ggerganov/whisper.cpp.git
   cd whisper.cpp
   
   mkdir build && cd build
   cmake .. -DBUILD_SHARED_LIBS=ON
   cmake --build . --config Release
   ```

3. **Copy to Flutter project**:
   ```bash
   mkdir -p ../xai_translate/linux/whisper
   cp libwhisper.so ../xai_translate/linux/whisper/
   ```

#### Android

1. **Install Android NDK** (via Android Studio or command line)

2. **Build for Android**:
   ```bash
   cd whisper.cpp
   mkdir build-android && cd build-android
   
   cmake .. \
     -DCMAKE_TOOLCHAIN_FILE=$ANDROID_NDK/build/cmake/android.toolchain.cmake \
     -DANDROID_ABI=arm64-v8a \
     -DANDROID_PLATFORM=android-21 \
     -DBUILD_SHARED_LIBS=ON
   
   cmake --build . --config Release
   ```

3. **Copy to Flutter project**:
   ```bash
   mkdir -p ../xai_translate/android/app/src/main/jniLibs/arm64-v8a
   cp libwhisper.so ../xai_translate/android/app/src/main/jniLibs/arm64-v8a/
   ```

#### iOS

1. **Build for iOS**:
   ```bash
   cd whisper.cpp
   
   # Build framework
   xcodebuild -target whisper -configuration Release \
     -arch arm64 \
     BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
     SKIP_INSTALL=NO
   ```

2. **Copy to Flutter project**:
   ```bash
   mkdir -p ../xai_translate/ios/whisper
   cp -R build/Release/whisper.framework ../xai_translate/ios/whisper/
   ```

### Step 2: Download Whisper Model

Download a Whisper model file (GGML format) from HuggingFace:

```bash
# Download base.en model (~140 MB, good balance of speed/accuracy)
curl -L https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.en.bin \
  -o ggml-base.en.bin

# Or download tiny.en model (~75 MB, faster but less accurate)
curl -L https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-tiny.en.bin \
  -o ggml-tiny.en.bin

# Or download small.en model (~465 MB, more accurate but slower)
curl -L https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-small.en.bin \
  -o ggml-small.en.bin
```

### Step 3: Add Model to App Documents

The app looks for the model in the app's documents directory:

**On first run**, place the model at:
- **Windows**: `%LOCALAPPDATA%\xai_translate\xai_translate\Documents\whisper\ggml-base.en.bin`
- **macOS**: `~/Library/Application Support/xai_translate/whisper/ggml-base.en.bin`
- **Linux**: `~/.local/share/xai_translate/whisper/ggml-base.en.bin`
- **Android**: Internal storage (automatically placed by the app)
- **iOS**: App documents directory (automatically placed by the app)

Alternatively, bundle the model with your app as an asset (see below).

### Step 4: Implement FFI Bindings

The `OnDeviceWhisperClient` class includes comments showing where to add FFI calls. Here's a complete example:

```dart
// In lib/services/voice_input_service.dart

import 'dart:ffi' as ffi;
import 'package:ffi/ffi.dart';

class OnDeviceWhisperClient implements WhisperClient {
  late ffi.DynamicLibrary _whisperLib;
  ffi.Pointer? _ctx;
  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Load native library (platform-specific)
      if (Platform.isWindows) {
        _whisperLib = ffi.DynamicLibrary.open('whisper/whisper.dll');
      } else if (Platform.isMacOS) {
        _whisperLib = ffi.DynamicLibrary.open('whisper/libwhisper.dylib');
      } else if (Platform.isLinux) {
        _whisperLib = ffi.DynamicLibrary.open('whisper/libwhisper.so');
      } else if (Platform.isAndroid) {
        _whisperLib = ffi.DynamicLibrary.open('libwhisper.so');
      } else if (Platform.isIOS) {
        _whisperLib = ffi.DynamicLibrary.process();
      }

      // Load model
      final modelPath = await _getModelPath();
      final initFunc = _whisperLib.lookupFunction<
          ffi.Pointer Function(ffi.Pointer<Utf8>),
          ffi.Pointer Function(ffi.Pointer<Utf8>)>('whisper_init_from_file');
      
      _ctx = initFunc(modelPath.toNativeUtf8());
      _isInitialized = true;
    } catch (e) {
      print('Failed to initialize Whisper: $e');
      _isInitialized = false;
    }
  }

  @override
  Future<String> transcribe(String audioPath) async {
    if (!_isInitialized) await initialize();
    
    // Call whisper_full() via FFI
    // Extract transcription text
    // Return result
  }
}
```

### Alternative: Bundle Model as Asset

Instead of downloading separately, you can bundle the model with your app:

1. **Add model to assets** in `pubspec.yaml`:
   ```yaml
   flutter:
     assets:
       - assets/models/ggml-base.en.bin
   ```

2. **Copy asset to documents on first run**:
   ```dart
   Future<void> _ensureModelExists() async {
     final appDir = await getApplicationDocumentsDirectory();
     final modelPath = path.join(appDir.path, 'whisper', 'ggml-base.en.bin');
     final modelFile = File(modelPath);
     
     if (!await modelFile.exists()) {
       final data = await rootBundle.load('assets/models/ggml-base.en.bin');
       await modelFile.create(recursive: true);
       await modelFile.writeAsBytes(data.buffer.asUint8List());
     }
   }
   ```

## Platform Configuration

### Android

Add microphone permission to `android/app/src/main/AndroidManifest.xml`:

```xml
<manifest>
    <uses-permission android:name="android.permission.RECORD_AUDIO" />
    <uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
    <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
    
    <application>
        ...
    </application>
</manifest>
```

### iOS

Add microphone usage description to `ios/Runner/Info.plist`:

```xml
<key>NSMicrophoneUsageDescription</key>
<string>This app needs access to your microphone for voice input translation.</string>
```

### Windows/Linux/macOS

The `record` package handles permissions automatically on desktop platforms.

## Usage

1. **Ensure Whisper model is available** (see setup instructions above)

2. **Run the Flutter app**:
   ```bash
   flutter run
   ```

3. **Use voice input**:
   - Tap the microphone button (blue) at the bottom-right of the source text field
   - Speak clearly into your microphone
   - Tap the stop button (red) when done
   - The app will transcribe your speech and automatically translate it

## Testing

Run the voice input service tests:

```bash
# Run all voice input tests
flutter test test/services/voice_input_service_test.dart

# Run specific test group
flutter test test/services/voice_input_service_test.dart --name "Recording"
```

Currently, 9/19 tests pass. The failing tests require:
- Mock file system for audio file existence checks
- TestWidgetsFlutterBinding for permission handler tests

## Architecture Decisions

### Why On-Device Whisper?

- **Complete Privacy**: Audio never leaves the device
- **Offline Capable**: Works without internet connection
- **No API Costs**: No ongoing transcription fees
- **Low Latency**: Direct inference without network round-trips
- **Data Security**: Sensitive conversations remain private

### Performance Considerations

Model size vs. accuracy trade-offs:
- **tiny.en** (~75 MB): ~32x realtime on modern devices, good for quick transcriptions
- **base.en** (~140 MB): ~16x realtime, best balance of speed and accuracy (recommended)
- **small.en** (~465 MB): ~6x realtime, high accuracy for critical applications
- **medium.en** (~1.5 GB): ~2x realtime, near-perfect transcription
- **large** (~3 GB): ~1x realtime, best possible accuracy

### Dependency Injection

The service uses constructor injection for testing:
```dart
VoiceInputService({
  WhisperClient? whisperClient,
  VoiceRecorder? audioRecorder,
})
```

This allows easy mocking in unit tests while using real implementations in production.

### Error Handling

- Permission denied: Clear error message shown to user
- Server unavailable: Graceful fallback with helpful message
- Recording failures: Automatic cleanup of resources
- File system errors: Non-critical cleanup errors are logged but not thrown

## Future Enhancements

- [ ] Add language detection from transcribed audio
- [ ] Support multiple Whisper models (tiny, small, medium, large)
- [ ] Add audio visualization during recording
- [ ] Implement audio preprocessing (noise reduction)
- [ ] Cache Whisper model for faster startup
- [ ] Add voice activity detection (VAD) for automatic stop
- [ ] Support streaming transcription for long audio
- [ ] Add speaker diarization for multi-speaker audio

## Troubleshooting

### "Whisper model not available"
- Ensure the model file exists in the app's documents directory
- Check the model file name matches exactly: `ggml-base.en.bin`
- Verify the model file isn't corrupted (check file size)
- Look at app logs for the expected path

### "On-device transcription failed"
- Ensure whisper.cpp is compiled and the library is present
- Check that FFI bindings are properly implemented
- Verify the model format matches whisper.cpp version
- For testing, use the Whisper server approach instead

### "Microphone permission denied"
- Grant microphone permission in system settings
- On Android: Settings > Apps > AI Translate > Permissions
- On iOS: Settings > AI Translate > Microphone

### Library loading errors
- **Windows**: Ensure whisper.dll is in `windows/whisper/` directory
- **macOS**: Check code signing on libwhisper.dylib
- **Linux**: Verify libwhisper.so has execute permissions
- **Android**: Confirm library is in correct ABI folder

### Model not found
- Check model file location in logs
- On mobile, model must be copied to documents on first run
- Consider bundling model as asset for easier deployment

### Poor transcription quality
- Try a larger model (small.en or medium.en)
- Ensure audio quality is good (16kHz, mono)
- Check for background noise in recordings
- Verify recording permissions are granted

### Performance issues
- Use smaller model (tiny.en) for faster transcription
- Consider quantized models for mobile devices
- Optimize audio preprocessing
- Test on physical devices, not just emulators

## Contributing

When adding voice input features:

1. Write tests first (TDD approach)
2. Ensure all existing tests pass
3. Add integration tests for new UI features
4. Update this documentation
5. Test on multiple platforms

## License

Same as the main project.
