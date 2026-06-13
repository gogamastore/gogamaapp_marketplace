import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:myapp/src/features/checkout/data/biteship_service.dart';

/// Card tracking pengiriman Biteship (JNE, J&T, SiCepat, dll).
/// Pasang di OrderDetailScreen saat status order = "Dikirim".
///
/// Contoh pemakaian:
///   BiteshipTrackingCard(orderId: order.id)
class BiteshipTrackingCard extends StatefulWidget {
  final String orderId;
  final String? waybillId; // opsional — untuk tampilan awal
  final String? courierName; // opsional — untuk tampilan awal

  const BiteshipTrackingCard({
    super.key,
    required this.orderId,
    this.waybillId,
    this.courierName,
  });

  @override
  State<BiteshipTrackingCard> createState() => _BiteshipTrackingCardState();
}

class _BiteshipTrackingCardState extends State<BiteshipTrackingCard> {
  final _service = BiteshipService();
  BiteshipTrackingInfo? _info;
  bool _isLoading = false;
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final info = await _service.trackOrder(widget.orderId);
      if (mounted) setState(() => _info = info);
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

    final info = _info;
    if (info == null || !info.hasDelivery) {
      // Tampilkan card minimal jika ada waybill tapi belum ada data tracking
      if (widget.waybillId?.isNotEmpty == true) {
        return _buildMinimalCard();
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
            // Header kurir + status
            _buildHeader(info),
            const Divider(height: 24),

            // No resi
            if ((info.waybillId ?? widget.waybillId)?.isNotEmpty == true)
              _buildWaybillRow(info.waybillId ?? widget.waybillId ?? ''),

            const SizedBox(height: 12),

            // Tombol lacak + refresh
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.track_changes, size: 18),
                    label: const Text('Lacak Paket'),
                    onPressed: () => _openTracking(
                      info.trackingUrl ??
                          'https://biteship.com/tracking/${info.waybillId ?? widget.waybillId ?? ""}',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[700],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _load,
                  tooltip: 'Refresh status',
                ),
              ],
            ),

            // History perjalanan paket
            if (info.history.isNotEmpty) ...[
              const SizedBox(height: 8),
              _buildHistorySection(info.history),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BiteshipTrackingInfo info) {
    final courierLabel = info.courierName ?? widget.courierName ?? 'Kurir';
    final statusLabel = _statusLabel(info.status);
    final statusColor = _statusColor(info.status);

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.blue[50],
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.local_shipping, color: Colors.blue[700], size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                courierLabel,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 2),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWaybillRow(String waybill) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Icon(Icons.receipt_long, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('No. Resi',
                    style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                Text(
                  waybill,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      letterSpacing: 0.5),
                ),
              ],
            ),
          ),
          // Tombol salin resi
          TextButton(
            style: TextButton.styleFrom(
                padding: EdgeInsets.zero, minimumSize: const Size(40, 30)),
            onPressed: () {
              // Salin ke clipboard
              // Clipboard.setData(ClipboardData(text: waybill));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Nomor resi disalin'),
                  duration: Duration(seconds: 1),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: const Text('Salin', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildHistorySection(List<TrackingHistory> history) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => setState(() => _isExpanded = !_isExpanded),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                const Text(
                  'Riwayat Pengiriman',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const Spacer(),
                Icon(
                  _isExpanded ? Icons.expand_less : Icons.expand_more,
                  color: Colors.grey,
                ),
              ],
            ),
          ),
        ),
        if (_isExpanded)
          ...history.asMap().entries.map((entry) {
            final i = entry.key;
            final h = entry.value;
            final isFirst = i == 0;
            return _buildHistoryItem(h, isFirst: isFirst);
          }),
      ],
    );
  }

  Widget _buildHistoryItem(TrackingHistory h, {bool isFirst = false}) {
    String formattedTime = h.timestamp;
    try {
      final dt = DateTime.parse(h.timestamp).toLocal();
      formattedTime = DateFormat('d MMM HH:mm', 'id_ID').format(dt);
    } catch (_) {}

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline indicator
          SizedBox(
            width: 28,
            child: Column(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isFirst ? Colors.blue[700] : Colors.grey[400],
                  ),
                ),
                Expanded(
                  child: Container(
                    width: 2,
                    color: Colors.grey[300],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _statusLabel(h.status),
                    style: TextStyle(
                      fontWeight: isFirst ? FontWeight.bold : FontWeight.normal,
                      fontSize: 13,
                      color: isFirst ? Colors.blue[700] : Colors.black87,
                    ),
                  ),
                  if (h.note.isNotEmpty)
                    Text(h.note,
                        style:
                            TextStyle(fontSize: 12, color: Colors.grey[600])),
                  Text(formattedTime,
                      style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMinimalCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.courierName ?? 'Pengiriman',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            if (widget.waybillId?.isNotEmpty == true) ...[
              const SizedBox(height: 8),
              _buildWaybillRow(widget.waybillId!),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.track_changes),
                label: const Text('Lacak Paket'),
                onPressed: () => _openTracking(
                  'https://biteship.com/tracking/${widget.waybillId ?? ""}',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _statusLabel(String? status) {
    if (status == null) return 'Memproses...';
    final s = status.toLowerCase();
    if (s.contains('allocating') || s.contains('waiting'))
      return 'Mencari kurir';
    if (s.contains('picked_up') || s.contains('pickup'))
      return 'Paket dijemput';
    if (s.contains('in_transit') || s.contains('on_process'))
      return 'Dalam perjalanan';
    if (s.contains('delivered')) return 'Terkirim';
    if (s.contains('cancelled') || s.contains('failed'))
      return 'Gagal terkirim';
    if (s.contains('returned')) return 'Dikembalikan';
    return status;
  }

  Color _statusColor(String? status) {
    final s = status?.toLowerCase() ?? '';
    if (s.contains('delivered')) return Colors.green;
    if (s.contains('cancelled') ||
        s.contains('failed') ||
        s.contains('returned')) return Colors.red;
    if (s.contains('in_transit') || s.contains('on_process'))
      return Colors.blue;
    return Colors.orange;
  }

  Future<void> _openTracking(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
