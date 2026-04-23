import 'package:cloudinary_public/cloudinary_public.dart';

class CloudinaryService {
  static final cloudinaryTimetable=CloudinaryPublic(
      'dbou8qtak',
      'file_uploder',
      cache: false
  );
  static final cloudinaryMark=CloudinaryPublic(
      'dbou8qtak',
      'mark_uploader',
      cache: false
  );
  static final studentProfile=CloudinaryPublic(
      'dbou8qtak',
      'student_image',
      cache: false
  );  static final teacherProfile=CloudinaryPublic(
      'dbou8qtak',
      'teacher_image',
      cache: false
  );
}
