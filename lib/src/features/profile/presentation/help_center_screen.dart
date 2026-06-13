import 'package:flutter/material.dart';

class HelpCenterScreen extends StatelessWidget {
  const HelpCenterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kebijakan Privasi & FAQ'),
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildPrivacyPolicyCard(context, textTheme),
          const SizedBox(height: 24),
          _buildFaqCard(textTheme),
        ],
      ),
    );
  }

  Widget _buildPrivacyPolicyCard(BuildContext context, TextTheme textTheme) {
    return Card(
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.shield_outlined, color: Theme.of(context).primaryColor, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Kebijakan Privasi – Gogama.Store',
                    style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Terakhir diperbarui: 27 September 2025',
              style: textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
            ),
            const Divider(height: 32),
            _buildPolicySection(
              '1. Pendahuluan',
              'Selamat datang di Gogama.Store. Kami menghargai privasi Anda dan berkomitmen untuk melindungi data pribadi yang Anda berikan saat menggunakan aplikasi ini. Kebijakan ini menjelaskan bagaimana kami mengumpulkan, menggunakan, dan melindungi informasi Anda.',
              textTheme,
            ),
            _buildPolicySection(
              '2. Informasi yang Kami Kumpulkan',
              'Kami dapat mengumpulkan data berikut:\n- Informasi Akun: Nama, alamat email, nomor telepon, dan alamat pengiriman.\n- Data Transaksi: Riwayat pembelian, metode pembayaran (hanya data transaksi, bukan detail kartu).\n- Data Teknis: Alamat IP, jenis perangkat, sistem operasi, dan aktivitas penggunaan aplikasi.\n- Konten yang Diberikan Pengguna: Ulasan, komentar, atau pesan yang dikirimkan ke kami.',
              textTheme,
            ),
            _buildPolicySection(
              '3. Penggunaan Informasi',
              'Data yang dikumpulkan digunakan untuk:\n- Memproses pesanan dan pengiriman.\n- Memberikan dukungan pelanggan.\n- Mengirimkan informasi promo, penawaran khusus, atau pembaruan produk.\n- Meningkatkan keamanan dan pengalaman pengguna di aplikasi.',
              textTheme,
            ),
            _buildPolicySection(
              '9. Kontak',
              'Jika Anda memiliki pertanyaan atau keluhan terkait kebijakan ini, silakan hubungi kami di:\n📧 official@gogama.store\n📱 +6289636052501',
              textTheme,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPolicySection(String title, String content, TextTheme textTheme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(
            content,
            style: textTheme.bodyMedium?.copyWith(color: Colors.grey[800], height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildFaqCard(TextTheme textTheme) {
    final faqs = [
      {
        'question': 'Bagaimana cara menjadi reseller?',
        'answer': 'Untuk menjadi reseller, Anda dapat menghubungi tim kami melalui WhatsApp di nomor yang tertera pada halaman "Hubungi Kami". Dapatkan harga spesial dan keuntungan lainnya!'
      },
      {
        'question': 'Bagaimana cara melacak pesanan saya?',
        'answer': 'Anda dapat melacak pesanan Anda melalui menu "Riwayat Pesanan" di halaman profil. Status pesanan akan diperbarui secara real-time.'
      },
      {
        'question': 'Berapa lama waktu pengiriman?',
        'answer': 'Waktu pengiriman bervariasi tergantung pada lokasi Anda. Estimasi waktu pengiriman akan ditampilkan saat Anda checkout.'
      },
      {
        'question': 'Apa saja metode pembayaran yang diterima?',
        'answer': 'Kami menerima berbagai metode pembayaran, termasuk transfer bank, kartu kredit/debit, dan dompet digital populer.'
      },
    ];

    return Card(
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pertanyaan yang Sering Diajukan (FAQ)',
              style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...faqs.map((faq) => ExpansionTile(
                  title: Text(faq['question']!, style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Text(
                        faq['answer']!,
                        style: textTheme.bodyMedium?.copyWith(color: Colors.grey[800], height: 1.5),
                      ),
                    ),
                  ],
                )),
          ],
        ),
      ),
    );
  }
}
