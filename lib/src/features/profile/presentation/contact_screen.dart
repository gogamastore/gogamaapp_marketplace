import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class ContactScreen extends StatelessWidget {
  const ContactScreen({super.key});

  Future<void> _launchURL(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      // throw 'Could not launch $url';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Hubungi Kami', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF075664), Color(0xFF2aadc4)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            children: [
              _buildSectionHeader('Akun Official Kami'),
              ContactInfoTile(
                icon: FontAwesomeIcons.instagram,
                text: 'manafidh_kosmetik',
                url: 'https://www.instagram.com/manafidh_kosmetik/',
                onTap: () => _launchURL('https://www.instagram.com/manafidh_kosmetik/'),
              ),
              ContactInfoTile(
                icon: FontAwesomeIcons.globe,
                text: 'www.gogama.store',
                url: 'https://www.gogama.store/',
                onTap: () => _launchURL('https://www.gogama.store/'),
              ),
              ContactInfoTile(
                icon: FontAwesomeIcons.tiktok,
                text: 'Gallery Makassar',
                url: 'https://www.tiktok.com/@gallery.makassar',
                onTap: () => _launchURL('https://www.tiktok.com/@gallery.makassar'),
              ),
               ContactInfoTile(
                icon: FontAwesomeIcons.shoppingBag,
                text: 'manafidh_kosmetik',
                url: 'https://shope.ee/6Kbmbbr5pA',
                onTap: () => _launchURL('https://shope.ee/6Kbmbbr5pA'),
              ),
              const SizedBox(height: 20),
              _buildSectionHeader('Hubungi Kami Untuk Join Grosir'),
              ContactInfoTile(
                icon: FontAwesomeIcons.whatsapp,
                text: 'WA Komplain Shopee',
                url: 'http://wa.me/6289506991107',
                onTap: () => _launchURL('http://wa.me/6289506991107'),
              ),
              ContactInfoTile(
                icon: FontAwesomeIcons.whatsapp,
                text: 'Admin Grosir 1',
                url: 'http://wa.me/6288705707321',
                onTap: () => _launchURL('http://wa.me/6288705707321'),
              ),
               ContactInfoTile(
                icon: FontAwesomeIcons.whatsapp,
                text: 'Admin Grosir 2',
                url: 'http://wa.me/6289503674236',
                onTap: () => _launchURL('http://wa.me/6289503674236'),
              ),
               ContactInfoTile(
                icon: FontAwesomeIcons.whatsapp,
                text: 'WA Lowongan Kerja',
                url: 'http://wa.me/6289636052501',
                onTap: () => _launchURL('http://wa.me/6289636052501'),
              ),
              const SizedBox(height: 20),
               _buildSectionHeader('Offline Store'),
              ContactInfoTile(
                icon: FontAwesomeIcons.mapMarkedAlt,
                text: 'Maps: Gallery Makassar',
                url: 'https://maps.app.goo.gl/BQmTCJBcVRaeU7wi9',
                onTap: () => _launchURL('https://maps.app.goo.gl/BQmTCJBcVRaeU7wi9'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8.0, bottom: 15, top: 15),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
          letterSpacing: -0.5,
        ),
      ),
    );
  }
}

class ContactInfoTile extends StatelessWidget {
  final FaIconData icon;
  final String text;
  final String url;
  final VoidCallback onTap;

  const ContactInfoTile({
    super.key,
    required this.icon,
    required this.text,
    required this.url,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      shadowColor: Colors.black45,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 18),
          child: Row(
            children: [
              FaIcon(icon, size: 24, color: const Color(0xFF075664)),
              const SizedBox(width: 20),
              Expanded(
                child: Text(
                  text,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Color(0xFF211B21),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
