import 'dart:convert';

import 'package:flutter/material.dart';

import '../../staff/staff_models.dart';
import '../../theme/design_tokens.dart';

enum AuditQuickFilter { all, errors, sales, loyalty }

class AuditLogView extends StatefulWidget {
  const AuditLogView({
    super.key,
    required this.loadingAuditLogs,
    required this.auditRows,
    required this.auditTotal,
    required this.auditHasMore,
    required this.loadingMoreAuditLogs,
    required this.userFilterController,
    required this.actionFilterController,
    required this.resourceTypeFilterController,
    required this.onFilter,
    required this.onLoadMore,
  });

  final bool loadingAuditLogs;
  final List<StaffAuditLog> auditRows;
  final int auditTotal;
  final bool auditHasMore;
  final bool loadingMoreAuditLogs;
  final TextEditingController userFilterController;
  final TextEditingController actionFilterController;
  final TextEditingController resourceTypeFilterController;
  final VoidCallback onFilter;
  final VoidCallback onLoadMore;

  @override
  State<AuditLogView> createState() => _AuditLogViewState();
}

class _AuditLogViewState extends State<AuditLogView> {
  AuditQuickFilter _quickFilter = AuditQuickFilter.all;

  String _formatAuditDate(String raw) {
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;
    final dt = parsed.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${dt.year}-${two(dt.month)}-${two(dt.day)} ${two(dt.hour)}:${two(dt.minute)}:${two(dt.second)}';
  }

  bool _isAuditErrorAction(String action) {
    const exact = {'REJECT_ORDER', 'LOGIN_FAILURE', 'DELETE_RESOURCE'};
    final normalized = action.trim().toUpperCase();
    return exact.contains(normalized) ||
        normalized.contains('FAIL') ||
        normalized.contains('REJECT') ||
        normalized.contains('ERROR');
  }

  bool _isAuditSalesAction(String action) {
    final normalized = action.trim().toUpperCase();
    return normalized.contains('ORDER') ||
        normalized.contains('SALE') ||
        normalized.contains('PROMO') ||
        normalized.contains('SYNC_POS');
  }

  bool _isAuditLoyaltyAction(String action) {
    final normalized = action.trim().toUpperCase();
    return normalized.contains('POINT') ||
        normalized.contains('RANK') ||
        normalized.contains('VINTAGE') ||
        normalized.contains('LOYAL');
  }

  ({Color fg, Color bg}) _auditActionPalette(String action) {
    const greenActions = {'APPROVE_ORDER', 'LOGIN_SUCCESS', 'POINTS_ADDED'};
    const redActions = {'REJECT_ORDER', 'LOGIN_FAILURE', 'DELETE_RESOURCE'};
    const goldActions = {
      'CHANGE_RANK',
      'VINTAGE_STATUS_ASSIGNED',
      'PROMO_ACTIVATED',
    };
    const blueActions = {'AI_PROPOSAL_GENERATED', 'SYNC_POS'};
    final normalized = action.trim().toUpperCase();
    if (greenActions.contains(normalized)) {
      return (fg: const Color(0xFF1B5E20), bg: DesignTokens.successSoft);
    }
    if (redActions.contains(normalized)) {
      return (fg: DesignTokens.error, bg: DesignTokens.dangerSoft);
    }
    if (goldActions.contains(normalized)) {
      return (fg: const Color(0xFF8A6D00), bg: DesignTokens.accentSoft);
    }
    if (blueActions.contains(normalized)) {
      return (fg: const Color(0xFF0D47A1), bg: DesignTokens.infoSoft);
    }
    return (fg: DesignTokens.ink, bg: DesignTokens.panelSoft);
  }

  String _formatAuditJson(Object? value) {
    if (value == null) return 'Brak danych.';
    try {
      return const JsonEncoder.withIndent('  ').convert(value);
    } catch (_) {
      return value.toString();
    }
  }

