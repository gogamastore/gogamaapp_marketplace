import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:go_router/go_router.dart';

import '../../authentication/data/auth_service.dart';
import '../domain/order.dart';

class OrderHistoryScreen extends StatefulWidget {
  const OrderHistoryScreen({super.key});

  @override
  State<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends State<OrderHistoryScreen> {
  String _selectedStatus = 'Semua';

  final List<String> _statusFilters = [
    'Semua',
    'Belum Proses',
    'Diproses',
    'Dikirim',
    'Selesai',
    'Dibatalkan',
  ];

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('id_ID');
  }

  List<String> _getFirestoreStatuses(String displayStatus) {
    switch (displayStatus) {
      case 'Belum Proses':
        return ['Pending', 'pending'];
      case 'Diproses':
        return ['Processing', 'processing'];
      case 'Dikirim':
        return ['shipped', 'Shipped'];
      case 'Selesai':
        return ['delivered', 'Delivered'];
      case 'Dibatalkan':
        return ['Cancelled', 'cancelled'];
      default:
        return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final String? userId = authService.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Riwayat Pesanan'),
        elevation: 1,
      ),
      body: Column(
        children: [
          _buildHeader(),
          _buildStatusFilter(),
          Expanded(
            child: userId == null
                ? const Center(child: Text('Silakan login untuk melihat riwayat.'))
                : _buildOrderList(userId),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16.0),
      color: Theme.of(context).canvasColor,
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Pesanan Saya', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          SizedBox(height: 4),
          Text('Lihat semua riwayat transaksi Anda di sini.', style: TextStyle(fontSize: 14, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildStatusFilter() {
    return Container(
      height: 90,
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      decoration: BoxDecoration(
        color: Theme.of(context).canvasColor,
        border: Border(bottom: BorderSide(color: Colors.grey[200]!, width: 1)),
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12.0),
        itemCount: _statusFilters.length,
        itemBuilder: (context, index) {
          final status = _statusFilters[index];
          final isSelected = status == _selectedStatus;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: ChoiceChip(
              label: Text(status),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  setState(() {
                    _selectedStatus = status;
                  });
                }
              },
              backgroundColor: isSelected ? Colors.deepPurple[100] : Colors.grey[100],
              selectedColor: Colors.deepPurple,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : Colors.black87,
                fontWeight: FontWeight.bold,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: isSelected ? Colors.deepPurple : Colors.grey[300]!),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildOrderList(String userId) {
    Query query = FirebaseFirestore.instance
        .collection('orders')
        .where('customerId', isEqualTo: userId)
        .orderBy('date', descending: true);

    if (_selectedStatus != 'Semua') {
      final firestoreStatuses = _getFirestoreStatuses(_selectedStatus);
      query = query.where('status', whereIn: firestoreStatuses);
    }

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Terjadi kesalahan: ${snapshot.error}'));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.receipt_long, size: 80, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  _selectedStatus == 'Semua' 
                      ? 'Anda belum memiliki riwayat pesanan'
                      : 'Tidak ada pesanan dengan status "$_selectedStatus"',
                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        final orders = snapshot.data!.docs.map((doc) => Order.fromFirestore(doc)).toList();

        return ListView.builder(
          padding: const EdgeInsets.all(16.0),
          itemCount: orders.length,
          itemBuilder: (context, index) {
            return OrderCard(order: orders[index]);
          },
        );
      },
    );
  }
}

class OrderCard extends StatelessWidget {
  final Order order;

  const OrderCard({super.key, required this.order});

  String _normalizeStatus(String status) {
    final s = status.toLowerCase();
    if (s == 'pending') return 'Belum Proses';
    if (s == 'processing') return 'Diproses';
    if (s == 'shipped') return 'Dikirim';
    if (s == 'delivered') return 'Selesai';
    if (s == 'cancelled') return 'Dibatalkan';
    return status; // Fallback
  }

  String _normalizePaymentStatus(String paymentStatus) {
    final ps = paymentStatus.toLowerCase();
    if (ps == 'unpaid') return 'Belum Bayar';
    if (ps == 'paid') return 'Lunas';
    return paymentStatus; // Fallback
  }
  
  void _showConfirmationDialog(BuildContext context, String orderId) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Konfirmasi Pesanan'),
          content: const Text('Apakah Anda yakin pesanan ini telah diterima?'),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          actions: <Widget>[
            TextButton(
              child: const Text('Batal', style: TextStyle(color: Colors.grey)),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
            TextButton(
              child: const Text('Ya'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _updateOrderStatusToDelivered(context, orderId);
              },
            ),
          ],
        );
      },
    );
  }

  void _updateOrderStatusToDelivered(BuildContext context, String orderId) {
    FirebaseFirestore.instance
        .collection('orders')
        .doc(orderId)
        .update({'status': 'delivered'})
        .then((_) {
      // --- PERBAIKAN DIMULAI DI SINI ---
      if (!context.mounted) return; // Cek jika widget masih ada di tree
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Status pesanan berhasil diperbarui ke "Selesai".'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }).catchError((error) {
      if (!context.mounted) return; // Cek jika widget masih ada di tree
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal memperbarui status: $error'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    });
    // --- PERBAIKAN BERAKHIR DI SINI ---
  }

  @override
  Widget build(BuildContext context) {
    final normalizedStatus = _normalizeStatus(order.status);

    return Card(
      elevation: 3,
      margin: const EdgeInsets.only(bottom: 16.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          context.push('/order-detail', extra: order);
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('#${order.id.substring(0, 8).toUpperCase()}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  _buildStatusChip(normalizedStatus),
                ],
              ),
              Text(order.formattedDate, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(order.customer, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 4),
                        Text('${order.totalProducts} produk • ${order.formattedTotal}', style: TextStyle(color: Colors.grey[700])),
                        const SizedBox(height: 8),
                        Text(order.paymentMethod.replaceAll('_', ' ').toUpperCase(), style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                      ],
                    ),
                  ),
                  _buildPaymentStatusText(_normalizePaymentStatus(order.paymentStatus)),
                ],
              ),
              const SizedBox(height: 8),
              const Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                   Text('Lihat Detail', style: TextStyle(color: Colors.grey, fontSize: 12)),
                   SizedBox(width: 4),
                   Icon(Icons.chevron_right, color: Colors.grey, size: 18),
                ],
              ),

              if (normalizedStatus == 'Dikirim')
                Padding(
                  padding: const EdgeInsets.only(top: 16.0),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        _showConfirmationDialog(context, order.id);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Pesanan Diterima'),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color chipColor;
    switch (status) {
      case 'Belum Proses':
        chipColor = Colors.orange;
        break;
      case 'Diproses':
        chipColor = Colors.blue;
        break;
      case 'Dikirim':
        chipColor = Colors.lightGreen;
        break;
      case 'Selesai':
        chipColor = Colors.green;
        break;
      case 'Dibatalkan':
        chipColor = Colors.red;
        break;
      default:
        chipColor = Colors.grey;
    }

    return Chip(
      label: Text(status, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
      backgroundColor: chipColor,
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 0),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  Widget _buildPaymentStatusText(String paymentStatus) {
    Color textColor;
    switch (paymentStatus) {
      case 'Lunas':
        textColor = Colors.green[700]!;
        break;
      case 'Belum Bayar':
        textColor = Colors.red[700]!;
        break;
      default:
        textColor = Colors.grey;
    }

    return Text(
      paymentStatus,
      style: TextStyle(
        color: textColor,
        fontWeight: FontWeight.bold,
        fontSize: 14,
      ),
    );
  }
}
