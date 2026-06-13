import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';

import '../application/checkout_provider.dart';
import '../../cart/application/cart_provider.dart';
import '../../authentication/data/auth_service.dart';
import '../../../core/data/firestore_service.dart';
import '../data/biteship_service.dart';
import '../data/delivery_service.dart';
import 'widgets/delivery_info_widget.dart';
import 'widgets/address_selector.dart';
import 'widgets/payment_method_widget.dart';
import 'widgets/instant_shipping_widget.dart';
import 'widgets/biteship_rates_widget.dart';

class CheckoutScreen extends StatelessWidget {
  const CheckoutScreen({super.key});

  static const DeliveryLocation _storeLocation = DeliveryLocation(
    latitude: -5.1640848,
    longitude: 119.4686043,
    address:
        'Gallery Makassar, Jl. Borong Raya No.100, Manggala, Makassar 90234',
    contactName: 'Gogama Store',
    contactPhone: '6289636052501',
  );

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => CheckoutProvider(
        authService: context.read<AuthService>(),
        firestoreService: context.read<FirestoreService>(),
        cartProvider: context.read<CartProvider>(),
      )..initialize(),
      child: Consumer<CheckoutProvider>(
        builder: (context, checkoutProvider, child) {
          if (checkoutProvider.isInitializing) {
            return Scaffold(
              appBar: AppBar(title: const Text('Checkout')),
              body: const Center(child: CircularProgressIndicator()),
            );
          }

          return Scaffold(
            appBar: AppBar(
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => context.pop(),
              ),
              title: const Text('Checkout'),
            ),
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildAddressSelectorSection(context),
                  const SizedBox(height: 24),
                  _buildShippingOptions(context),
                  const SizedBox(height: 24),
                  _buildDeliveryInfoSection(context),
                  const SizedBox(height: 24),
                  _buildBiteshipRatesSection(context),
                  const SizedBox(height: 24),
                  _buildPaymentMethodSection(context),
                  const SizedBox(height: 24),
                  _buildOrderSummary(context),
                ],
              ),
            ),
            bottomNavigationBar: _buildCheckoutSummary(context),
          );
        },
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Text(
        title,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildAddressSelectorSection(BuildContext context) {
    final checkoutProvider = context.watch<CheckoutProvider>();
    if (checkoutProvider.userAddresses.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Pilih Alamat Tersimpan'),
        const AddressSelector(),
      ],
    );
  }

  Widget _buildOrderSummary(BuildContext context) {
    final cart = context.watch<CartProvider>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Ringkasan Pesanan'),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: cart.items.length,
          itemBuilder: (context, index) {
            final item = cart.items[index];
            return ListTile(
              leading: Image.network(
                item.gambar,
                width: 50,
                height: 50,
                fit: BoxFit.cover,
              ),
              title: Text(item.nama),
              subtitle: Text(
                '${item.quantity} x '
                '${NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ').format(item.harga)}',
              ),
              trailing: Text(
                NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ')
                    .format(item.quantity * item.harga),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildShippingOptions(BuildContext context) {
    final checkoutProvider = context.watch<CheckoutProvider>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Pilih Pengiriman'),
        ...checkoutProvider.shippingOptions.map((option) {
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: RadioListTile<String>(
              title: Text(option.name),
              subtitle: Text(
                '${option.description}\nEstimasi: ${option.estimatedDays}',
              ),
              secondary: Text(
                NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ')
                    .format(option.price),
              ),
              value: option.id,
              groupValue: checkoutProvider.selectedShipping?.id,
              onChanged: (value) {
                if (value != null) {
                  context.read<CheckoutProvider>().selectShippingOption(option);
                }
              },
            ),
          );
        }),
        const SizedBox(height: 16),
        Builder(
          builder: (context) {
            final provider = context.watch<CheckoutProvider>();
            final selectedAddress = provider.selectedAddress;

            if (selectedAddress != null &&
                selectedAddress.latitude != null &&
                selectedAddress.longitude != null) {
              return InstantShippingWidget(
                storeLocation: _storeLocation,
                destinationLocation: DeliveryLocation(
                  latitude: selectedAddress.latitude!,
                  longitude: selectedAddress.longitude!,
                  address: selectedAddress.address,
                  contactName: selectedAddress.name,
                  contactPhone: selectedAddress.phone,
                ),
                selectedRate: provider.selectedInstantRate,
                onRateSelected: (rate) =>
                    context.read<CheckoutProvider>().selectInstantRate(rate),
              );
            }
            return const SizedBox.shrink();
          },
        ),
      ],
    );
  }

  Widget _buildDeliveryInfoSection(BuildContext context) {
    final checkoutProvider = context.watch<CheckoutProvider>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(
          checkoutProvider.userAddresses.isEmpty
              ? 'Isi Alamat Pengiriman'
              : 'Atau Isi Alamat Pengiriman Baru',
        ),
        BiteshipAreaSearchField(
          onAreaSelected: (area) {
            context.read<CheckoutProvider>().onDestinationAreaSelected(area);
          },
          initialArea: checkoutProvider.selectedDestinationArea,
        ),
        const SizedBox(height: 16),
        const DeliveryInfoWidget(),
      ],
    );
  }

  Widget _buildBiteshipRatesSection(BuildContext context) {
    final provider = context.watch<CheckoutProvider>();
    final cartProvider = context.watch<CartProvider>();

    if (provider.selectedDestinationArea == null) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Pilih Kurir'),
        BiteshipRatesWidget(
          destinationAreaId: provider.selectedDestinationArea?.id,
          items: cartProvider.items
              .map(
                (item) => ShipmentItem(
                  productId: item.productId,
                  name: item.nama,
                  price: item.harga,
                  quantity: item.quantity,
                  weightGram: 200,
                ),
              )
              .toList(),
          selectedRate: provider.selectedBiteshipRate,
          onRateSelected: provider.selectBiteshipRate,
        ),
      ],
    );
  }

  Widget _buildPaymentMethodSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Metode Pembayaran'),
        const PaymentMethodWidget(),
      ],
    );
  }

  Widget _buildCheckoutSummary(BuildContext context) {
    final checkoutProvider = context.watch<CheckoutProvider>();
    final total = checkoutProvider.grandTotal;

    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(25), // 10% opacity
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Subtotal:', style: TextStyle(fontSize: 16)),
              Text(
                NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ')
                    .format(checkoutProvider.subtotal),
                style: const TextStyle(fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Pengiriman:', style: TextStyle(fontSize: 16)),
              Text(
                NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ')
                    .format(checkoutProvider.shippingCost),
                style: const TextStyle(fontSize: 16),
              ),
            ],
          ),
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total:',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              Text(
                NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ')
                    .format(total),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 50),
            ),
            onPressed: checkoutProvider.isProcessingOrder ||
                    checkoutProvider.isCreatingPayment
                ? null
                : () => _handlePlaceOrder(context),
            child: checkoutProvider.isProcessingOrder ||
                    checkoutProvider.isCreatingPayment
                ? const CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  )
                : const Text('Buat Pesanan & Bayar'),
          ),
        ],
      ),
    );
  }

  Future<void> _handlePlaceOrder(BuildContext context) async {
    final checkoutProv = context.read<CheckoutProvider>();

    final orderError = await checkoutProv.processOrder();
    if (!context.mounted) return;

    if (orderError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(orderError)),
      );
      return;
    }

    final orderId = checkoutProv.lastOrderId;
    if (orderId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal mendapatkan ID pesanan.')),
      );
      return;
    }

    if (checkoutProv.selectedPaymentMethod == 'midtrans') {
      final midtransError = await checkoutProv.createMidtransPayment(orderId);
      if (!context.mounted) return;

      if (midtransError != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(midtransError)),
        );
        return;
      }

      final redirectUrl = checkoutProv.midtransRedirectUrl;
      if (redirectUrl != null && context.mounted) {
        context.push('/payment-webview', extra: {
          'orderId': orderId,
          'redirectUrl': redirectUrl,
        });
      }
    } else {
      // Navigate to order detail screen for other payment methods
      context.go('/orders/$orderId');
    }
  }
}
