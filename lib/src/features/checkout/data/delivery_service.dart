import 'dart:developer' as developer;
import 'package:cloud_functions/cloud_functions.dart';

// ─────────────────────────────────────────────
// Model: koordinat + alamat
// ─────────────────────────────────────────────
class DeliveryLocation {
  final double latitude;
  final double longitude;
  final String address;
  final String contactName;
  final String contactPhone;

  const DeliveryLocation({
    required this.latitude,
    required this.longitude,
    required this.address,
    required this.contactName,
    required this.contactPhone,
  });

  Map<String, dynamic> toMap() => {
        'latitude': latitude,
        'longitude': longitude,
        'address': address,
        'contactName': contactName,
        'contactPhone': contactPhone,
      };
}

// ─────────────────────────────────────────────
// Model: pilihan tarif pengiriman
// ─────────────────────────────────────────────
class ShippingRate {
  final String provider; // "gosend" | "grab"
  final String serviceType;
  final String serviceName;
  final double price;
  final String currency;
  final String estimatedDelivery;
  final bool available;
  final String? errorMessage;

  const ShippingRate({
    required this.provider,
    required this.serviceType,
    required this.serviceName,
    required this.price,
    required this.currency,
    required this.estimatedDelivery,
    required this.available,
    this.errorMessage,
  });

  factory ShippingRate.fromMap(Map<String, dynamic> map) {
    return ShippingRate(
      provider: map['provider'] as String? ?? '',
      serviceType: map['serviceType'] as String? ?? '',
      serviceName: map['serviceName'] as String? ?? '',
      price: (map['price'] as num?)?.toDouble() ?? 0.0,
      currency: map['currency'] as String? ?? 'IDR',
      estimatedDelivery: map['estimatedDelivery'] as String? ?? '-',
      available: map['available'] as bool? ?? false,
      errorMessage: map['errorMessage'] as String?,
    );
  }

  /// Ikon provider untuk UI
  String get providerIcon => provider == 'gosend' ? '🛵 GoSend' : '🟢 GrabExpress';
}

// ─────────────────────────────────────────────
// Model: info paket yang dikirim
// ─────────────────────────────────────────────
class PackageInfo {
  final String description;
  final double weightKg;
  final double value; // nilai barang untuk asuransi

  const PackageInfo({
    required this.description,
    required this.weightKg,
    required this.value,
  });

  Map<String, dynamic> toMap() => {
        'description': description,
        'weightKg': weightKg,
        'value': value,
      };
}

// ─────────────────────────────────────────────
// Model: hasil booking driver
// ─────────────────────────────────────────────
class DeliveryBookingResult {
  final bool success;
  final String bookingId;
  final String provider;
  final String? trackingUrl;

  const DeliveryBookingResult({
    required this.success,
    required this.bookingId,
    required this.provider,
    this.trackingUrl,
  });
}

// ─────────────────────────────────────────────
// Model: status tracking
// ─────────────────────────────────────────────
class DeliveryTrackingInfo {
  final bool hasDelivery;
  final String? provider;
  final String? status;
  final String? driverName;
  final String? driverPhone;
  final String? driverPlate;
  final String? trackingUrl;

  const DeliveryTrackingInfo({
    required this.hasDelivery,
    this.provider,
    this.status,
    this.driverName,
    this.driverPhone,
    this.driverPlate,
    this.trackingUrl,
  });

  factory DeliveryTrackingInfo.fromMap(Map<String, dynamic> map) {
    return DeliveryTrackingInfo(
      hasDelivery: map['hasDelivery'] as bool? ?? false,
      provider: map['provider'] as String?,
      status: map['status'] as String?,
      driverName: map['driverName'] as String?,
      driverPhone: map['driverPhone'] as String?,
      driverPlate: map['driverPlate'] as String?,
      trackingUrl: map['trackingUrl'] as String?,
    );
  }
}

// ─────────────────────────────────────────────
// Service utama
// ─────────────────────────────────────────────
class DeliveryService {
  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(
    region: 'asia-southeast1',
  );

  /// Ambil tarif pengiriman dari GoSend dan GrabExpress secara paralel.
  Future<List<ShippingRate>> getShippingRates({
    required DeliveryLocation origin,
    required DeliveryLocation destination,
    double weightKg = 1.0,
  }) async {
    try {
      final callable = _functions.httpsCallable('getShippingRates');
      final result = await callable.call({
        'origin': origin.toMap(),
        'destination': destination.toMap(),
        'weightKg': weightKg,
      });

      final data = result.data as Map<String, dynamic>;
      final ratesList = data['rates'] as List<dynamic>? ?? [];

      return ratesList
          .map((r) => ShippingRate.fromMap(r as Map<String, dynamic>))
          .toList();
    } on FirebaseFunctionsException catch (e) {
      developer.log('getShippingRates error', name: 'DeliveryService', error: '${e.code}: ${e.message}');
      throw DeliveryException(message: e.message ?? 'Gagal mengambil tarif pengiriman.');
    }
  }

  /// Booking driver instan GoSend atau GrabExpress.
  Future<DeliveryBookingResult> bookDelivery({
    required String orderId,
    required String provider, // "gosend" | "grab"
    required String serviceType,
    required DeliveryLocation origin,
    required DeliveryLocation destination,
    required PackageInfo packageInfo,
  }) async {
    try {
      final callable = _functions.httpsCallable('bookInstantDelivery');
      final result = await callable.call({
        'orderId': orderId,
        'provider': provider,
        'serviceType': serviceType,
        'origin': origin.toMap(),
        'destination': destination.toMap(),
        'packageInfo': packageInfo.toMap(),
      });

      final data = result.data as Map<String, dynamic>;
      return DeliveryBookingResult(
        success: data['success'] as bool? ?? false,
        bookingId: data['bookingId'] as String? ?? '',
        provider: data['provider'] as String? ?? provider,
        trackingUrl: data['trackingUrl'] as String?,
      );
    } on FirebaseFunctionsException catch (e) {
      developer.log('bookDelivery error', name: 'DeliveryService', error: '${e.code}: ${e.message}');
      throw DeliveryException(message: e.message ?? 'Gagal booking driver.');
    }
  }

  /// Batalkan booking driver yang sudah aktif.
  Future<void> cancelDelivery(String orderId) async {
    try {
      final callable = _functions.httpsCallable('cancelDelivery');
      await callable.call({'orderId': orderId});
    } on FirebaseFunctionsException catch (e) {
      throw DeliveryException(message: e.message ?? 'Gagal membatalkan pengiriman.');
    }
  }

  /// Cek status tracking pengiriman.
  Future<DeliveryTrackingInfo> trackDelivery(String orderId) async {
    try {
      final callable = _functions.httpsCallable('trackDelivery');
      final result = await callable.call({'orderId': orderId});
      return DeliveryTrackingInfo.fromMap(result.data as Map<String, dynamic>);
    } on FirebaseFunctionsException catch (e) {
      developer.log('trackDelivery error', name: 'DeliveryService', error: e.message);
      return const DeliveryTrackingInfo(hasDelivery: false);
    }
  }
}

class DeliveryException implements Exception {
  final String message;
  DeliveryException({required this.message});

  @override
  String toString() => 'DeliveryException: $message';
}
