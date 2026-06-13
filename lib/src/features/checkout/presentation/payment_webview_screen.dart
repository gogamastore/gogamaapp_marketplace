import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:go_router/go_router.dart';

/// Layar WebView untuk menampilkan Midtrans Snap payment page.
/// Navigasi ke sini setelah mendapatkan [redirectUrl] dari Cloud Functions.
///
/// Cara pakai:
///   context.push('/payment-webview', extra: {
///     'orderId': order.id,
///     'redirectUrl': result.redirectUrl,
///   });
class PaymentWebViewScreen extends StatefulWidget {
  final String orderId;
  final String redirectUrl;

  const PaymentWebViewScreen({
    super.key,
    required this.orderId,
    required this.redirectUrl,
  });

  @override
  State<PaymentWebViewScreen> createState() => _PaymentWebViewScreenState();
}

class _PaymentWebViewScreenState extends State<PaymentWebViewScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;

  // URL yang mengindikasikan pembayaran selesai (berhasil / gagal / pending)
  static const _finishPaths = [
    '/payment-result',    // Deep link dari Midtrans callback
    'status_code=200',    // Midtrans success
    'transaction_status=settlement',
    'transaction_status=capture',
  ];

  static const _pendingPaths = [
    'transaction_status=pending',
  ];

  static const _failedPaths = [
    'transaction_status=cancel',
    'transaction_status=deny',
    'transaction_status=expire',
  ];

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (progress) {
            if (mounted) setState(() => _isLoading = progress < 100);
          },
          onPageFinished: (_) {
            if (mounted) setState(() => _isLoading = false);
          },
          onNavigationRequest: (request) {
            return _handleNavigation(request.url);
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.redirectUrl));
  }

  NavigationDecision _handleNavigation(String url) {
    // Cek apakah URL menandakan pembayaran selesai
    if (_finishPaths.any((path) => url.contains(path))) {
      _onPaymentSuccess();
      return NavigationDecision.prevent;
    }
    if (_pendingPaths.any((path) => url.contains(path))) {
      _onPaymentPending();
      return NavigationDecision.prevent;
    }
    if (_failedPaths.any((path) => url.contains(path))) {
      _onPaymentFailed();
      return NavigationDecision.prevent;
    }
    return NavigationDecision.navigate;
  }

  void _onPaymentSuccess() {
    if (!mounted) return;
    _showResultAndNavigate(
      icon: Icons.check_circle,
      iconColor: Colors.green,
      title: 'Pembayaran Berhasil!',
      message: 'Pesanan Anda sedang diproses.',
      routeResult: 'success',
    );
  }

  void _onPaymentPending() {
    if (!mounted) return;
    _showResultAndNavigate(
      icon: Icons.hourglass_top,
      iconColor: Colors.orange,
      title: 'Menunggu Pembayaran',
      message: 'Selesaikan pembayaran Anda sebelum batas waktu.',
      routeResult: 'pending',
    );
  }

  void _onPaymentFailed() {
    if (!mounted) return;
    _showResultAndNavigate(
      icon: Icons.cancel,
      iconColor: Colors.red,
      title: 'Pembayaran Gagal',
      message: 'Silakan coba metode pembayaran lain.',
      routeResult: 'failed',
    );
  }

  void _showResultAndNavigate({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String message,
    required String routeResult,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: iconColor),
            const SizedBox(height: 16),
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[600])),
          ],
        ),
        actions: [
          TextButton(
            child: const Text('Lihat Detail Pesanan'),
            onPressed: () {
              Navigator.of(ctx).pop();
              // Kembali ke home dan navigasi ke order detail
              context.go('/profile/orders');
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pembayaran'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => _showCancelConfirmation(),
        ),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }

  void _showCancelConfirmation() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Batalkan Pembayaran?'),
        content: const Text('Pembayaran belum selesai. Apakah Anda yakin ingin keluar?'),
        actions: [
          TextButton(
            child: const Text('Lanjutkan Bayar'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          TextButton(
            child: Text('Keluar', style: TextStyle(color: Theme.of(context).colorScheme.error)),
            onPressed: () {
              Navigator.of(ctx).pop();
              context.pop();
            },
          ),
        ],
      ),
    );
  }
}
