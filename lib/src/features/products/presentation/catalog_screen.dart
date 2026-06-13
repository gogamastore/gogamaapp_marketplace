import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/data/firestore_service.dart';
import '../domain/product.dart';
import 'widgets/product_card.dart';

class CatalogScreen extends StatefulWidget {
  const CatalogScreen({super.key});

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  late final FirestoreService _firestoreService;
  Stream<List<Product>>? _productsStream;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _firestoreService = Provider.of<FirestoreService>(context, listen: false);
    _productsStream = _firestoreService.getProductsStream();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          onChanged: (value) {
            setState(() {
              _searchQuery = value;
            });
          },
          decoration: const InputDecoration(
            hintText: 'Cari produk...',
            border: InputBorder.none,
            hintStyle: TextStyle(color: Colors.white70),
          ),
          style: const TextStyle(color: Colors.white), // Set text color to white
        ),
      ),
      body: StreamBuilder<List<Product>>(
        stream: _productsStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Gagal memuat produk. Penyebab: ${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.red[700]),
                ),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          var products = snapshot.data ?? [];

          // --- LOGIKA SORTIR BARU DIMULAI DI SINI ---
          products.sort((a, b) {
            // Prioritas 1: Produk dengan stok > 0 (Tersedia) diutamakan.
            final aTersedia = a.stock > 0;
            final bTersedia = b.stock > 0;

            if (aTersedia && !bTersedia) {
              return -1; // a (tersedia) diletakkan sebelum b (habis).
            }
            if (!aTersedia && bTersedia) {
              return 1; // a (habis) diletakkan setelah b (tersedia).
            }

            // Prioritas 2: Jika status stok sama, urutkan berdasarkan nama (A-Z).
            return a.name.toLowerCase().compareTo(b.name.toLowerCase());
          });
          // --- LOGIKA SORTIR BARU BERAKHIR DI SINI ---

          if (_searchQuery.isNotEmpty) {
            products = products.where((product) {
              return product.name.toLowerCase().contains(_searchQuery.toLowerCase());
            }).toList();
          }

          if (products.isEmpty) {
            return const Center(
              child: Text(
                'Tidak ada produk yang cocok dengan pencarian Anda.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
            );
          }

          return Padding(
            padding: const EdgeInsets.all(8.0),
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.55,
                crossAxisSpacing: 8.0,
                mainAxisSpacing: 8.0,
              ),
              itemCount: products.length,
              itemBuilder: (context, index) {
                return ProductCard(product: products[index]);
              },
            ),
          );
        },
      ),
    );
  }
}
