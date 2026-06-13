import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/data/firestore_service.dart';
import '../../authentication/data/auth_service.dart';
import '../../cart/application/cart_provider.dart' show CartProvider;
import '../../profile/domain/address.dart';
import '../domain/bank_account.dart';
import '../domain/shipping_option.dart';
import '../data/payment_service.dart';
import '../data/delivery_service.dart';
import '../data/biteship_service.dart';

class DeliveryInfo {
  String recipientName;
  String phoneNumber;
  String address;
  String city;
  String postalCode;
  String specialInstructions;

  DeliveryInfo({
    this.recipientName = '',
    this.phoneNumber = '',
    this.address = '',
    this.city = '',
    this.postalCode = '',
    this.specialInstructions = '',
  });

  bool get isCompleted =>
      recipientName.isNotEmpty &&
      phoneNumber.isNotEmpty &&
      address.isNotEmpty &&
      city.isNotEmpty &&
      postalCode.isNotEmpty;
}

class CheckoutProvider with ChangeNotifier {
  final AuthService _authService;
  final FirestoreService _firestoreService;
  final CartProvider _cartProvider;

  bool _isInitializing = true;
  bool _isProcessingOrder = false;

  // ── Tambahkan field ini ───────────────────────────────────────────
  String? _lastOrderId;

  // ── Payment ──────────────────────────────────────────────────────
  final PaymentService _paymentService = PaymentService();
  String? _midtransRedirectUrl;
  String? _midtransToken;
  bool _isCreatingPayment = false;

  // ── Instant Delivery ─────────────────────────────────────────────
  final DeliveryService _deliveryService = DeliveryService();
  List<ShippingRate> _instantRates = [];
  ShippingRate? _selectedInstantRate;
  bool _isLoadingRates = false;
  String? _ratesErrorMessage;

  // ── Biteship state ─────────────────────────────────────────────────
  final BiteshipService _biteshipService = BiteshipService();
  BiteshipArea? _selectedDestinationArea;
  List<BiteshipRate> _biteshipRates = [];
  BiteshipRate? _selectedBiteshipRate;
  bool _isLoadingBiteshipRates = false;
  String? _biteshipRatesError;

  List<BankAccount> _bankAccounts = [];
  List<Address> _userAddresses = [];
  final List<ShippingOption> _shippingOptions = [
    ShippingOption(
      id: 'courier',
      name: 'Pengiriman oleh Kurir',
      price: 15000,
      estimatedDays: '1-3 hari',
      description: 'Pengiriman menggunakan kurir, harga mulai dari Rp 15.000/koli',
    ),
    ShippingOption(
      id: 'pickup',
      name: 'Ambil di Toko',
      price: 0,
      estimatedDays: 'Hari ini',
      description: 'Ambil sendiri di toko, tidak ada biaya pengiriman',
    ),
  ];

  ShippingOption? _selectedShipping;
  String _selectedPaymentMethod = 'bank_transfer';
  Address? _selectedAddress;
  final DeliveryInfo _deliveryInfo = DeliveryInfo();
  XFile? _paymentProofImage;

  bool get isInitializing => _isInitializing;
  bool get isProcessingOrder => _isProcessingOrder;
  
  // ── Tambahkan getter ini ──────────────────────────────────────────
  String? get lastOrderId => _lastOrderId;

  List<BankAccount> get bankAccounts => _bankAccounts;
  List<Address> get userAddresses => _userAddresses;
  List<ShippingOption> get shippingOptions => _shippingOptions;
  ShippingOption? get selectedShipping => _selectedShipping;
  String get selectedPaymentMethod => _selectedPaymentMethod;
  Address? get selectedAddress => _selectedAddress;
  DeliveryInfo get deliveryInfo => _deliveryInfo;
  XFile? get paymentProofImage => _paymentProofImage;

  double get subtotal => _cartProvider.total;
  double get shippingCost {
    if (_selectedBiteshipRate != null) return _selectedBiteshipRate!.price;
    if (_selectedInstantRate != null) return _selectedInstantRate!.price;
    return _selectedShipping?.price ?? 0;
  }
  double get grandTotal => subtotal + shippingCost;