  Future<void> _showAuditDetails(StaffAuditLog row) async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Szczegóły: ${row.action}'),
          content: SizedBox(
            width: 680,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Kto: ${row.userEmail.isNotEmpty ? row.userEmail : row.userId}',
                  ),
                  const SizedBox(height: 8),
                  Text('Obiekt: ${row.resourceType}:${row.resourceId}'),
                  const SizedBox(height: 8),
                  Text('IP: ${row.ipAddress ?? "—"}'),
                  const SizedBox(height: 8),
                  Text('Data: ${_formatAuditDate(row.createdAt)}'),
                  const SizedBox(height: 14),
                  Text('oldValue',
                      style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: DesignTokens.subtleFill,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: DesignTokens.line),
                    ),
                    child: SelectableText(_formatAuditJson(row.oldValue)),
                  ),
                  const SizedBox(height: 12),
                  Text('newValue',
                      style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: DesignTokens.subtleFill,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: DesignTokens.line),
                    ),
                    child: SelectableText(_formatAuditJson(row.newValue)),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Zamknij'),
            ),
          ],
        );
      },
    );
  }

  List<StaffAuditLog> _filteredAuditRows() {
    switch (_quickFilter) {
      case AuditQuickFilter.all:
        return widget.auditRows;
      case AuditQuickFilter.errors:
        return widget.auditRows
            .where((row) => _isAuditErrorAction(row.action))
            .toList();
      case AuditQuickFilter.sales:
        return widget.auditRows
            .where((row) => _isAuditSalesAction(row.action))
            .toList();
      case AuditQuickFilter.loyalty:
        return widget.auditRows
            .where((row) => _isAuditLoyaltyAction(row.action))
            .toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.loadingAuditLogs) {
      return const Center(child: CircularProgressIndicator());
    }
    final rows = _filteredAuditRows();
    final mobileLayout = MediaQuery.sizeOf(context).width < 900;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Dziennik aktywności (tylko Owner Dashboard).',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: DesignTokens.mutedText),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              label: const Text('Wszystkie'),
              selected: _quickFilter == AuditQuickFilter.all,
              onSelected: (_) =>
                  setState(() => _quickFilter = AuditQuickFilter.all),
            ),
            ChoiceChip(
              label: const Text('Tylko Błędy'),
              selected: _quickFilter == AuditQuickFilter.errors,
              onSelected: (_) =>
                  setState(() => _quickFilter = AuditQuickFilter.errors),
            ),
            ChoiceChip(
              label: const Text('Tylko Sprzedaż'),
              selected: _quickFilter == AuditQuickFilter.sales,
              onSelected: (_) =>
                  setState(() => _quickFilter = AuditQuickFilter.sales),
            ),
            ChoiceChip(
              label: const Text('Tylko Lojalność'),
              selected: _quickFilter == AuditQuickFilter.loyalty,
              onSelected: (_) =>
                  setState(() => _quickFilter = AuditQuickFilter.loyalty),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            SizedBox(
              width: 320,
              child: TextField(
                controller: widget.userFilterController,
                decoration: const InputDecoration(
                  labelText: 'Kto (email)',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) => widget.onFilter(),
              ),
            ),
            SizedBox(
              width: 360,
              child: TextField(
                controller: widget.actionFilterController,
                decoration: const InputDecoration(
                  labelText: 'Akcja (np. CHANGE_ORDER_STATUS)',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) => widget.onFilter(),
              ),
            ),
            SizedBox(
              width: 260,
              child: TextField(
                controller: widget.resourceTypeFilterController,
                decoration: const InputDecoration(
                  labelText: 'Obiekt (ORDER, PRODUCT...)',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) => widget.onFilter(),
              ),
            ),
            FilledButton.tonal(
              onPressed: widget.onFilter,
              child: const Text('Filtruj'),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          'Wyniki: ${rows.length} / ${widget.auditTotal}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        if (rows.isEmpty)
          Text(
            'Brak wpisów dla wybranego filtra.',
            style: Theme.of(context).textTheme.bodyMedium,
          )
        else if (mobileLayout)
          SizedBox(
            height: 560,
            child: ListView.separated(
              itemCount: rows.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final row = rows[i];
                final palette = _auditActionPalette(row.action);
                return Card(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => _showAuditDetails(row),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  row.userEmail.isNotEmpty
                                      ? row.userEmail
                                      : row.userId,
                                  style: Theme.of(context).textTheme.titleSmall,
                                ),
                              ),
                              Chip(
                                label: Text(
                                  row.action,
                                  style: TextStyle(
                                    color: palette.fg,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                backgroundColor: palette.bg,
                                side: BorderSide(color: palette.bg),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text('Obiekt: ${row.resourceType}:${row.resourceId}'),
                          const SizedBox(height: 4),
                          Text(
                            _formatAuditDate(row.createdAt),
                            style: Theme.of(
                              context,
                            ).textTheme.bodySmall?.copyWith(
                                  color: DesignTokens.mutedText,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          )
        else
          SizedBox(
            height: 520,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Kto')),
                  DataColumn(label: Text('Akcja')),
                  DataColumn(label: Text('Obiekt')),
                  DataColumn(label: Text('Data')),
                ],
                rows: rows
                    .map(
                      (row) => DataRow(
                        onSelectChanged: (_) => _showAuditDetails(row),
                        cells: [
                          DataCell(
                            Text(
                              row.userEmail.isNotEmpty
                                  ? row.userEmail
                                  : row.userId,
                            ),
                          ),
                          DataCell(
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: _auditActionPalette(row.action).bg,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                row.action,
                                style: TextStyle(
                                  color: _auditActionPalette(row.action).fg,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          DataCell(
                              Text('${row.resourceType}:${row.resourceId}')),
                          DataCell(Text(_formatAuditDate(row.createdAt))),
                        ],
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
        const SizedBox(height: 12),
        if (widget.loadingMoreAuditLogs)
          const Center(child: CircularProgressIndicator())
        else if (widget.auditHasMore)
          Center(
            child: FilledButton.tonal(
              onPressed: widget.onLoadMore,
              child: const Text('Wczytaj więcej'),
            ),
          ),
      ],
    );
  }
}
