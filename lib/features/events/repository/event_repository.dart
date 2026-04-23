import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:scholo_admin/core/constant/firebase_constant.dart';

import '../../../models/event_model.dart';

class EventRepository {
  final FirebaseFirestore _firestore;

  EventRepository(this._firestore);

  CollectionReference get _events =>
      _firestore.collection(FirebaseConstant.events);

  /// Realtime events stream (only non-deleted)
  Stream<List<EventModel>> getEventsStream() {
    return _events
        .where('delete', isEqualTo: false)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
          .map(
            (doc) =>
            EventModel.fromMap(doc.data() as Map<String, dynamic>),
      )
          .toList(),
    );
  }

  /// Add / update event (handles title change too if oldTitle passed)
  Future<void> saveEvent(EventModel event, {String? oldTitle}) async {
    // If title changed, delete old doc
    if (oldTitle != null && oldTitle.isNotEmpty && oldTitle != event.title) {
      await _events.doc(oldTitle).delete();
    }

    await _events.doc(event.title).set(event.toMap());
  }

  /// Soft delete (sets delete: true)
  Future<void> deleteEvent(String title) async {
    await _events.doc(title).update({'delete': true, "deletedAt": FieldValue.serverTimestamp(),});
  }
}
