import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constant/firebase_constant.dart';
import '../../../../core/cloudinaryServies/cloudinary_service.dart';
import '../../../../models/otherFiles_model.dart';

class OtherFilesRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> uploadFile({
    required String teacherId,
    required String title,
    required String subtitle,
    required String filePath,
    required String fileName,
    required String division,
    required int classNo,
  }) async {

    /// 1️⃣ Upload to Cloudinary
    // Note: You might want to rename 'cloudinaryTimetable' to 'cloudinaryOtherFiles' in your CloudinaryService as well
    final cloudinaryResponse =
    await CloudinaryService.cloudinaryTimetable.uploadFile(
      CloudinaryFile.fromFile(
        filePath,
        folder: "otherFile",
        resourceType: CloudinaryResourceType.Raw, // Supports PDFs, Docs, etc.
      ),
    );

    final fileUrl = cloudinaryResponse.secureUrl;

    /// 2️⃣ Create Firestore Document Reference
    final doc = _firestore
        .collection(FirebaseConstant.otherFile)
        .doc();

    /// 3️⃣ Create Model instance
    final model = OtherFilesModel(
      id: doc.id,
      fileName: fileName,
      fileUrl: fileUrl,
      tittle: title,
      subtitle: subtitle,
      uploadedAt: DateTime.now(),
      delete: false,
      teacherId: teacherId,
      deletedDate: null,
      classNo: classNo,
      division: division,
    );

    /// 4️⃣ Save to Firestore
    await doc.set(model.toMap());
  }
}

/// Provider renamed to match the new Repository name
final otherFilesRepositoryProvider = Provider<OtherFilesRepository>((ref) {
  return OtherFilesRepository();
});