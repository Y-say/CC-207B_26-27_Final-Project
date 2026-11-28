import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../models/audit_record.dart';
import '../../../providers/audit_providers.dart';
import '../../../utils/app_failure.dart';
import '../../../widgets/common/async_view.dart';
import '../../../widgets/common/status_badge.dart';
import '../../../widgets/tablet/tablet_controls.dart';
import '../../../widgets/theme/app_colors.dart';
import '../../../widgets/theme/app_spacing.dart';
import 'audit_drawer.dart';
import 'audit_format.dart';

// The administrator's list of platform events (wireframe: table + search)
class AuditListScreen extends ConsumerStatefulWidget {
  const AuditListScreen({super.key, this.drawerInShell = false});

  /// When true, [AdminShellScreen] renders [AuditDrawer] in the frame's right panel.
  final bool drawerInShell;

  @override
  ConsumerState<AuditListScreen> createState() => _AuditListScreenState();
}

class _AuditListScreenState extends ConsumerState<AuditListScreen> {
  final _search = TextEditingController();
  String _typeFilter = 'all';

  static const _typeOptions = <(String, String)>[
    ('All types', 'all'),
    ('Sign-in', 'sign_in'),
    ('Failed sign-in', 'failed_sign_in'),
    ('Account security', 'account_security'),
    ('Pharmacy application', 'pharmacy_application'),
    ('Admin action', 'admin_action'),
    ('Data export', 'data_export'),
  ];

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<AuditRecord> _filtered(List<AuditRecord> all) {
    final q = _search.text.trim().toLowerCase();
    return all.where((item) {
      if (_typeFilter != 'all' && item.eventType != _typeFilter) return false;
      if (q.isEmpty) return true;
      return [
        item.displayId,
        item.actorLabel,
        item.action,
        item.recordRef ?? '',
        item.eventType,
      ].any((field) => field.toLowerCase().contains(q));
    }).toList();
  }

