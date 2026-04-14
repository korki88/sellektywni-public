import 'package:flutter/material.dart';

import '../../staff/staff_models.dart';
import '../../theme/design_tokens.dart';

class AiProposalsView extends StatelessWidget {
  const AiProposalsView({
    super.key,
    required this.isOwner,
    required this.loading,
    required this.runningAnalysis,
    required this.proposals,
    required this.onRunAnalysis,
    required this.onRefresh,
    required this.onApprove,
    required this.onReject,
  });

  final bool isOwner;
  final bool loading;
  final bool runningAnalysis;
  final List<FinancialAiProposal> proposals;
  final VoidCallback onRunAnalysis;
  final VoidCallback onRefresh;
  final ValueChanged<FinancialAiProposal> onApprove;
  final ValueChanged<FinancialAiProposal> onReject;

  @override
  Widget build(BuildContext context) {
    if (!isOwner) {
      return Center(
        child: Text(
          'Sekcja dostępna tylko dla OWNER.',
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(color: DesignTokens.mutedText),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Agenci AI · Profit Guard',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        Text(
          'Agent Profit Guard analizuje ryzyko płynności i proponuje obniżki cen dla produktów wymagających przyspieszonej rotacji.',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: DesignTokens.mutedText),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            FilledButton.icon(
              onPressed: runningAnalysis ? null : onRunAnalysis,
              icon: runningAnalysis
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.auto_graph_outlined),
              label: Text(
                runningAnalysis ? 'Analizowanie...' : 'Uruchom analizę',
              ),
            ),
            const SizedBox(width: 10),
            FilledButton.tonal(
              onPressed: onRefresh,
              child: const Text('Odśwież propozycje'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (loading)
          const Center(child: CircularProgressIndicator())
        else if (proposals.isEmpty)
          Text(
            'Brak aktywnych propozycji Profit Guard.',
            style: Theme.of(context).textTheme.bodyMedium,
          )
        else
          ...proposals.map(
            (p) => Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.productName ?? p.productId ?? 'Produkt',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Risk score: ${p.riskScore} · '
                      'Cena: ${p.currentPriceRaw} zł -> ${p.suggestedPriceRaw} zł '
                      '(-${p.discountPercentRaw}%)',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (p.supplierName != null ||
                        p.paymentTermsDays != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Dostawca: ${p.supplierName ?? "—"} · '
                        'Termin płatności: ${p.paymentTermsDays?.toString() ?? "—"} dni',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: DesignTokens.mutedText,
                            ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      p.rationale,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: DesignTokens.mutedText,
                          ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton(
                          onPressed: () => onReject(p),
                          child: const Text('Odrzuć'),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: () => onApprove(p),
                          child: const Text('Zatwierdź'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
