import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:myapp/src/features/checkout/data/delivery_service.dart';

/// Widget card tracking pengiriman GoSend/Grab.
/// Ditempel di OrderDetailScreen setelah order berstatus "Dikirim".
class DeliveryTrackingCard extends StatefulWidget {
  final String orderId;
  final String? existingTrackingUrl;

  const DeliveryTrackingCard({
    super.key,
    required this.orderId,
    this.existingTrackingUrl,
  });

  @override
  State<DeliveryTrackingCard> createState() => _DeliveryTrackingCardState();
}

class _DeliveryTrackingCardState extends State<DeliveryTrackingCard> {
  final DeliveryService _deliveryService = DeliveryService();
  DeliveryTrackingInfo? _trackingInfo;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadTracking();
  }

  Future<void> _loadTracking() async {
    setState(() => _isLoading = true);
    try {
      final info = await _deliveryService.trackDelivery(widget.orderId);
      if (mounted) setState(() => _trackingInfo = info);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    final info = _trackingInfo;

    if (info == null || !info.hasDelivery) {
      // Jika belum ada booking tapi ada tracking URL lama, tampilkan
      if (widget.existingTrackingUrl?.isNotEmpty == true) {
        return _buildSimpleTrackingCard(widget.existingTrackingUrl!);
      }
      return const SizedBox.shrink();
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                _buildProviderIcon(info.provider ?? ''),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _providerName(info.provider),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Text(
                        _statusLabel(info.status),
                        style: TextStyle(
                          color: _statusColor(info.status),
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _loadTracking,
                  tooltip: 'Refresh status',
                ),
              ],
            ),

            // Info driver (jika ada)
            if (info.driverName != null) ...[
              const Divider(height: 24),
              _buildDriverInfo(info),
            ],

            // Tombol lacak di peta
            if (info.trackingUrl?.isNotEmpty == true) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.map),
                  label: const Text('Lacak di Peta'),
                  onPressed: () => _openTracking(info.trackingUrl!),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _providerColor(info.provider),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDriverInfo(DeliveryTrackingInfo info) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Info Driver', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.person, size: 16, color: Colors.grey),
              const SizedBox(width: 8),
              Text(info.driverName ?? '-', style: const TextStyle(fontSize: 14)),
            ],
          ),
          if (info.driverPhone != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.phone, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Text(info.driverPhone!, style: const TextStyle(fontSize: 14)),
                const Spacer(),
                TextButton.icon(
                  icon: const Icon(Icons.call, size: 14),
                  label: const Text('Hubungi'),
                  onPressed: () => _call(info.driverPhone!),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 0),
                  ),
                ),
              ],
            ),
          ],
          if (info.driverPlate != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.motorcycle, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Text(info.driverPlate!, style: const TextStyle(fontSize: 14)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSimpleTrackingCard(String url) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.location_on),
            label: const Text('Lacak Pengiriman'),
            onPressed: () => _openTracking(url),
          ),
        ),
      ),
    );
  }

  Widget _buildProviderIcon(String provider) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: _providerColor(provider).withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          provider == 'gosend' ? 'G' : 'Gr',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: _providerColor(provider),
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  String _providerName(String? provider) {
    if (provider == 'gosend') return 'GoSend';
    if (provider == 'grab') return 'GrabExpress';
    return 'Kurir';
  }

  Color _providerColor(String? provider) {
    if (provider == 'gosend') return const Color(0xFF00AA13);
    if (provider == 'grab') return const Color(0xFF00B14F);
    return Colors.blue;
  }

  String _statusLabel(String? status) {
    if (status == null) return 'Memproses...';
    switch (status.toLowerCase()) {
      case 'finding_driver':
      case 'allocating':
        return 'Mencari driver...';
      case 'driver_accepted':
      case 'driver_on_the_way_to_pickup':
        return 'Driver menuju toko';
      case 'picked_up':
      case 'in_delivery':
        return 'Dalam perjalanan ke Anda';
      case 'delivered':
        return 'Terkirim';
      case 'cancelled':
        return 'Dibatalkan';
      default:
        return status;
    }
  }

  Color _statusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'delivered':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.blue;
    }
  }

  Future<void> _openTracking(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _call(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }
}