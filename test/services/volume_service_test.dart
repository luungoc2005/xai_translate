import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xai_translate/services/volume_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late VolumeService volumeService;
  late MethodChannel channel;
  double? mockVolume;

  setUp(() {
    volumeService = VolumeService();
    channel = const MethodChannel('com.yosemiteyss.flutter_volume_controller/method');
    mockVolume = 0.5;

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      if (methodCall.method == 'getVolume') {
        return mockVolume.toString();
      } else if (methodCall.method == 'setVolume') {
        // The arguments might be a map or just the value depending on implementation
        // Checking the package source code or trial and error is needed.
        // Based on common practices, it's likely a map with 'volume' key or just the double.
        // Let's assume it's the double for now based on usage setVolume(0.5).
        // Actually, looking at the package, setVolume takes a double.
        // But over method channel it might be wrapped.
        // Let's print arguments if test fails.
        if (methodCall.arguments is double) {
           mockVolume = methodCall.arguments as double;
        } else if (methodCall.arguments is Map) {
           mockVolume = (methodCall.arguments as Map)['volume'] as double?;
        }
        return null;
      }
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  group('VolumeService', () {
    test('ensureVolumeIsAudible increases volume when low', () async {
      mockVolume = 0.05; // 5% volume
      
      final result = await volumeService.ensureVolumeIsAudible();
      
      expect(result, isTrue);
      expect(mockVolume, 0.5); // Should be set to default target 50%
    });

    test('ensureVolumeIsAudible does nothing when volume is sufficient', () async {
      mockVolume = 0.3; // 30% volume
      
      final result = await volumeService.ensureVolumeIsAudible();
      
      expect(result, isFalse);
      expect(mockVolume, 0.3); // Should remain unchanged
    });

    test('restoreVolume restores original volume', () async {
      mockVolume = 0.05;
      
      // First change it
      await volumeService.ensureVolumeIsAudible();
      expect(mockVolume, 0.5);
      
      // Then restore it
      await volumeService.restoreVolume();
      expect(mockVolume, 0.05);
    });

    test('restoreVolume does nothing if volume was not changed', () async {
      mockVolume = 0.3;
      
      await volumeService.ensureVolumeIsAudible(); // Won't change
      await volumeService.restoreVolume();
      
      expect(mockVolume, 0.3);
    });
  });
}
