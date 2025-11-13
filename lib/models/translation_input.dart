import 'dart:io';

class TranslationInput {
  final String? text;
  final File? image;

  TranslationInput({
    this.text,
    this.image,
  });

  bool get hasText => text != null && text!.isNotEmpty;
  bool get hasImage => image != null;
  bool get isEmpty => !hasText && !hasImage;

  @override
  String toString() {
    if (hasText && hasImage) {
      return 'Text + Image';
    } else if (hasText) {
      return text!;
    } else if (hasImage) {
      return 'Image: ${image!.path}';
    }
    return 'Empty';
  }
}
