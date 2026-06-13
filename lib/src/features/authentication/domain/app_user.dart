import 'package:cloud_firestore/cloud_firestore.dart';

class AppUser {
  final String uid;
  final String name;
  final String email;
  final String photoURL;
  final String role;
  final String whatsapp;

  AppUser({
    required this.uid,
    required this.name,
    required this.email,
    required this.photoURL,
    required this.role,
    required this.whatsapp,
  });

  // Factory constructor to create an AppUser from a Firestore document.
  factory AppUser.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>? ?? {};
    return AppUser(
      uid: doc.id,
      name: data['name'] ?? 'Nama Tidak Ditemukan',
      email: data['email'] ?? 'Email Tidak Ditemukan',
      photoURL: data['photoURL'] ?? '',
      role: data['role'] ?? 'user',
      whatsapp: data['whatsapp'] ?? 'Nomor Tidak Ditemukan',
    );
  }
}
