import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'src/core/navigation/router.dart';
import 'src/features/cart/application/cart_provider.dart';
import 'src/features/authentication/data/auth_service.dart';
import 'src/core/data/firestore_service.dart';
import 'src/core/theme/theme_provider.dart';
import 'src/features/profile/application/address_provider.dart';
import 'src/features/authentication/presentation/splash_screen.dart';
import 'src/features/products/application/promotion_provider.dart'; // Impor baru

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AppInitializer());
}

class AppInitializer extends StatefulWidget {
  const AppInitializer({super.key});

  @override
  AppInitializerState createState() => AppInitializerState();
}

class AppInitializerState extends State<AppInitializer> {
  late final Future<AuthService> _initialization;

  @override
  void initState() {
    super.initState();
    _initialization = _initializeServices();
  }

  Future<AuthService> _initializeServices() async {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    final authService = AuthService();
    await authService.isReady;
    return authService;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AuthService>(
      future: _initialization,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return MaterialApp(
            home: Scaffold(
              body: Center(
                child: Text('Error initializing app: ${snapshot.error}'),
              ),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.done) {
          return MyApp(authService: snapshot.data!);
        }

        return const MaterialApp(
          home: SplashScreen(),
        );
      },
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, required this.authService});

  final AuthService authService;

  @override
  Widget build(BuildContext context) {
    final appRouter = AppRouter(authService);

    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthService>.value(value: authService),
        Provider<FirestoreService>(create: (_) => FirestoreService()),
        // --- PENAMBAHAN PROVIDER PROMOSI ---
        ChangeNotifierProvider<PromotionProvider>(
          create: (context) => PromotionProvider(context.read<FirestoreService>()),
        ),
        ChangeNotifierProxyProvider<AuthService, CartProvider>(
          create: (context) => CartProvider(
            context.read<FirestoreService>(),
            context.read<AuthService>(),
          ),
          update: (context, auth, previousCart) =>
              previousCart ?? CartProvider(context.read<FirestoreService>(), auth),
        ),
        ChangeNotifierProxyProvider<AuthService, AddressProvider>(
          create: (context) => AddressProvider(
            firestoreService: context.read<FirestoreService>(),
            authService: context.read<AuthService>(),
          ),
          update: (context, auth, previousProvider) =>
              previousProvider ??
              AddressProvider(
                  firestoreService: context.read<FirestoreService>(),
                  authService: auth),
        ),
      ],
      child: MaterialApp.router(
        routerConfig: appRouter.router,
        title: 'Gogama Store',
        theme: ThemeProvider.lightTheme,
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
