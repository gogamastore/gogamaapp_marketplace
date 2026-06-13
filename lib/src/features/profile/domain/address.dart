import 'package:cloud_firestore/cloud_firestore.dart';

class Address {
  final String id;
  final String label;
  final String name;
  final String phone;
  final String address;
  final String city;
  final String postalCode;
  final String province;
  final bool isDefault;
  final double latitude;
  final double longitude;

  Address({
    required this.id,
    this.label = '',
    required this.name,
    required this.phone,
    required this.address,
    required this.city,
    required this.postalCode,
    required this.province,
    required this.isDefault,
    this.latitude = 0.0,
    this.longitude = 0.0,
  });

  factory Address.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Address(
      id: doc.id,
      label: data['label'] ?? '',
      name: data['name'] ?? '',
      phone: data['phone'] ?? '',
      address: data['address'] ?? '',
      city: data['city'] ?? '',
      postalCode: data['postalCode'] ?? data['postal_code'] ?? '',
      province: data['province'] ?? '',
      isDefault: data['isDefault'] ?? false,
      latitude: (data['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (data['longitude'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'label': label,
      'name': name,
      'phone': phone,
      'address': address,
      'city': city,
      'postalCode': postalCode,
      'province': province,
      'isDefault': isDefault,
      'latitude': latitude,
      'longitude': longitude,
      'created_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
    };
  }

  // Add a copyWith method for easier state management
  Address copyWith({
    String? id,
    String? label,
    String? name,
    String? phone,
    String? address,
    String? city,
    String? postalCode,
    String? province,
    bool? isDefault,
    double? latitude,
    double? longitude,
  }) {
    return Address(
      id: id ?? this.id,
      label: label ?? this.label,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      city: city ?? this.city,
      postalCode: postalCode ?? this.postalCode,
      province: province ?? this.province,
      isDefault: isDefault ?? this.isDefault,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
    );
  }
}