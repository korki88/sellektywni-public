import 'package:flutter/material.dart';

import '../../theme/design_tokens.dart';

class MarketingCampaignsView extends StatelessWidget {
  const MarketingCampaignsView({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Kampanie Marketingowe',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          'Placeholder pod kolejne iteracje. Tutaj dodamy harmonogram, status publikacji i KPI kampanii.',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: DesignTokens.mutedText),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              'TODO: widok kampanii AI (Hype Maker / Profit Guard) wraz z metrykami konwersji.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ),
      ],
    );
  }
}
