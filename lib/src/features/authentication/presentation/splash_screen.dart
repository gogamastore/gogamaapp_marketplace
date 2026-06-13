import 'package:flutter/material.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // Atur warna latar belakang jika perlu
      body: Center(
        child: Image.asset(
          'assets/images/splash-animation.gif',
          // Anda bisa mengatur lebar atau tinggi jika perlu
          // width: 250,
        ),
      ),
    );
  }
}
