import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../application/address_provider.dart';
import '../domain/address.dart';
import '../../../core/widgets/gogama_button.dart';

class AddressScreen extends StatelessWidget {
  const AddressScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pengaturan Alamat'),
        centerTitle: true,
      ),
      body: Consumer<AddressProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.addresses.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Anda belum memiliki alamat tersimpan.'),
                  const SizedBox(height: 20),
                  GogamaButton(
                    label: 'Tambah Alamat Baru',
                    onPressed: () => context.push('/profile/address/add'),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: provider.addresses.length,
            itemBuilder: (context, index) {
              final address = provider.addresses[index];
              return AddressCard(address: address);
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/profile/address/add'),
        label: const Text('Tambah Alamat'),
        icon: const Icon(Icons.add),
      ),
    );
  }
}

class AddressCard extends StatelessWidget {
  final Address address;
  const AddressCard({super.key, required this.address});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 16.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(address.label, style: textTheme.titleLarge),
                if (address.isDefault)
                  Chip(
                    label: const Text('Default'),
                    backgroundColor: colorScheme.primaryContainer,
                    labelStyle: TextStyle(color: colorScheme.onPrimaryContainer),
                    padding: EdgeInsets.zero,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(address.name, style: textTheme.bodyLarge),
            Text(address.phone, style: textTheme.bodyMedium),
            const SizedBox(height: 4),
            Text(address.address, style: textTheme.bodyMedium),
            Text('${address.city}, ${address.province} ${address.postalCode}', style: textTheme.bodyMedium),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () {
                    context.push('/profile/address/edit', extra: address);
                  },
                  child: const Text('Ubah'),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () => _showDeleteConfirmation(context, address.id),
                  child: Text('Hapus', style: TextStyle(color: colorScheme.error)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, String addressId) {
    showDialog(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          title: const Text('Hapus Alamat'),
          content: const Text('Apakah Anda yakin ingin menghapus alamat ini?'),
          actions: [
            TextButton(
              child: const Text('Batal'),
              onPressed: () => Navigator.of(ctx).pop(),
            ),
            TextButton(
              child: Text('Hapus', style: TextStyle(color: Theme.of(context).colorScheme.error)),
              onPressed: () {
                context.read<AddressProvider>().deleteAddress(addressId);
                Navigator.of(ctx).pop();
              },
            ),
          ],
        );
      },
    );
  }
}
