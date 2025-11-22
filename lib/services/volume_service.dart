import 'package:flutter/foundation.dart';
import 'package:flutter_volume_controller/flutter_volume_controller.dart';

class VolumeService {
  double? _originalVolume;

  /// Checks current volume and increases it if it's too low (below 10%).
  /// Returns true if volume was adjusted.
  Future<bool> ensureVolumeIsAudible({double targetVolume = 0.5, double threshold = 0.1}) async {
    try {
      final currentVolume = await FlutterVolumeController.getVolume();
      if (currentVolume != null && currentVolume < threshold) {
        _originalVolume = currentVolume;
        await FlutterVolumeController.setVolume(targetVolume);
        return true;
      }
    } catch (e) {
      debugPrint('Error adjusting volume: $e');
    }
    return false;
  }

  /// Restores the volume to its original level if it was changed.
  Future<void> restoreVolume() async {
    if (_originalVolume != null) {
      try {
        await FlutterVolumeController.setVolume(_originalVolume!);
        _originalVolume = null;
      } catch (e) {
        debugPrint('Error restoring volume: $e');
      }
    }
  }
}
