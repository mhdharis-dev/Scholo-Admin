import 'dart:typed_data';
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
    required Uint8List fileBytes,
    required String fileName,
    required String division,
    required int classNo,
  }) async {

    /// 1️⃣ Upload to Cloudinary
    final cloudinaryResponse =
    await CloudinaryService.cloudinaryTimetable.uploadFile(
      CloudinaryFile.fromBytesData(
        fileBytes,
        identifier: fileName,
        folder: "otherFile",
        resourceType: CloudinaryResourceType.Raw, // Supports PDFs, Docs, etc.
      ),
    );

    final fileUrl = cloudinaryResponse.secureUrl;
    final idVal = DateTime.now().millisecondsSinceEpoch.toString();

    /// 2️⃣ Create Model instance
    final model = OtherFilesModel(
      id: idVal,
      fileName: fileName,
      fileUrl: fileUrl,
      tittle: title,
      subtitle: subtitle == "OTHER FILE" ? "Notes" : subtitle,
      uploadedAt: DateTime.now(),
      delete: false,
      teacherId: teacherId,
      deletedDate: null,
      classNo: classNo,
      division: division,
    );

    /// 3️⃣ Save to Firestore (Nested Schema only)
    final nestedDoc = _firestore
        .schoolCollection(FirebaseConstant.notes)
        .doc(classNo.toString());

    await nestedDoc.set({
      division: {
        title: model.toMap(),
      }
    }, SetOptions(merge: true));
  }
}

/// Provider renamed to match the new Repository name
final otherFilesRepositoryProvider = Provider<OtherFilesRepository>((ref) {
  return OtherFilesRepository();
});