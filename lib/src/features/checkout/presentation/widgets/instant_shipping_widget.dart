import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../data/delivery_service.dart';

/// Widget untuk menampilkan pilihan tarif GoSend & GrabExpress di halaman checkout.
class InstantShippingWidget extends StatefulWidget {
  final DeliveryLocation storeLocation;

  // FIX: pakai destinationLocation (DeliveryLocation?) bukan destinationAddress (String)
  final DeliveryLocation? destinationLocation;

  final void Function(ShippingRate selected)? onRateSelected;
  final ShippingRate? selectedRate;

  const InstantShippingWidget({
    super.key,
    required this.storeLocation,
    this.destinationLocation,
    this.onRateSelected,
    this.selectedRate,
  });

  @override
  State<InstantShippingWidget> createState() => _InstantShippingWidgetState();
}

class _InstantShippingWidgetState extends State<InstantShippingWidget> {
  final DeliveryService _deliveryService = DeliveryService();
  List<ShippingRate> _rates = [];
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    if (widget.destinationLocation != null) {
      _fetchRates();
    }
  }

  @override
  void didUpdateWidget(InstantShippingWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.destinationLocation?.latitude !=
            oldWidget.destinationLocation?.latitude ||
        widget.destinationLocation?.longitude !=
            oldWidget.destinationLocation?.longitude) {
      _fetchRates();
    }
  }

  Future<void> _fetchRates() async {
    if (widget.destinationLocation == null) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _rates = [];
    });

    try {
      final rates = await _deliveryService.getShippingRates(
        origin: widget.storeLocation,
        destination: widget.destinationLocation!,
        weightKg: 1.0,
      );
      if (mounted) {
        setState(() {
          _rates = rates;
          _isLoading = false;
        });
      }
    } on DeliveryException catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.message;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.destinationLocation == null) {
      return _buildPlaceholder();
    }

    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Column(
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 12),
              Text('Menghitung ongkir...',
                  style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      );
    }

    if (_errorMessage != null) return _buildErrorState();
    if (_rates.isEmpty) return _buildEmptyState();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ..._rates.map((rate) => _buildRateTile(rate)),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: _fetchRates,
          icon: const Icon(Icons.refresh, size: 16),
          label: const Text('Refresh Tarif'),
          style: TextButton.styleFrom(foregroundColor: Colors.grey[600]),
        ),
      ],
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        children: [
          Icon(Icons.location_off, color: Colors.grey[400]),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Isi alamat pengiriman untuk melihat tarif GoSend & GrabExpress.',
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red[200]!),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.red[400]),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _errorMessage!,
                  style: TextStyle(color: Colors.red[700], fontSize: 13),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _fetchRates,
                  child: const Text('Coba Lagi'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange[200]!),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: Colors.orange[700]),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Layanan pengiriman instan tidak tersedia untuk rute ini.',
              style: TextStyle(color: Colors.orange[800], fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRateTile(ShippingRate rate) {
    final currency =
        NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    final isSelected = widget.selectedRate?.provider == rate.provider &&
        widget.selectedRate?.serviceType == rate.serviceType;
    final isUnavailable = !rate.available;

    return GestureDetector(
      onTap: isUnavailable ? null : () => widget.onRateSelected?.call(rate),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.08)
              : isUnavailable
                  ? Colors.grey[100]
                  : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : isUnavailable
                    ? Colors.grey[300]!
                    : Colors.grey[200]!,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : Colors.grey[400]!,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? Center(
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            _buildProviderBadge(rate.provider),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    rate.serviceName,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: isUnavailable ? Colors.grey : null,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(Icons.schedule, size: 12, color: Colors.grey[500]),
                      const SizedBox(width: 4),
                      Text(
                        rate.estimatedDelivery,
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                  if (isUnavailable && rate.errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        rate.errorMessage!,
                        style: TextStyle(fontSize: 11, color: Colors.red[400]),
                      ),
                    ),
                ],
              ),
            ),
            Text(
              isUnavailable ? 'Tidak Tersedia' : currency.format(rate.price),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: isUnavailable
                    ? Colors.grey
                    : Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProviderBadge(String provider) {
    final isGoSend = provider == 'gosend';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isGoSend
            ? const Color(0xFF00AA13).withValues(alpha: 0.1)
            : const Color(0xFF00B14F).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        isGoSend ? 'GoSend' : 'Grab',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: isGoSend ? const Color(0xFF00AA13) : const Color(0xFF00B14F),
        ),
      ),
    );
  }
}
