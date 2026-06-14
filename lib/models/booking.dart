import 'package:cloud_firestore/cloud_firestore.dart';

class Booking {
  final String id;
  final String uid;
  final String from;
  final String to;
  final String date;
  final String time;
  final int passengers;
  final int price;
  final String passengerName;
  final String phoneNumber;
  final String paymentMethod;
  final String busNumber;
  final String routeType;
  final String transactionId;
  final DateTime createdAt;

  const Booking({
    required this.id,
    required this.uid,
    required this.from,
    required this.to,
    required this.date,
    required this.time,
    required this.passengers,
    required this.price,
    required this.passengerName,
    required this.phoneNumber,
    required this.paymentMethod,
    required this.busNumber,
    required this.routeType,
    required this.transactionId,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'from': from,
      'to': to,
      'date': date,
      'time': time,
      'passengers': passengers,
      'price': price,
      'passengerName': passengerName,
      'phoneNumber': phoneNumber,
      'paymentMethod': paymentMethod,
      'busNumber': busNumber,
      'routeType': routeType,
      'transactionId': transactionId,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory Booking.fromMap(String id, Map<String, dynamic> map) {
    DateTime createdAt = DateTime.now();
    final createdRaw = map['createdAt'];
    if (createdRaw is Timestamp) {
      createdAt = createdRaw.toDate();
    } else if (createdRaw is int) {
      createdAt = DateTime.fromMillisecondsSinceEpoch(createdRaw);
    } else if (createdRaw is String) {
      createdAt = DateTime.tryParse(createdRaw) ?? DateTime.now();
    }
    return Booking(
      id: id,
      uid: map['uid'] ?? '',
      from: map['from'] ?? '',
      to: map['to'] ?? '',
      date: map['date'] ?? '',
      time: map['time'] ?? '',
      passengers: map['passengers'] is int ? map['passengers'] as int : int.tryParse(map['passengers']?.toString() ?? '0') ?? 0,
      price: map['price'] is int ? map['price'] as int : int.tryParse(map['price']?.toString() ?? '0') ?? 0,
      passengerName: map['passengerName'] ?? '',
      phoneNumber: map['phoneNumber'] ?? '',
      paymentMethod: map['paymentMethod'] ?? '',
      busNumber: map['busNumber'] ?? '',
      routeType: map['routeType'] ?? '',
      transactionId: map['transactionId'] ?? '',
      createdAt: createdAt,
    );
  }

  factory Booking.fromDoc(DocumentSnapshot doc) {
  final d = doc.data() as Map<String, dynamic>;
  return Booking.fromMap(doc.id, d);
}
}
