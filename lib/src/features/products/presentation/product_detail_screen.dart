import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../core/data/firestore_service.dart';
import '../domain/product.dart';
import '../../cart/application/cart_provider.dart';
import 'widgets/quantity_selector.dart';

class ProductDetailScreen extends StatefulWidget {
  final Product? product;
  final String? productId;

  const ProductDetailScreen({
    super.key,
    this.product,
    this.productId,
  }) : assert(product != null || productId != null, 'Either product or productId must be provided.');

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  Product? _product;
  Future<Product?>? _fetchProductFuture;
  int _selectedQuantity = 1;

  @override
  void initState() {
    super.initState();
    if (widget.product != null) {
      _product = widget.product;
    } else {
      final firestoreService = Provider.of<FirestoreService>(context, listen: false);
      _fetchProductFuture = firestoreService.getProduct(widget.productId!);
    }
    if (_product?.stock == 0) {
      _selectedQuantity = 0;
    }
  }

  void _onQuantityChanged(int newQuantity) {
    setState(() {
      _selectedQuantity = newQuantity;
    });
  }

  // --- FUNGSI BARU UNTUK MENANGANI PENAMBAHAN KE KERANJANG ---
  Future<void> _handleAddToCart() async {
    if (_product == null || _selectedQuantity <= 0) return;

    final cartProvider = context.read<CartProvider>();
    final bool success = await cartProvider.addItemToCart(_product!, _selectedQuantity);

    if (!mounted) return; // Pastikan widget masih ada di tree

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$_selectedQuantity x ${_product!.name} ditambahkan ke keranjang.'),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Keranjang Penuh'),
          content: const Text('Maaf Keranjang Anda Penuh, harap checkout terlebih dahulu, lalu mengisi keranjang anda kembali. Terima Kasih'),
          actions: [
            TextButton(
              child: const Text('Mengerti'),
              onPressed: () => Navigator.of(ctx).pop(),
            ),
          ],
        ),
      );
    }
  }
  // --- AKHIR FUNGSI BARU ---

  @override
  Widget build(BuildContext context) {
    if (_product != null) {
      return _buildProductUI(_product!, context);
    }

    return FutureBuilder<Product?>(
      future: _fetchProductFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Error')),
            body: const Center(child: Text('Produk tidak dapat ditemukan.')),
          );
        }

        _product = snapshot.data;
        if (_product?.stock == 0) {
          _selectedQuantity = 0;
        }
        return _buildProductUI(_product!, context);
      },
    );
  }

  Widget _buildProductUI(Product product, BuildContext context) {
    final currencyFormatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    final theme = Theme.of(context);

    if (_selectedQuantity > product.stock) {
      _selectedQuantity = product.stock;
    }
    if (product.stock > 0 && _selectedQuantity == 0) {
      _selectedQuantity = 1;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(product.name),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Hero(
              tag: 'product-image-${product.id}',
              child: CachedNetworkImage(
                imageUrl: product.imageUrl,
                fit: BoxFit.cover,
                height: 300,
                placeholder: (context, url) => Container(
                  height: 300,
                  color: Colors.grey[200],
                  child: const Center(child: CircularProgressIndicator()),
                ),
                errorWidget: (context, url, error) => Container(
                  height: 300,
                  color: Colors.grey[200],
                  child: const Center(child: Icon(Icons.broken_image, size: 60, color: Colors.grey)),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(product.name, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(product.category, style: theme.textTheme.titleMedium?.copyWith(color: Colors.grey[600])),
                  const SizedBox(height: 16),
                  Text(product.description, style: theme.textTheme.bodyLarge?.copyWith(height: 1.5)),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Stok: ${product.stock}',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: product.stock > 0 ? Colors.green[700] : Colors.red[700],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Flexible(
                        child: Text(
                          currencyFormatter.format(product.price),
                          style: theme.textTheme.headlineSmall?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (product.stock > 0)
                QuantitySelector(
                  quantity: _selectedQuantity,
                  stock: product.stock,
                  onChanged: _onQuantityChanged,
                ),
              const SizedBox(height: 14),
              ElevatedButton.icon(
                // --- PERUBAHAN: Panggil fungsi _handleAddToCart ---
                onPressed: _selectedQuantity > 0 ? _handleAddToCart : null,
                icon: const Icon(Icons.add_shopping_cart),
                label: const Text('Tambah ke Keranjang'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