  Future<void> _openFilters() async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.md),
              child: Text('Filter by type', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            ),
            RadioGroup<String>(
              groupValue: _typeFilter,
              onChanged: (v) {
                if (v != null) Navigator.pop(context, v);
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final (label, value) in _typeOptions)
                    RadioListTile<String>(
                      value: value,
                      title: Text(label),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    if (picked != null) setState(() => _typeFilter = picked);
  }

  void _openRow(String id) {
    final useShell = widget.drawerInShell && MediaQuery.sizeOf(context).width >= 900;
    if (useShell) {
      ref.read(selectedAuditProvider.notifier).select(id);
      return;
    }
    _openAsSheet(id);
  }

  Future<void> _openAsSheet(String id) async {
    await showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close',
      pageBuilder: (context, _, _) => Align(
        alignment: Alignment.centerRight,
        child: SizedBox(
          width: 420,
          height: MediaQuery.sizeOf(context).height,
          child: AuditDrawer(recordId: id, onClose: () => Navigator.pop(context)),
        ),
      ),
    );
    ref.read(selectedAuditProvider.notifier).select(null);
  }

  Future<void> _export() async {
    try {
      final csv = await ref.read(auditServiceProvider).exportCsv();
      if (!mounted) return;

      final stamp = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
      final savedPath = await FilePicker.saveFile(
        dialogTitle: 'Save audit records as CSV',
        fileName: 'meditech_audit_$stamp.csv',
        bytes: utf8.encode(csv),
        mimeType: 'text/csv',
      );

      if (!mounted) return;

      if (kIsWeb || savedPath != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('CSV saved successfully.')),
        );
      }
    } on AppFailure catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = ref.watch(auditListProvider);
    final selected = ref.watch(selectedAuditProvider);
    final when = DateFormat('MMM d, yyyy · h:mm a');
    final shellDrawerOpen =
        widget.drawerInShell && selected != null && MediaQuery.sizeOf(context).width >= 900;
    final compact = shellDrawerOpen;

    final content = Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Audit records', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800)),
                    const SizedBox(height: AppSpacing.xs),
                    AsyncView<List<AuditRecord>>(
                      value: list,
                      onRetry: () => ref.invalidate(auditListProvider),
                      builder: (all) {
                        final n = _filtered(all).length;
                        return Text(
                          '$n of ${all.length} records · platform and security events only',
                          style: const TextStyle(color: AppColors.textMuted),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: TabletControls.toolbarHeight,
                  child: TextField(
                    controller: _search,
                    onChanged: (_) => setState(() {}),
                    decoration: TabletControls.searchDecoration(
                      hint: 'Actor, action, or record',
                      suffixIcon: _search.text.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Clear search',
                              icon: const Icon(Icons.close, size: 18),
                              onPressed: () => setState(() => _search.clear()),
                            ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              OutlinedButton.icon(
                onPressed: _openFilters,
                icon: const Icon(Icons.filter_list, size: 18),
                label: Text(_typeFilter == 'all' ? 'Filters' : 'Filters (1)'),
                style: TabletControls.toolbarOutlined(
                  border: _typeFilter == 'all' ? AppColors.border : AppColors.primary,
                  foreground: _typeFilter == 'all' ? AppColors.text : AppColors.primary,
                  background: _typeFilter == 'all' ? Colors.white : AppColors.primaryLight,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              OutlinedButton(
                onPressed: _export,
                style: TabletControls.toolbarOutlined(),
                child: const Text('Export CSV'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.border),
            ),
            child: const Text(
              'Pharmacy privacy: this log shows platform and account events only. It does not include '
              'patient data or pharmacy financials.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 13, height: 1.4),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Expanded(
            child: Card(
              margin: EdgeInsets.zero,
              clipBehavior: Clip.antiAlias,
              child: AsyncView<List<AuditRecord>>(
                value: list,
                isEmpty: (items) => items.isEmpty,
                emptyMessage: 'No audit records yet.',
                onRetry: () => ref.invalidate(auditListProvider),
                builder: (all) {
                  final filtered = _filtered(all);
                  return Column(
                    children: [
                      _AuditTableHeader(compact: compact),
                      Expanded(
                        child: filtered.isEmpty
                            ? const Center(
                                child: Text(
                                  'No records match these filters.',
                                  style: TextStyle(color: AppColors.textMuted),
                                ),
                              )
                            : ListView.separated(
                                itemCount: filtered.length,
                                separatorBuilder: (_, _) => const Divider(height: 1),
                                itemBuilder: (context, index) {
                                  final item = filtered[index];
                                  return _AuditRow(
                                    record: item,
                                    whenLabel: when.format(item.createdAt.toLocal()),
                                    compact: compact,
                                    selected: item.id == selected,
                                    onView: () => _openRow(item.id),
                                  );
                                },
                              ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );

    if (widget.drawerInShell) return content;

    return Scaffold(body: content);
  }
}

class _AuditTableHeader extends StatelessWidget {
  const _AuditTableHeader({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    Widget cell(String text, {int flex = 1}) => Expanded(
          flex: flex,
          child: Text(text, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
        );

    return Container(
      color: AppColors.primaryLight,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
      child: Row(
        children: [
          cell('ID', flex: 2),
          if (!compact) cell('WHEN', flex: 3),
          cell('ACTOR', flex: compact ? 4 : 3),
          cell('TYPE', flex: 2),
          cell('ACTION', flex: compact ? 5 : 4),
          if (!compact) cell('RECORD', flex: 2),
          const SizedBox(
            width: 48,
            child: Text('VIEW', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

class _AuditRow extends StatelessWidget {
  const _AuditRow({
    required this.record,
    required this.whenLabel,
    required this.compact,
    required this.selected,
    required this.onView,
  });

  final AuditRecord record;
  final String whenLabel;
  final bool compact;
  final bool selected;
  final VoidCallback onView;

  @override
  Widget build(BuildContext context) {
    final (typeLabel, typeTone) = auditEventTypeBadge(record.eventType);

    return Material(
      color: selected ? AppColors.primaryLight.withValues(alpha: 0.45) : Colors.transparent,
      child: InkWell(
        onTap: onView,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: Text(record.displayId, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              ),
              if (!compact)
                Expanded(
                  flex: 3,
                  child: Text(whenLabel, style: const TextStyle(fontSize: 13)),
                ),
              Expanded(
                flex: compact ? 4 : 3,
                child: Text(
                  record.actorLabel,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Expanded(
                flex: 2,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: StatusBadge(typeLabel, tone: typeTone),
                ),
              ),
              Expanded(
                flex: compact ? 5 : 4,
                child: Text(record.action, style: const TextStyle(fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis),
              ),
              if (!compact)
                Expanded(
                  flex: 2,
                  child: Text(
                    record.recordRef ?? '—',
                    style: const TextStyle(fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              SizedBox(
                width: 48,
                child: Align(
                  alignment: Alignment.center,
                  child: IconButton(
                    tooltip: 'View details',
                    onPressed: onView,
                    visualDensity: VisualDensity.compact,
                    style: IconButton.styleFrom(
                      fixedSize: const Size(40, 40),
                      backgroundColor: selected ? AppColors.primary : Colors.white,
                      foregroundColor: selected ? Colors.white : AppColors.textMuted,
                      side: BorderSide(color: selected ? AppColors.primary : AppColors.border),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                    icon: const Icon(Icons.visibility_outlined, size: 20),
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