import 'dart:developer' as developer;
import '../../products/domain/product.dart';

class CartItem {
  final Product product;
  final int quantity;

  CartItem({required this.product, required this.quantity});

  // This factory is designed to be completely safe and never throw an error.
  factory CartItem.fromMap(Map<String, dynamic> map) {
    // --- Safe parsing with defaults ---

    // Safely parse the quantity. Default to 1 if missing or invalid.
    int quantity = 1;
    final quantityValue = map['quantity'];
    if (quantityValue is int && quantityValue > 0) {
      quantity = quantityValue;
    }

    // Safely extract the product data map.
    // If it's missing or the wrong type, pass an empty map to Product.fromMap.
    // The robust Product.fromMap will handle the rest.
    final productData = map['product'] is Map<String, dynamic>
        ? map['product'] as Map<String, dynamic>
        : <String, dynamic>{};

    final product = Product.fromMap(productData);

    // Log a warning if the original product data was bad
    if (productData.isEmpty) {
        developer.log(
        'CartItem contained missing or malformed product data.',
        name: 'CartItem.fromMap',
        level: 900, // Warning
        error: map, // Log the problematic data
      );
    }

    return CartItem(
      product: product,
      quantity: quantity,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'product': product.toMap(),
      'quantity': quantity,
    };
  }
}