  String? get midtransRedirectUrl => _midtransRedirectUrl;
  String? get midtransToken => _midtransToken;
  bool get isCreatingPayment => _isCreatingPayment;
  List<ShippingRate> get instantRates => _instantRates;
  ShippingRate? get selectedInstantRate => _selectedInstantRate;
  bool get isLoadingRates => _isLoadingRates;
  String? get ratesErrorMessage => _ratesErrorMessage;

  BiteshipArea? get selectedDestinationArea => _selectedDestinationArea;
  List<BiteshipRate> get biteshipRates => _biteshipRates;
  BiteshipRate? get selectedBiteshipRate => _selectedBiteshipRate;
  bool get isLoadingBiteshipRates => _isLoadingBiteshipRates;
  String? get biteshipRatesError => _biteshipRatesError;

  CheckoutProvider({
    required AuthService authService,
    required FirestoreService firestoreService,
    required CartProvider cartProvider,
  })  : _authService = authService,
        _firestoreService = firestoreService,
        _cartProvider = cartProvider;

  Future<void> initialize() async {
    developer.log('Initializing CheckoutProvider...', name: 'CheckoutProvider');
    _isInitializing = true;
    notifyListeners();
    _selectedShipping = _shippingOptions.first;
    await _fetchBankAccounts();
    await _fetchUserAddresses(); // This will now auto-select the default address
    _isInitializing = false;
    developer.log('Initialization complete. Found ${_userAddresses.length} addresses.', name: 'CheckoutProvider');
    notifyListeners();
  }

  Future<void> _fetchBankAccounts() async {
    try {
      _bankAccounts = await _firestoreService.getBankAccounts();
    } catch (e) {
      _bankAccounts = [];
      developer.log('Error fetching bank accounts', name: 'CheckoutProvider', error: e);
    }
  }

  Future<void> _fetchUserAddresses() async {
    final user = _authService.currentUser;
    if (user != null) {
      developer.log('Fetching addresses for user: ${user.uid}', name: 'CheckoutProvider');
      try {
        _userAddresses = await _firestoreService.getUserAddresses(user.uid);
        developer.log('Successfully fetched ${_userAddresses.length} addresses.', name: 'CheckoutProvider');
        
        Address? defaultAddress;
        try {
          defaultAddress = _userAddresses.firstWhere((addr) => addr.isDefault);
        } catch (e) {
          if (_userAddresses.isNotEmpty) {
            defaultAddress = _userAddresses.first;
          }
        }

        if (defaultAddress != null) {
          selectSavedAddress(defaultAddress);
        }
      } catch (e, s) {
        _userAddresses = [];
        developer.log('Error fetching user addresses', name: 'CheckoutProvider', error: e, stackTrace: s);
      }
    } else {
       developer.log('Cannot fetch addresses: User is not logged in.', name: 'CheckoutProvider');
       _userAddresses = [];
    }
  }

  void selectShippingOption(ShippingOption option) {
    if (_selectedShipping?.id == option.id) return;
    _selectedShipping = option;

    if (option.id == 'courier' && _selectedPaymentMethod == 'cod') {
      _selectedPaymentMethod = 'bank_transfer';
    }
    notifyListeners();
  }

  void selectPaymentMethod(String method) {
    if (_selectedPaymentMethod == method) return;
    
    if (method == 'cod' && _selectedShipping?.id == 'courier') {
      return;
    }

    _selectedPaymentMethod = method;
    notifyListeners();
  }

  void selectSavedAddress(Address address) {
    _selectedAddress = address;
    _deliveryInfo.recipientName = address.name;
    _deliveryInfo.phoneNumber = address.phone;
    _deliveryInfo.address = address.address;
    _deliveryInfo.city = address.city;
    _deliveryInfo.postalCode = address.postalCode;
    notifyListeners();
  }

  void clearSelectedAddress() {
    _selectedAddress = null;
    _deliveryInfo.recipientName = '';
    _deliveryInfo.phoneNumber = '';
    _deliveryInfo.address = '';
    _deliveryInfo.city = '';
    _deliveryInfo.postalCode = '';
    notifyListeners();
  }

