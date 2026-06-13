import 'package:flutter/material.dart';
import 'package:myapp/src/core/data/firestore_service.dart';
import 'package:myapp/src/features/products/domain/promotion.dart';
import 'package:myapp/src/features/products/presentation/widgets/promo_product_card.dart';
import 'dart:developer' as developer;
import 'package:cloud_firestore/cloud_firestore.dart';

class PromoSection extends StatelessWidget {
  const PromoSection({super.key});

  @override
  Widget build(BuildContext context) {
    final firestoreService = FirestoreService();

    return StreamBuilder<List<PromoProduct>>(
      stream: firestoreService.getPromoProductsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          final error = snapshot.error;
          String errorMessage = 'Error memuat produk promo: $error';

          if (error is FirebaseException &&
              error.code == 'failed-precondition') {
            // Log the detailed message which contains the index creation link
            developer.log(
              'KUERI FIRESTORE MEMERLUKAN INDEKS. Salin dan buka link di bawah ini di browser untuk membuatnya:\n${error.message}',
              name: 'FirestoreIndexError',
            );
            errorMessage =
                'Error: Kueri memerlukan indeks. Cek log debug untuk link pembuatan indeks.';
          } else {
            developer.log('Terjadi error saat memuat produk promo',
                name: 'PromoSectionError', error: error);
          }

          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(errorMessage, textAlign: TextAlign.center),
            ),
          );
        }

        final promoProducts = snapshot.data;

        if (promoProducts == null || promoProducts.isEmpty) {
          return const SizedBox
              .shrink(); // Hide the section if there are no promo products
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
              child: Text(
                'Flash Sale',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            GridView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              shrinkWrap: true,
              physics:
                  const NeverScrollableScrollPhysics(), // Disable scrolling within the grid
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8.0,
                mainAxisSpacing: 8.0,
                childAspectRatio:
                    0.5, // Adjust this ratio to fit your card design
              ),
              itemCount: promoProducts.length,
              itemBuilder: (context, index) {
                return PromoProductCard(promoProduct: promoProducts[index]);
              },
            ),
          ],
        );
      },
    );
  }
}
