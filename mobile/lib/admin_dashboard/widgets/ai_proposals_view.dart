import 'package:flutter/material.dart';

import '../../staff/staff_models.dart';
import '../../theme/design_tokens.dart';
import 'marketing_campaigns_view.dart';

class AiProposalsView extends StatelessWidget {
  const AiProposalsView({
    super.key,
    required this.isOwner,
    required this.loadingActive,
    required this.loadingHistory,
    required this.runningAnalysis,
    required this.activeProposals,
    required this.historyProposals,
    required this.acceptedThisMonth,
    required this.onRunAnalysis,
    required this.onRefresh,
    required this.onApprove,
    required this.onReject,
  });

  final bool isOwner;
  final bool loadingActive;
  final bool loadingHistory;
  final bool runningAnalysis;
  final List<FinancialAiProposal> activeProposals;
  final List<FinancialAiProposal> historyProposals;
  final int acceptedThisMonth;
  final VoidCallback onRunAnalysis;
  final VoidCallback onRefresh;
  final ValueChanged<FinancialAiProposal> onApprove;
  final ValueChanged<FinancialAiProposal> onReject;

  String _proposalDate(String raw) {
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;
    final local = parsed.toLocal();
    return '${local.year.toString().padLeft(4, '0')}-'
        '${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')} '
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }

  Color _statusColor(String status) {
    switch (status.toUpperCase()) {
      case 'ACCEPTED':
        return const Color(0xFF1B5E20);
      case 'REJECTED':
        return DesignTokens.error;
      default:
        return DesignTokens.mutedText;
    }
  }

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

    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Agenci AI · Profit Guard',
                  style: Theme.of(
                    context,
                  )
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                Text(
                  'Agent Profit Guard analizuje ryzyko płynności i proponuje obniżki cen dla produktów wymagających przyspieszonej rotacji.',
                  style: Theme.of(
                    context,
                  )
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: DesignTokens.mutedText),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        const Icon(Icons.insights_outlined),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'KPI (miesiąc bieżący): zaakceptowane rekomendacje',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                        Text(
                          '$acceptedThisMonth',
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
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
                      child: const Text('Odśwież sekcję AI'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const TabBar(
            tabs: [
              Tab(text: 'Aktywne'),
              Tab(text: 'Historia Rekomendacji'),
              Tab(text: 'Kampanie Marketingowe'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                if (loadingActive)
                  const Center(child: CircularProgressIndicator())
                else if (activeProposals.isEmpty)
                  Center(
                    child: Text(
                      'Brak aktywnych propozycji Profit Guard.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  )
                else
                  ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      ...activeProposals.map(
                        (p) => Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  p.productName ?? p.productId ?? 'Produkt',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w700),
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
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                            color: DesignTokens.mutedText),
                                  ),
                                ],
                                const SizedBox(height: 6),
                                Text(
                                  p.rationale,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(color: DesignTokens.mutedText),
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
                  ),
                if (loadingHistory)
                  const Center(child: CircularProgressIndicator())
                else if (historyProposals.isEmpty)
                  Center(
                    child: Text(
                      'Brak archiwalnych rekomendacji.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  )
                else
                  ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      ...historyProposals.map(
                        (p) => Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          child: ListTile(
                            title:
                                Text(p.productName ?? p.productId ?? 'Produkt'),
                            subtitle: Text(
                              'Status: ${p.status} · Data: ${_proposalDate(p.createdAt)}\n'
                              'Cena: ${p.currentPriceRaw} zł -> ${p.suggestedPriceRaw} zł',
                            ),
                            trailing: Chip(
                              label: Text(p.status),
                              side: BorderSide.none,
                              backgroundColor: _statusColor(p.status)
                                  .withValues(alpha: 0.15),
                              labelStyle: TextStyle(
                                color: _statusColor(p.status),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                const MarketingCampaignsView(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
