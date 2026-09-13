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
    String uploaderName = '',
    String uploaderId = '',
    bool isCameraInstant = false,
  }) async {

    /// 1️⃣ Upload to Cloudinary with multi-fallback to handle image & raw doc presets safely
    CloudinaryResponse? cloudinaryResponse;
    Object? lastError;

    // Detect if image based on file extension
    final lowerName = fileName.toLowerCase();
    final isImage = lowerName.endsWith('.jpg') ||
        lowerName.endsWith('.jpeg') ||
        lowerName.endsWith('.png') ||
        lowerName.endsWith('.webp') ||
        lowerName.endsWith('.gif');

    final resourceTypes = isImage
        ? [CloudinaryResourceType.Image, CloudinaryResourceType.Auto, CloudinaryResourceType.Raw]
        : [CloudinaryResourceType.Auto, CloudinaryResourceType.Raw, CloudinaryResourceType.Image];

    final clients = [
      CloudinaryService.cloudinaryTimetable,
      CloudinaryService.studentProfile,
      CloudinaryService.teacherProfile,
    ];

    for (final client in clients) {
      for (final rType in resourceTypes) {
        try {
          final safeIdentifier = "${DateTime.now().millisecondsSinceEpoch}_${fileName.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')}";
          cloudinaryResponse = await client.uploadFile(
            CloudinaryFile.fromBytesData(
              fileBytes,
              identifier: safeIdentifier,
              folder: "otherFile",
              resourceType: rType,
            ),
          );
          if (cloudinaryResponse.secureUrl.isNotEmpty) {
            break;
          }
        } catch (err) {
          lastError = err;
        }
      }
      if (cloudinaryResponse != null && cloudinaryResponse.secureUrl.isNotEmpty) {
        break;
      }
    }

    if (cloudinaryResponse == null) {
      throw Exception("Upload failed: ${lastError?.toString() ?? 'Cloudinary error'}");
    }

    final fileUrl = cloudinaryResponse.secureUrl;
    final idVal = DateTime.now().millisecondsSinceEpoch.toString();

    /// 2️⃣ Create Model instance
    final model = OtherFilesModel(
      id: idVal,
      fileName: fileName,
      fileUrl: fileUrl,
      tittle: title,
      subtitle: subtitle == "OTHER FILE" ? "Notes" : subtitle,
      uploaderName: uploaderName,
      uploaderId: uploaderId,
      uploadedAt: DateTime.now(),
      isCameraInstant: isCameraInstant,
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