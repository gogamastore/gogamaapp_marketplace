import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import '../application/address_provider.dart';
import '../domain/address.dart';
import '../../../core/widgets/gogama_button.dart';

class AddEditAddressScreen extends StatefulWidget {
  final Address? address;
  const AddEditAddressScreen({super.key, this.address});

  @override
  State<AddEditAddressScreen> createState() => _AddEditAddressScreenState();
}

class _AddEditAddressScreenState extends State<AddEditAddressScreen> {
  final _formKey = GlobalKey<FormState>();
  late String _label, _name, _phone, _address, _city, _province, _postalCode;
  late bool _isDefault;
  bool _isLoading = false;

  bool get _isEditing => widget.address != null;

  @override
  void initState() {
    super.initState();
    _label = widget.address?.label ?? '';
    _name = widget.address?.name ?? '';
    _phone = widget.address?.phone ?? '';
    _address = widget.address?.address ?? '';
    _city = widget.address?.city ?? '';
    _province = widget.address?.province ?? '';
    _postalCode = widget.address?.postalCode ?? '';
    _isDefault = widget.address?.isDefault ?? false;
  }

  Future<void> _submit() async {
    if (_formKey.currentState?.validate() ?? false) {
      _formKey.currentState!.save();
      setState(() => _isLoading = true);

      final addressProvider = context.read<AddressProvider>();
      final messenger = ScaffoldMessenger.of(context);
      final router = GoRouter.of(context);

      final newAddress = Address(
        id: _isEditing ? widget.address!.id : '',
        label: _label,
        name: _name,
        phone: _phone,
        address: _address,
        city: _city,
        province: _province,
        postalCode: _postalCode,
        isDefault: _isDefault,
      );

      try {
        if (_isEditing) {
          await addressProvider.updateAddress(newAddress);
        } else {
          await addressProvider.addAddress(newAddress);
        }

        if (mounted) {
          router.pop();
        }

      } catch (e) {
         if (mounted) {
          messenger.showSnackBar(
            SnackBar(content: Text('Gagal menyimpan alamat: $e')),
          );
        }
      } finally {
         if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Ubah Alamat' : 'Tambah Alamat'),
        centerTitle: true,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            TextFormField(
              initialValue: _label,
              decoration: const InputDecoration(labelText: 'Label Alamat (Contoh: Rumah, Kantor)'),
              onSaved: (value) => _label = value ?? '',
              validator: (value) => (value == null || value.isEmpty) ? 'Label tidak boleh kosong' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              initialValue: _name,
              decoration: const InputDecoration(labelText: 'Nama Penerima'),
              onSaved: (value) => _name = value ?? '',
              validator: (value) => (value == null || value.isEmpty) ? 'Nama tidak boleh kosong' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              initialValue: _phone,
              decoration: const InputDecoration(labelText: 'Nomor Telepon'),
              keyboardType: TextInputType.phone,
              onSaved: (value) => _phone = value ?? '',
              validator: (value) => (value == null || value.isEmpty) ? 'Nomor telepon tidak boleh kosong' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              initialValue: _address,
              decoration: const InputDecoration(labelText: 'Alamat Lengkap'),
              onSaved: (value) => _address = value ?? '',
              validator: (value) => (value == null || value.isEmpty) ? 'Alamat tidak boleh kosong' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              initialValue: _city,
              decoration: const InputDecoration(labelText: 'Kota'),
              onSaved: (value) => _city = value ?? '',
              validator: (value) => (value == null || value.isEmpty) ? 'Kota tidak boleh kosong' : null,
            ),
            const SizedBox(height: 16),
             TextFormField(
              initialValue: _province,
              decoration: const InputDecoration(labelText: 'Provinsi'),
              onSaved: (value) => _province = value ?? '',
              validator: (value) => (value == null || value.isEmpty) ? 'Provinsi tidak boleh kosong' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              initialValue: _postalCode,
              decoration: const InputDecoration(labelText: 'Kode Pos'),
              keyboardType: TextInputType.number,
              onSaved: (value) => _postalCode = value ?? '',
              validator: (value) => (value == null || value.isEmpty) ? 'Kode pos tidak boleh kosong' : null,
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Jadikan Alamat Utama'),
              value: _isDefault,
              onChanged: (bool value) {
                setState(() {
                  _isDefault = value;
                });
              },
            ),
            const SizedBox(height: 32),
            GogamaButton(
              label: 'Simpan Alamat',
              onPressed: _submit,
              isLoading: _isLoading,
            ),
          ],
        ),
      ),
    );
  }
}
