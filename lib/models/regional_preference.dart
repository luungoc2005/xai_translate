enum RegionalPreference {
  none,
  singapore,
}

extension RegionalPreferenceExtension on RegionalPreference {
  String get name {
    switch (this) {
      case RegionalPreference.none:
        return 'None';
      case RegionalPreference.singapore:
        return 'Singapore';
    }
  }

  String get currency {
    switch (this) {
      case RegionalPreference.none:
        return '';
      case RegionalPreference.singapore:
        return 'SGD';
    }
  }

  String get unitSystem {
    switch (this) {
      case RegionalPreference.none:
        return '';
      case RegionalPreference.singapore:
        return 'metric';
    }
  }

  static RegionalPreference fromString(String value) {
    switch (value.toLowerCase()) {
      case 'singapore':
        return RegionalPreference.singapore;
      case 'none':
      default:
        return RegionalPreference.none;
    }
  }
}
