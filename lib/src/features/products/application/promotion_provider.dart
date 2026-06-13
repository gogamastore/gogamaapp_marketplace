import 'dart:async';
import 'dart:developer' as developer; // Impor untuk logging
import 'package:flutter/material.dart';

import '../../../core/data/firestore_service.dart';
import '../domain/promotion.dart';

/// A provider that manages the state of active promotions throughout the app.
class PromotionProvider with ChangeNotifier {
  final FirestoreService _firestoreService;
  StreamSubscription? _promoSubscription;

  Map<String, Promotion> _promotions = {};
  bool _isLoading = true;

  PromotionProvider(this._firestoreService) {
    _listenToPromotions();
  }

  bool get isLoading => _isLoading;
  Map<String, Promotion> get promotions => _promotions;

  Promotion? getPromotionForProduct(String productId) {
    return _promotions[productId];
  }

  void _listenToPromotions() {
    _isLoading = true;
    notifyListeners();

    _promoSubscription = _firestoreService.getPromoProductsStream().listen((promoProducts) {
      final newPromos = <String, Promotion>{};
      
      // --- PERANGKAP DEBUG SEMENTARA ---
      for (final promoProduct in promoProducts) {
        // Cek jika ada nilai NaN di data promosi
        final promo = promoProduct.promotion;
        if (promo.discountPrice.isNaN) {
          developer.log(
            '[DATA RUSAK TERDETEKSI] Ditemukan nilai NaN pada data promosi.',
            name: 'Data.PromoNaNError',
            // --- PERBAIKAN: Mengganti toJson() dengan detail manual ---
            error: 'ID Produk: ${promoProduct.product.id}, Nama Produk: ${promoProduct.product.name}, Data Promo: {id: ${promo.id}, discountPrice: ${promo.discountPrice}}',
          );
        }
        newPromos[promoProduct.product.id] = promo;
      }
      // --- AKHIR DARI PERANGKAP DEBUG ---

      _promotions = newPromos;
      _isLoading = false;
      notifyListeners();
    }, onError: (error, stackTrace) {
      developer.log(
        'Error saat mendengarkan promosi',
        name: 'PromotionProvider',
        error: error,
        stackTrace: stackTrace,
      );
      _isLoading = false;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _promoSubscription?.cancel();
    super.dispose();
  }
}
