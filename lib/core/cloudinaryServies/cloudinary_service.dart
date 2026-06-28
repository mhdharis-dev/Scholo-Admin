import 'package:cloudinary_public/cloudinary_public.dart';

class CloudinaryService {
  static final cloudinaryTimetable=CloudinaryPublic(
      'dxqqnfxvj',
      'file_uploder',
      cache: false
  );
  static final cloudinaryMark=CloudinaryPublic(
      'dxqqnfxvj',
      'mark_uploader',
      cache: false
  );
  static final studentProfile=CloudinaryPublic(
      'dxqqnfxvj',
      'student_image',
      cache: false
  );  static final teacherProfile=CloudinaryPublic(
      'dxqqnfxvj',
      'teacher_image',
      cache: false
  );
}