  void updateDeliveryInfo({
    String? recipientName,
    String? phoneNumber,
    String? address,
    String? city,
    String? postalCode,
    String? specialInstructions,
  }) {
    _deliveryInfo.recipientName = recipientName ?? _deliveryInfo.recipientName;
    _deliveryInfo.phoneNumber = phoneNumber ?? _deliveryInfo.phoneNumber;
    _deliveryInfo.address = address ?? _deliveryInfo.address;
    _deliveryInfo.city = city ?? _deliveryInfo.city;
    _deliveryInfo.postalCode = postalCode ?? _deliveryInfo.postalCode;
    _deliveryInfo.specialInstructions = specialInstructions ?? _deliveryInfo.specialInstructions;
    // When manual update occurs, deselect the saved address
    _selectedAddress = null;
    notifyListeners();
  }

  Future<void> pickPaymentProof() async {
    final ImagePicker picker = ImagePicker();
    try {
      final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
      if (image != null) {
        _paymentProofImage = image;
        notifyListeners();
      }
    } catch (e) {
      developer.log('Error picking payment proof', name: 'CheckoutProvider', error: e);
    }
  }

  void removePaymentProof() {
    _paymentProofImage = null;
    notifyListeners();
  }

  Future<String?> processOrder() async {
    final user = _authService.currentUser;
    if (user == null || !_deliveryInfo.isCompleted || _cartProvider.items.isEmpty) {
      return 'Formulir tidak lengkap atau keranjang kosong.';
    }

    _isProcessingOrder = true;
    notifyListeners();

    final String newOrderId = _firestoreService.getNewOrderId();

    try {
      final now = DateTime.now();
      final isoTimestamp = now.toUtc().toIso8601String();

      String paymentProofUrl = '';
      if (_paymentProofImage != null) {
        paymentProofUrl = await _firestoreService.uploadPaymentProof(
            user.uid, newOrderId, _paymentProofImage!);
      }

      final orderData = {
        // Timestamps & Dates
        'created_at': isoTimestamp,
        'updated_at': isoTimestamp,
        'date': now,
        'stockUpdateTimestamp': isoTimestamp,

        // Customer Info
        'customer': _deliveryInfo.recipientName,
        'customerId': user.uid,
        'customerDetails': {
          'name': _deliveryInfo.recipientName,
          'address': '${_deliveryInfo.address}, ${_deliveryInfo.city}, ${_deliveryInfo.postalCode}',
          'whatsapp': _deliveryInfo.phoneNumber,
        },

        // Product Info
        'products': _cartProvider.items.map((item) => {
          'productId': item.productId,
          'name': item.nama,
          'price': item.harga,
          'quantity': item.quantity,
          'image': item.gambar,
        }).toList(),
        'productIds': _cartProvider.items.map((item) => item.productId).toList(),

        // Payment Info
        'paymentMethod': _selectedPaymentMethod,
        'paymentStatus': _paymentProofImage != null ? 'Paid' : 'Unpaid',
        'paymentProofUrl': paymentProofUrl,
        'paymentProofFileName': _paymentProofImage?.name ?? '',
        'paymentProofId': '', // Left blank as per structure
        'paymentProofUploaded': _paymentProofImage != null,

        // Shipping Info
        'shippingMethod': _selectedShipping!.name,
        'shippingFee': shippingCost,

        // Totals
        'subtotal': subtotal,
        'total': grandTotal,

        // Biteship delivery info
        'biteshipCourierCode': _selectedBiteshipRate?.courierId ?? '',
        'biteshipServiceCode': _selectedBiteshipRate?.courierServiceCode ?? '',
        'biteshipCourierName': _selectedBiteshipRate?.courierName ?? '',
        'biteshipServiceName': _selectedBiteshipRate?.serviceName ?? '',
        'destinationAreaId': _selectedDestinationArea?.id ?? '',

        // Status
        'status': 'Pending',
        'stockUpdated': true,
      };

      final itemsToUpdate = _cartProvider.items
          .map((item) => {'productId': item.productId, 'quantity': item.quantity})
          .toList();

      await _firestoreService.placeOrderInTransaction(newOrderId, orderData, itemsToUpdate);

      _lastOrderId = newOrderId;

      await _cartProvider.clearCart();

      return null; // Success

    } catch (e) {
      developer.log('Error processing order', name: 'CheckoutProvider', error: e);
      return e.toString();
    } finally {
      _isProcessingOrder = false;
      notifyListeners();
    }
  }

