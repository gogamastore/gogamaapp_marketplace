import 'dart:developer' as developer;
import 'package:cloud_functions/cloud_functions.dart';

/// Hasil dari pembuatan transaksi Midtrans
class MidtransTransactionResult {
  final String token;
  final String redirectUrl;

  MidtransTransactionResult({
    required this.token,
    required this.redirectUrl,
  });
}

/// Service untuk komunikasi dengan Cloud Functions Midtrans
class PaymentService {
  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(
    region: 'asia-southeast1',
  );

  /// Buat transaksi Midtrans Snap untuk order tertentu.
  /// Mengembalikan [MidtransTransactionResult] berisi token & redirect URL.
  Future<MidtransTransactionResult> createTransaction(String orderId) async {
    try {
      final callable = _functions.httpsCallable('createMidtransTransaction');
      final result = await callable.call({'orderId': orderId});

      final data = result.data as Map<String, dynamic>;
      return MidtransTransactionResult(
        token: data['token'] as String,
        redirectUrl: data['redirectUrl'] as String,
      );
    } on FirebaseFunctionsException catch (e) {
      developer.log(
        'Gagal membuat transaksi Midtrans',
        name: 'PaymentService',
        error: '${e.code}: ${e.message}',
      );
      throw PaymentException(
        code: e.code,
        message: _mapErrorMessage(e.code, e.message),
      );
    } catch (e, s) {
      developer.log('PaymentService error', name: 'PaymentService', error: e, stackTrace: s);
      throw PaymentException(
        code: 'unknown',
        message: 'Terjadi kesalahan saat memproses pembayaran.',
      );
    }
  }

  String _mapErrorMessage(String code, String? message) {
    switch (code) {
      case 'unauthenticated':
        return 'Silakan login terlebih dahulu.';
      case 'not-found':
        return 'Order tidak ditemukan.';
      case 'already-exists':
        return 'Order ini sudah dibayar.';
      case 'permission-denied':
        return 'Akses ditolak.';
      default:
        return message ?? 'Gagal memproses pembayaran.';
    }
  }
}

/// Exception khusus untuk error pembayaran
class PaymentException implements Exception {
  final String code;
  final String message;

  PaymentException({required this.code, required this.message});

  @override
  String toString() => 'PaymentException($code): $message';
}
