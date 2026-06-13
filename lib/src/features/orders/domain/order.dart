import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

// Helper function to safely convert any value to num
num _toNum(dynamic value) {
  if (value == null) return 0;
  if (value is num) return value;
  if (value is String) {
    return num.tryParse(value) ?? 0;
  }
  return 0;
}

class ProductItem {
  final String image;
  final String name;
  final num price;
  final String productId;
  final int quantity;

  ProductItem({
    required this.image,
    required this.name,
    required this.price,
    required this.productId,
    required this.quantity,
  });

  factory ProductItem.fromMap(Map<String, dynamic> data) {
    return ProductItem(
      // Cerdas: Cek 'imageUrl' dulu, baru 'image', atau default ke string kosong
      image: data['imageUrl'] ?? data['image'] ?? '',
      name: data['name'] ?? 'Unknown Product',
      price: _toNum(data['price']),
      productId: data['productId'] ?? '',
      quantity: _toNum(data['quantity']).toInt(),
    );
  }
}

class Order {
  final String id;
  final String customer;
  final Map<String, dynamic> customerDetails;
  final Timestamp date;
  final String paymentMethod;
  final String? paymentProofUrl;
  final String paymentStatus;
  final List<ProductItem> products;
  final num shippingFee;
  final String shippingMethod;
  final String status;
  final num subtotal;
  final num total;
  final String? waybillId;
  final String? biteshipCourierName;
  final String? deliveryTrackingUrl;

  Order({
    required this.id,
    required this.customer,
    required this.customerDetails,
    required this.date,
    required this.paymentMethod,
    this.paymentProofUrl,
    required this.paymentStatus,
    required this.products,
    required this.shippingFee,
    required this.shippingMethod,
    required this.status,
    required this.subtotal,
    required this.total,
    this.waybillId,
    this.biteshipCourierName,
    this.deliveryTrackingUrl,
  });

  factory Order.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    var productList = (data['products'] as List<dynamic>?) ?? [];

    return Order(
      id: doc.id,
      customer: data['customerDetails']?['name'] ?? 'N/A',
      customerDetails: (data['customerDetails'] as Map<String, dynamic>?) ?? {},
      date: data['date'] ?? Timestamp.now(),
      paymentMethod: data['paymentMethod'] ?? 'N/A',
      paymentProofUrl: data['paymentProofUrl'],
      paymentStatus: data['paymentStatus'] ?? 'Unknown',
      products: productList.map((p) => ProductItem.fromMap(p as Map<String, dynamic>)).toList(),
      shippingFee: _toNum(data['shippingFee']),
      shippingMethod: data['shippingMethod'] ?? 'N/A',
      status: data['status'] ?? 'Unknown',
      subtotal: _toNum(data['subtotal']),
      total: _toNum(data['total']),
      waybillId: data['waybillId'] as String?,
      biteshipCourierName: data['biteshipCourierName'] as String?,
      deliveryTrackingUrl: data['deliveryTrackingUrl'] as String?,
    );
  }

  int get totalProducts => products.fold(0, (sum, item) => sum + item.quantity);
  
  String get formattedDate {
    return DateFormat('d MMMM yyyy', 'id_ID').format(date.toDate());
  }

  String get formattedTotal {
    final numberFormat = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    return numberFormat.format(total);
  }
}
