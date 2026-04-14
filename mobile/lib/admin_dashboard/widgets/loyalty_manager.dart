import 'package:flutter/material.dart';

import '../../staff/staff_models.dart';
import '../../theme/design_tokens.dart';

class LoyaltyManager extends StatelessWidget {
  const LoyaltyManager({
    super.key,
    required this.loadingCustomer,
    required this.customer,
    required this.buildCustomerCard,
  });

  final bool loadingCustomer;
  final StaffCustomerProfile? customer;
  final Widget Function(StaffCustomerProfile customer) buildCustomerCard;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: ListView(
        children: [
          Text(
            'Program lojalnościowy — profil po skanie QR.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: DesignTokens.mutedText),
          ),
          const SizedBox(height: 16),
          if (loadingCustomer)
            const Center(child: CircularProgressIndicator())
          else if (customer == null)
            Text(
              'Brak klienta — użyj zakładki Skaner lub zeskanuj kod (HID).',
              style: Theme.of(context).textTheme.bodyLarge,
            )
          else
            buildCustomerCard(customer!),
        ],
      ),
    );
  }
}
