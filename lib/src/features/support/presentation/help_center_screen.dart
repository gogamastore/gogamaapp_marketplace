import 'package:flutter/material.dart';

class FaqItem {
  const FaqItem({required this.question, required this.answer});
  final String question;
  final String answer;
}

class HelpCenterScreen extends StatelessWidget {
  const HelpCenterScreen({super.key});

  final List<FaqItem> faqData = const [
    FaqItem(
        question: 'Bagaimana cara menjadi reseller?',
        answer:
            'Untuk menjadi reseller, silakan daftar melalui aplikasi dengan memilih opsi "Daftar sebagai Reseller". Isi formulir pendaftaran dengan lengkap dan tunggu verifikasi dari tim kami. Setelah disetujui, Anda dapat mulai menjual produk dengan mendapatkan komisi dari setiap penjualan.'),
    FaqItem(
        question: 'Bagaimana cara melacak pesanan saya?',
        answer:
            'Anda dapat melacak pesanan melalui menu "Riwayat Pesanan" di profil Anda. Setiap pesanan akan menampilkan status terkini mulai dari konfirmasi, proses, pengiriman, hingga sampai tujuan. Anda juga akan mendapat notifikasi untuk setiap perubahan status pesanan.'),
    FaqItem(
        question: 'Berapa lama waktu pengiriman?',
        answer:
            'Waktu pengiriman bervariasi tergantung lokasi Anda dan metode pengiriman yang dipilih. Estimasi waktu pengiriman akan ditampilkan saat proses checkout.'),
    FaqItem(
        question: 'Bagaimana cara melakukan pengembalian produk?',
        answer:
            'Untuk pengembalian produk:\n\n1. Hubungi customer service dalam 7 hari setelah produk diterima\n2. Produk masih dalam kondisi asli dan belum digunakan\n3. Sertakan bukti pembelian dan foto produk\n4. Tim kami akan memverifikasi dan memberikan instruksi lebih lanjut\n\nBiaya return ditanggung pembeli kecuali produk cacat/salah kirim.'),
    FaqItem(
        question: 'Apakah ada garansi untuk produk?',
        answer:
            'Garansi produk bervariasi tergantung jenis dan brand:\n\n• Elektronik: Garansi resmi dari distributor/brand\n• Fashion: Garansi kualitas 7 hari\n• Kosmetik: Garansi original dan tanggal expired\n\nDetail garansi dapat dilihat di deskripsi produk atau hubungi customer service.'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pusat Bantuan'),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(8.0),
        itemCount: faqData.length,
        itemBuilder: (context, index) {
          final item = faqData[index];
          return Card(
            margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
            child: ExpansionTile(
              title: Text(item.question, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 16)),
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(item.answer),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
