enum TTSVoice {
  alloy,
  echo,
  fable,
  onyx,
  nova,
  shimmer,
}

extension TTSVoiceExtension on TTSVoice {
  String get name {
    switch (this) {
      case TTSVoice.alloy:
        return 'Alloy';
      case TTSVoice.echo:
        return 'Echo';
      case TTSVoice.fable:
        return 'Fable';
      case TTSVoice.onyx:
        return 'Onyx';
      case TTSVoice.nova:
        return 'Nova';
      case TTSVoice.shimmer:
        return 'Shimmer';
    }
  }

  String get apiValue {
    return toString().split('.').last;
  }

  String get description {
    switch (this) {
      case TTSVoice.alloy:
        return 'Neutral, balanced voice';
      case TTSVoice.echo:
        return 'Male, warm voice';
      case TTSVoice.fable:
        return 'British, expressive voice';
      case TTSVoice.onyx:
        return 'Male, deep voice';
      case TTSVoice.nova:
        return 'Female, energetic voice';
      case TTSVoice.shimmer:
        return 'Female, soft voice';
    }
  }

  static TTSVoice fromString(String value) {
    switch (value.toLowerCase()) {
      case 'alloy':
        return TTSVoice.alloy;
      case 'echo':
        return TTSVoice.echo;
      case 'fable':
        return TTSVoice.fable;
      case 'onyx':
        return TTSVoice.onyx;
      case 'nova':
        return TTSVoice.nova;
      case 'shimmer':
        return TTSVoice.shimmer;
      default:
        return TTSVoice.alloy;
    }
  }
}
