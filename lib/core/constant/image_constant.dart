import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

class ImageConstant {
  static const String temporaryStudentImage = 'assets/image/temp_student_images.png';
  static const String temporaryFemaleStudentImage = 'assets/image/temp_girl_student_image.png';
  static const String temporaryTeacherImage = 'assets/image/temp_teacher_image.png';
  static const String logo = 'assets/imagesJpg/Scholo_Logo.jpg';
  static const String logoWithText = 'assets/imagesJpg/scholo_LogoWithName.jpg';
  static const String editIcon = 'assets/imageSvg/edit_icon.svg';
  static const String completed = 'assets/imageSvg/completed.svg';
  static const String folderImage = 'assets/image/folder_image.png';

  /// Helper to get the correct student ImageProvider based on gender & uploaded image
  static ImageProvider getStudentImageProvider({
    String? gender,
    String? imageUrl,
    File? selectedFile,
    Uint8List? selectedFileBytes,
  }) {
    if (selectedFileBytes != null && selectedFileBytes.isNotEmpty) {
      return MemoryImage(selectedFileBytes);
    }
    if (selectedFile != null && !kIsWeb) {
      return FileImage(selectedFile);
    }
    if (imageUrl != null && imageUrl.trim().isNotEmpty) {
      return NetworkImage(imageUrl.trim());
    }
    if (gender != null && gender.trim().toLowerCase() == 'female') {
      return const AssetImage(temporaryFemaleStudentImage);
    }
    return const AssetImage(temporaryStudentImage);
  }
}
