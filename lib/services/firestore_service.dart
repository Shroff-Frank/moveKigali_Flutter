// lib/services/firestore_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../user_state.dart';
import '../models/booking.dart';

class FirestoreService {
  static final _db = FirebaseFirestore.instance;

  // ═══════════════════════════════════════════════════════════════════════════
  // USER PROFILE
  // ═══════════════════════════════════════════════════════════════════════════

  // Save or update full user profile
  static Future<void> saveUserData(UserData data) async {
    await _db.collection('users').doc(data.uid).set(
      {
        'uid':          data.uid,
        'name':         data.name,
        'email':        data.email,
        'phone':        data.phone,
        'nickName':     data.nickName,
        'profileImage': data.profileImage,
        'buspoints':    data.buspoints,
        'fcmToken':     data.fcmToken,
        'updatedAt':    FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  // Get user profile from Firestore
  static Future<UserData?> getUserData(String uid) async {
    try {
      final doc = await _db.collection('users').doc(uid).get();
      if (!doc.exists || doc.data() == null) return null;
      final d = doc.data()!;
      return UserData(
        uid:          uid,
        name:         d['name']         ?? '',
        email:        d['email']        ?? '',
        phone:        d['phone']        ?? '',
        nickName:     d['nickName']     ?? '',
        profileImage: d['profileImage'] ?? '',
        buspoints:    (d['buspoints']   ?? 0) as int,
        fcmToken:     d['fcmToken']     ?? '',
      );
    } catch (e) {
      return null;
    }
  }

  // Save FCM token
  static Future<void> saveFcmToken(String uid, String token) async {
    await _db.collection('users').doc(uid).set(
      {'fcmToken': token, 'updatedAt': FieldValue.serverTimestamp()},
      SetOptions(merge: true),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // BOOKINGS
  // ═══════════════════════════════════════════════════════════════════════════

  // Save a new booking → returns the Firestore document ID
  static Future<String> createBooking(Booking booking) async {
    // 1. Save booking document
    final ref = await _db.collection('bookings').add(booking.toMap());

    // 2. Increment user's buspoints by 1
    await _db.collection('users').doc(booking.uid).set(
      {'buspoints': FieldValue.increment(1)},
      SetOptions(merge: true),
    );

    return ref.id;
  }

  // Get all bookings for a user — ordered by newest first
  static Future<List<Booking>> getBookingsForUser(String uid) async {
    try {
      final snapshot = await _db
          .collection('bookings')
          .where('uid', isEqualTo: uid)
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs.map((doc) => Booking.fromDoc(doc)).toList();
    } catch (e) {
      // If the ordered query fails because of an older createdAt format,
      // fallback to an unordered query and sort locally by timestamp.
      try {
        final snapshot = await _db
            .collection('bookings')
            .where('uid', isEqualTo: uid)
            .get();
        final bookings = snapshot.docs.map((doc) => Booking.fromDoc(doc)).toList();
        bookings.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return bookings;
      } catch (_) {
        return [];
      }
    }
  }

  // Delete a booking by document ID
  static Future<void> deleteBooking(String bookingId) async {
    await _db.collection('bookings').doc(bookingId).delete();
  }

  // Get user's current buspoints from Firestore
  static Future<int> getBuspoints(String uid) async {
    try {
      final doc = await _db.collection('users').doc(uid).get();
      if (!doc.exists) return 0;
      return (doc.data()?['buspoints'] ?? 0) as int;
    } catch (_) {
      return 0;
    }
  }
}