  // ─── Hitung ongkir instan (GoSend/Grab) ─────────────────────────
  Future<void> fetchInstantShippingRates({
    required DeliveryLocation origin,
    required DeliveryLocation destination,
  }) async {
    _isLoadingRates = true;
    _ratesErrorMessage = null;
    notifyListeners();

    try {
      _instantRates = await _deliveryService.getShippingRates(
        origin: origin,
        destination: destination,
        weightKg: 1.0,
      );
    } on DeliveryException catch (e) {
      _ratesErrorMessage = e.message;
      _instantRates = [];
    } finally {
      _isLoadingRates = false;
      notifyListeners();
    }
  }

  // ─── Pilih tarif instan ─────────────────────────────────────────
  void selectInstantRate(ShippingRate? rate) {
    _selectedInstantRate = rate;
    // Nonaktifkan opsi shipping manual jika instant dipilih
    if (rate != null) {
      _selectedShipping = null;
    }
    notifyListeners();
  }

  // ─── Buat transaksi Midtrans ────────────────────────────────────
  Future<String?> createMidtransPayment(String orderId) async {
    _isCreatingPayment = true;
    notifyListeners();

    try {
      final result = await _paymentService.createTransaction(orderId);
      _midtransToken = result.token;
      _midtransRedirectUrl = result.redirectUrl;
      notifyListeners();
      return null; // null = sukses
    } on PaymentException catch (e) {
      return e.message; // return pesan error
    } finally {
      _isCreatingPayment = false;
      notifyListeners();
    }
  }

  // ─── Booking driver setelah order dibuat ───────────────────────
  Future<String?> bookDriver({
    required String orderId,
    required DeliveryLocation origin,
    required DeliveryLocation destination,
    required PackageInfo packageInfo,
  }) async {
    if (_selectedInstantRate == null) return 'Pilih layanan pengiriman terlebih dahulu.';

    try {
      await _deliveryService.bookDelivery(
        orderId: orderId,
        provider: _selectedInstantRate!.provider,
        serviceType: _selectedInstantRate!.serviceType,
        origin: origin,
        destination: destination,
        packageInfo: packageInfo,
      );
      return null; // sukses
    } on DeliveryException catch (e) {
      return e.message;
    }
  }

  // ─── Biteship: Area dipilih ──────────────────────────────────────
  /// Dipanggil saat user memilih area dari BiteshipAreaSearchField
  void onDestinationAreaSelected(BiteshipArea area) {
    _selectedDestinationArea = area;
    _selectedBiteshipRate = null;
    _biteshipRates = [];
    notifyListeners();
    // Langsung fetch rates
    fetchBiteshipRates();
  }

  // ─── Biteship: Fetch tarif ──────────────────────────────────────
  /// Fetch tarif kurir dari Biteship berdasarkan area yang sudah dipilih
  Future<void> fetchBiteshipRates() async {
    if (_selectedDestinationArea == null || _cartProvider.items.isEmpty) return;

    _isLoadingBiteshipRates = true;
    _biteshipRatesError = null;
    notifyListeners();

    // Konversi cart items ke ShipmentItem
    final shipmentItems = _cartProvider.items.map((item) => ShipmentItem(
      productId: item.productId,
      name: item.nama,
      price: item.harga,
      quantity: item.quantity,
      weightGram: 200, // default 200g; idealnya ambil dari data produk
    )).toList();

    try {
      _biteshipRates = await _biteshipService.getRates(
        destinationAreaId: _selectedDestinationArea!.id,
        destinationAddress: _deliveryInfo.address,
        items: shipmentItems,
      );
    } on BiteshipException catch (e) {
      _biteshipRatesError = e.message;
      _biteshipRates = [];
    } finally {
      _isLoadingBiteshipRates = false;
      notifyListeners();
    }
  }

  // ─── Biteship: Pilih tarif ──────────────────────────────────────
  /// Dipanggil saat user memilih salah satu tarif di BiteshipRatesWidget
  void selectBiteshipRate(BiteshipRate rate) {
    _selectedBiteshipRate = rate;
    // Simpan info kurir ke dalam shipping info (untuk disimpan ke Firestore)
    _selectedShipping = null; // nonaktifkan opsi lain
    notifyListeners();
  }
}
