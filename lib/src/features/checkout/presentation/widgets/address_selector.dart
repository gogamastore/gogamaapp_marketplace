import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../profile/domain/address.dart';
import '../../application/checkout_provider.dart';

class AddressSelector extends StatefulWidget {
  const AddressSelector({super.key});

  @override
  State<AddressSelector> createState() => _AddressSelectorState();
}

class _AddressSelectorState extends State<AddressSelector> {

  @override
  void initState() {
    super.initState();
    // Auto-select the default or first address after the widget is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final checkoutProvider = context.read<CheckoutProvider>();
      if (checkoutProvider.selectedAddress == null && checkoutProvider.userAddresses.isNotEmpty) {
        final addresses = checkoutProvider.userAddresses;
        final Address addressToSelect = addresses.firstWhere((a) => a.isDefault, orElse: () => addresses.first);
        checkoutProvider.selectSavedAddress(addressToSelect);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final checkoutProvider = context.watch<CheckoutProvider>();
    final addresses = checkoutProvider.userAddresses;

    if (addresses.isEmpty) {
      return const SizedBox.shrink(); // Render nothing if no addresses are available
    }

    // Ensure the current selection in the dropdown is a valid object from the list
    Address? currentSelection;
    if (checkoutProvider.selectedAddress != null) {
      final selectedId = checkoutProvider.selectedAddress!.id;
      currentSelection = addresses.any((a) => a.id == selectedId)
          ? addresses.firstWhere((a) => a.id == selectedId)
          : null;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<Address>(
          initialValue: currentSelection,
          hint: const Text('Pilih dari alamat Anda'),
          isExpanded: true,
          onChanged: (Address? newValue) {
            if (newValue != null) {
              checkoutProvider.selectSavedAddress(newValue);
            }
          },
          items: addresses.map<DropdownMenuItem<Address>>((Address address) {
            return DropdownMenuItem<Address>(
              value: address,
              child: Text(
                '${address.name} - ${address.address}, ${address.city}',
                overflow: TextOverflow.ellipsis,
              ),
            );
          }).toList(),
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            suffixIcon: checkoutProvider.selectedAddress != null
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 20),
                    onPressed: () => checkoutProvider.clearSelectedAddress(),
                  )
                : null,
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}
