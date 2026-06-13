import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../authentication/data/auth_service.dart';

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Halaman Favorit',
              style: TextStyle(fontSize: 24.0),
            ),
            const SizedBox(height: 20.0),
            if (authService.currentUser != null)
              Text('UID Pengguna: ${authService.currentUser!.uid}'),
          ],
        ),
      ),
    );
  }
}
