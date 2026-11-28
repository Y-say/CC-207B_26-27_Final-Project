import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../models/inventory_item.dart';
import '../../../../providers/inventory_providers.dart';
import '../../../../providers/stock_alerts_providers.dart';
import '../../../../services/inventory_import_service.dart';
import '../../../../widgets/tablet/tablet_dialogs.dart';
import '../../../../widgets/theme/app_colors.dart';
import '../../../../widgets/theme/app_spacing.dart';

// Ph-29: Staged import review modal matching Figma wireframe.
class InventoryImportReviewScreen extends ConsumerStatefulWidget {
  InventoryImportReviewScreen({
    super.key,
    required this.batchId,
    InventoryImportService? service,
  }) : service = service ?? InventoryImportService();

  final String batchId;
  final InventoryImportService service;

  @override
  ConsumerState<InventoryImportReviewScreen> createState() =>
      _InventoryImportReviewScreenState();
}

class _InventoryImportReviewScreenState
    extends ConsumerState<InventoryImportReviewScreen> {
  Map<String, dynamic>? _batch;
  List<Map<String, dynamic>> _rows = [];
  int _removedCount = 0;

  bool _loading = true;
  bool _working = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadReview();
  }

  Future<void> _loadReview() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final batch = await widget.service.loadBatch(widget.batchId);
      final rows = await widget.service.loadRows(widget.batchId);

      if (!mounted) return;

      setState(() {
        _batch = batch;
        _rows = rows;
        _loading = false;
        _working = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _error = error.toString();
        _loading = false;
        _working = false;
      });
    }
  }

  bool _rowIsValid(Map<String, dynamic> row) {
    final errors = row['errors'];
    return errors is List ? errors.isEmpty : true;
  }

  int get _validRows => _rows.where(_rowIsValid).length;

  int get _errorRows => _rows.length - _validRows;

  List<String> _messages(dynamic value) {
    return value is List
        ? value.map((e) => e.toString()).toList()
        : [];
  }

  String _disp(dynamic value) {
    return value == null || value.toString().isEmpty
        ? ''
        : value.toString();
  }

  bool get _isReviewing => _batch?['status'] == 'reviewing';

  String _normLabel(String text) =>
      text.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  InventoryItem? _matchExistingItem(
    Map<String, dynamic> row,
    List<InventoryItem> inventory,
  ) {
    final matchedId = row['matched_medicine_id']?.toString();
    if (matchedId != null && matchedId.isNotEmpty) {
      for (final item in inventory) {
        if (item.medicineId == matchedId) return item;
      }
    }
    final label = _normLabel(_disp(row['medicine_label']));
    if (label.isEmpty) return null;
    for (final item in inventory) {
      if (_normLabel('${item.brandName} ${item.strength}') == label) {
        return item;
      }
    }
    return null;
  }

  Future<void> _saveInlineRow({
    required Map<String, dynamic> row,
    required String medicineLabel,
    required String stockText,
    required String priceText,
    required String thresholdText,
    required DateTime? nearestExpiry,
  }) async {
    final stockVal = int.tryParse(stockText.trim());
    final priceVal = double.tryParse(priceText.trim());
    final thresholdVal =
        thresholdText.trim().isEmpty ? null : int.tryParse(thresholdText.trim());

    // Keep local view updated; call backend RPC when basic numeric parsing succeeds
    if (stockVal == null || priceVal == null) {
      return;
    }

    setState(() => _working = true);

    try {
      await widget.service.updateRow(
        rowId: row['id'].toString(),
        medicineLabel: medicineLabel.trim(),
        stockQuantity: stockVal,
        pricePerUnit: priceVal,
        lowStockThreshold: thresholdVal,
        nearestExpiry: nearestExpiry,
      );

      await _loadReview();
    } catch (error) {
      if (mounted) {
        setState(() => _working = false);
        _snack('Could not update row: $error');
      }
    }
  }

  Future<void> _removeRow(Map<String, dynamic> row) async {
    final name = row['raw_medicine_name']?.toString().trim();
    final confirmed = await showTabletConfirmDialog(
      context: context,
      title: 'Delete item?',
      targetName: (name != null && name.isNotEmpty) ? name : null,
      message: 'Are you sure you want to delete this item?',
      cancelLabel: 'Cancel',
      confirmLabel: 'Delete',
      isDanger: true,
    );
    if (confirmed != true || !mounted) return;

    setState(() => _working = true);

    try {
      await widget.service.removeRow(row['id'].toString());
      _removedCount++;
      await _loadReview();
    } catch (error) {
      if (mounted) {
        setState(() => _working = false);
        _snack('Could not remove row: $error');
      }
    }
  }

  Future<void> _publish() async {
    if (_errorRows > 0 || _rows.isEmpty) {
      _snack('Fix or remove all error rows before publishing.');
      return;
    }

    final confirmed = await _confirm(
      title: 'Publish $_validRows records?',
      message:
          'All $_validRows valid rows will be applied to this branch\'s '
          'live inventory.',
      confirmText: 'Publish $_validRows records',
    );

    if (!confirmed) return;

    setState(() => _working = true);

    try {
      await widget.service.publishImport(widget.batchId);
      ref.invalidate(inventoryProvider);
      ref.invalidate(stockAlertsProvider);
      if (!mounted) return;
      _snack('Inventory import published successfully.');
      Navigator.of(context).maybePop();
    } catch (error) {
      if (mounted) {
        setState(() => _working = false);
        _snack('Could not publish import: $error');
      }
    }
  }

  Future<void> _discard() async {
    final confirmed = await _confirm(
      title: 'Discard import?',
      message:
          'All staged rows in this batch will be deleted. '
          'Live inventory will not be changed.',
      confirmText: 'Discard import',
      danger: true,
    );

    if (!confirmed) return;

    setState(() => _working = true);

    try {
      await widget.service.discardImport(widget.batchId);
      if (!mounted) return;
      _snack('Import discarded.');
      Navigator.of(context).maybePop();
    } catch (error) {
      if (mounted) {
        setState(() => _working = false);
        _snack('Could not discard import: $error');
      }
    }
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    required String confirmText,
    bool danger = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        title: Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF1A2E22),
          ),
        ),
        content: Text(
          message,
          style: GoogleFonts.inter(
            fontSize: 13,
            color: const Color(0xFF4B5563),
          ),
        ),
        actions: [
          SizedBox(
            height: 40,
            child: OutlinedButton(
              onPressed: () => Navigator.pop(ctx, false),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF1A2E22),
                side: const BorderSide(color: Color(0xFFD8E8DE)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(9),
                ),
              ),
              child: Text(
                'Go back',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          SizedBox(
            height: 40,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    danger ? AppColors.danger : const Color(0xFF2E6B46),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(9),
                ),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(
                confirmText,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final inventory =
        ref.watch(inventoryProvider).maybeWhen(data: (d) => d, orElse: () => <InventoryItem>[]);

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 960, maxHeight: 740),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFD8E8DE), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.14),
                blurRadius: 28,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: _loading
              ? const SizedBox(
                  height: 360,
                  child: Center(child: CircularProgressIndicator()),
                )
              : _error != null
                  ? _ErrorState(
                      message: _error!,
                      onRetry: _loadReview,
                    )
                  : _buildModalContent(inventory),
        ),
      ),
    );
  }

  Widget _buildModalContent(List<InventoryItem> inventory) {
    int toAdd = 0;
    int toUpdate = 0;
    for (final row in _rows) {
      if (_rowIsValid(row)) {
        final existing = _matchExistingItem(row, inventory);
        if (existing != null) {
          toUpdate++;
        } else {
          toAdd++;
        }
      }
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Top Header
        Padding(
          padding: const EdgeInsets.fromLTRB(26, 20, 22, 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Import CSV or Excel',
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF1A2E22),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Review every row. Edit values, remove rows, then publish.',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: const Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              const _StepPillReview(
                number: 1,
                label: 'Upload',
                complete: true,
              ),
              const SizedBox(width: 6),
              const _StepPillReview(
                number: 2,
                label: 'Review and edit',
                active: true,
              ),
              const SizedBox(width: 6),
              const _StepPillReview(
                number: 3,
                label: 'Publish',
              ),
              const SizedBox(width: 12),
              InkWell(
                onTap: () => Navigator.of(context).maybePop(),
                borderRadius: BorderRadius.circular(18),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(
                    color: Color(0xFFF3F5F2),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.close,
                    size: 16,
                    color: Color(0xFF1A2E22),
                  ),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: Color(0xFFE5EBE7)),

        // Summary Bar: file_name + badges on left, note on right
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: [
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 6,
                children: [
                  Text(
                    _disp(_batch!['file_name']).isEmpty
                        ? 'import.xlsx'
                        : _disp(_batch!['file_name']),
                    style: GoogleFonts.inter(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1A2E22),
                    ),
                  ),
                  _SummaryPill(
                    text: '$toAdd to add',
                    bg: const Color(0xFFE4F4E8),
                    fg: const Color(0xFF2E6B46),
                  ),
                  _SummaryPill(
                    text: '$toUpdate to update',
                    bg: const Color(0xFFE5EEFF),
                    fg: const Color(0xFF2563EB),
                  ),
                  _SummaryPill(
                    text: '$_errorRows need fixing',
                    bg: const Color(0xFFFEE2E2),
                    fg: const Color(0xFFDC2626),
                  ),
                  _SummaryPill(
                    text: '$_removedCount removed',
                    bg: const Color(0xFFF1F3F2),
                    fg: const Color(0xFF4B5563),
                  ),
                ],
              ),
              Text(
                'Nothing changes in your inventory until you publish.',
                style: GoogleFonts.inter(
                  fontSize: 11.5,
                  color: const Color(0xFF6B7280),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: Color(0xFFE5EBE7)),

        // Table Header + Rows
        Flexible(
          child: _rows.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(48),
                  child: Center(
                    child: Text(
                      'No rows in this import batch.',
                      style: GoogleFonts.inter(color: AppColors.textMuted),
                    ),
                  ),
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Column headers
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 10,
                      ),
                      decoration: const BoxDecoration(
                        color: Color(0xFFFAFBF9),
                        border: Border(
                          bottom: BorderSide(color: Color(0xFFE5EBE7)),
                        ),
                      ),
                      child: const Row(
                        children: [
                          SizedBox(width: 28, child: _ColHeader('#')),
                          Expanded(flex: 24, child: _ColHeader('MEDICINE')),
                          SizedBox(width: 10),
                          Expanded(flex: 10, child: _ColHeader('STOCK')),
                          SizedBox(width: 10),
                          Expanded(flex: 10, child: _ColHeader('PRICE (₱)')),
                          SizedBox(width: 10),
                          Expanded(flex: 10, child: _ColHeader('LOW-STOCK')),
                          SizedBox(width: 10),
                          Expanded(
                            flex: 16,
                            child: _ColHeader('NEAREST EXPIRY'),
                          ),
                          SizedBox(width: 10),
                          SizedBox(width: 78, child: _ColHeader('RESULT')),
                          SizedBox(width: 10),
                          SizedBox(width: 78),
                        ],
                      ),
                    ),
                    // Scrollable rows
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: _rows.length,
                        separatorBuilder: (_, _) =>
                            const Divider(height: 1, color: Color(0xFFE5EBE7)),
                        itemBuilder: (context, index) {
                          final row = _rows[index];
                          final existing = _matchExistingItem(row, inventory);
                          return _InlineEditableImportRow(
                            key: ValueKey(row['id']),
                            indexNumber: index + 1,
                            row: row,
                            existingItem: existing,
                            valid: _rowIsValid(row),
                            errors: _messages(row['errors']),
                            warnings: _messages(row['warnings']),
                            isReviewing: _isReviewing,
                            working: _working,
                            onSave: _saveInlineRow,
                            onRemove: () => _removeRow(row),
                          );
                        },
                      ),
                    ),
                  ],
                ),
        ),

        // Bottom Footer Bar
        if (_isReviewing)
          _FooterActionBar(
            working: _working,
            canPublish: _errorRows == 0 && _rows.isNotEmpty,
            errorRows: _errorRows,
            validRows: _validRows,
            onDiscard: _discard,
            onPublish: _publish,
          ),
      ],
    );
  }
}

class _StepPillReview extends StatelessWidget {
  const _StepPillReview({
    required this.number,
    required this.label,
    this.active = false,
    this.complete = false,
  });

  final int number;
  final String label;
  final bool active;
  final bool complete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: active
            ? const Color(0xFF2E6B46)
            : complete
                ? const Color(0xFFE4F4E8)
                : const Color(0xFFF1F4F1),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        '$number $label',
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: active
              ? Colors.white
              : complete
                  ? const Color(0xFF2E6B46)
                  : const Color(0xFF4B5563),
        ),
      ),
    );
  }
}

class _SummaryPill extends StatelessWidget {
  const _SummaryPill({
    required this.text,
    required this.bg,
    required this.fg,
  });

  final String text;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }
}

class _ColHeader extends StatelessWidget {
  const _ColHeader(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.inter(
        fontSize: 10,
        fontWeight: FontWeight.w800,
        color: const Color(0xFF6B7280),
        letterSpacing: 0.4,
      ),
    );
  }
}

class _InlineEditableImportRow extends StatefulWidget {
  const _InlineEditableImportRow({
    super.key,
    required this.indexNumber,
    required this.row,
    required this.existingItem,
    required this.valid,
    required this.errors,
    required this.warnings,
    required this.isReviewing,
    required this.working,
    required this.onSave,
    required this.onRemove,
  });

  final int indexNumber;
  final Map<String, dynamic> row;
  final InventoryItem? existingItem;
  final bool valid;
  final List<String> errors;
  final List<String> warnings;
  final bool isReviewing;
  final bool working;
  final Future<void> Function({
    required Map<String, dynamic> row,
    required String medicineLabel,
    required String stockText,
    required String priceText,
    required String thresholdText,
    required DateTime? nearestExpiry,
  }) onSave;
  final VoidCallback onRemove;

  @override
  State<_InlineEditableImportRow> createState() =>
      _InlineEditableImportRowState();
}

class _InlineEditableImportRowState extends State<_InlineEditableImportRow> {
  late final TextEditingController _medicineCtrl;
  late final TextEditingController _stockCtrl;
  late final TextEditingController _priceCtrl;
  late final TextEditingController _thresholdCtrl;
  DateTime? _expiryDate;

  @override
  void initState() {
    super.initState();
    _initFromRow();
  }

  @override
  void didUpdateWidget(covariant _InlineEditableImportRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.row != widget.row) {
      _medicineCtrl.text = _str(widget.row['medicine_label']);
      _stockCtrl.text = _str(widget.row['stock_quantity']);
      _priceCtrl.text = _formatPrice(widget.row['price_per_unit']);
      _thresholdCtrl.text = _str(widget.row['low_stock_threshold']);
      _expiryDate = _parseDate(widget.row['nearest_expiry']);
    }
  }

  void _initFromRow() {
    _medicineCtrl = TextEditingController(
      text: _str(widget.row['medicine_label']),
    );
    _stockCtrl = TextEditingController(
      text: _str(widget.row['stock_quantity']),
    );
    _priceCtrl = TextEditingController(
      text: _formatPrice(widget.row['price_per_unit']),
    );
    _thresholdCtrl = TextEditingController(
      text: _str(widget.row['low_stock_threshold']),
    );
    _expiryDate = _parseDate(widget.row['nearest_expiry']);
  }

  String _str(dynamic v) => v == null ? '' : v.toString();

  String _formatPrice(dynamic v) {
    if (v == null || v.toString().isEmpty) return '';
    final d = double.tryParse(v.toString());
    return d != null ? d.toStringAsFixed(2) : v.toString();
  }

  DateTime? _parseDate(dynamic v) {
    if (v == null || v.toString().isEmpty) return null;
    return DateTime.tryParse(v.toString());
  }

  String _formatDateSlash(DateTime? dt) {
    if (dt == null) return '';
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$m/$d/${dt.year}';
  }

  @override
  void dispose() {
    _medicineCtrl.dispose();
    _stockCtrl.dispose();
    _priceCtrl.dispose();
    _thresholdCtrl.dispose();
    super.dispose();
  }

  void _triggerSave() {
    widget.onSave(
      row: widget.row,
      medicineLabel: _medicineCtrl.text,
      stockText: _stockCtrl.text,
      priceText: _priceCtrl.text,
      thresholdText: _thresholdCtrl.text,
      nearestExpiry: _expiryDate,
    );
  }

  bool get _hasMedicineError {
    if (_medicineCtrl.text.trim().isEmpty) return true;
    return widget.errors.any(
      (e) => e.toLowerCase().contains('medicine') || e.toLowerCase().contains('catalogue'),
    );
  }

  bool get _hasStockError {
    if (_stockCtrl.text.trim().isEmpty) return true;
    if (int.tryParse(_stockCtrl.text.trim()) == null) return true;
    return widget.errors.any((e) => e.toLowerCase().contains('stock'));
  }

  bool get _hasPriceError {
    if (_priceCtrl.text.trim().isEmpty) return true;
    final p = double.tryParse(_priceCtrl.text.trim());
    if (p == null || p <= 0) return true;
    return widget.errors.any((e) => e.toLowerCase().contains('price'));
  }

  bool get _hasThresholdError {
    final t = _thresholdCtrl.text.trim();
    if (t.isNotEmpty) {
      final v = int.tryParse(t);
      if (v == null || v < 1) return true;
    }
    return widget.errors.any((e) => e.toLowerCase().contains('threshold'));
  }

  Future<void> _pickDate() async {
    if (!widget.isReviewing || widget.working) return;
    final picked = await showDatePicker(
      context: context,
      initialDate: _expiryDate ?? DateTime.now().add(const Duration(days: 365)),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _expiryDate = picked);
      _triggerSave();
    }
  }

  @override
  Widget build(BuildContext context) {
    final existing = widget.existingItem;
    final isUpdate = existing != null;

    // Build comparison subtitle when medicine matches an existing listing
    String? matchInfo;
    String? outOfStockNote;
    if (existing != null) {
      final newStock = _stockCtrl.text.trim().isEmpty
          ? '—'
          : _stockCtrl.text.trim();
      final newPriceVal = double.tryParse(_priceCtrl.text.trim());
      final newPrice = newPriceVal != null
          ? '₱${newPriceVal.toStringAsFixed(2)}'
          : (_priceCtrl.text.trim().isEmpty ? '—' : '₱${_priceCtrl.text.trim()}');

      matchInfo =
          'Matches ${existing.brandName} ${existing.strength}: '
          'stock ${existing.stockQuantity} → $newStock, '
          'price ₱${existing.pricePerUnit.toStringAsFixed(2)} → $newPrice';

      if (existing.outOfStock) {
        outOfStockNote =
            'Marked out of stock: the count updates, but it stays Unavailable until you use Back in stock.';
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // # index
              SizedBox(
                width: 28,
                child: Text(
                  '${widget.indexNumber}',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: const Color(0xFF6B7280),
                  ),
                ),
              ),

              // Medicine input
              Expanded(
                flex: 24,
                child: _InlineBoxField(
                  controller: _medicineCtrl,
                  enabled: widget.isReviewing && !widget.working,
                  hasError: !widget.valid && _hasMedicineError,
                  onSubmitted: (_) => _triggerSave(),
                ),
              ),
              const SizedBox(width: 10),

              // Stock input
              Expanded(
                flex: 10,
                child: _InlineBoxField(
                  controller: _stockCtrl,
                  enabled: widget.isReviewing && !widget.working,
                  hasError: !widget.valid && _hasStockError,
                  keyboardType: TextInputType.number,
                  onSubmitted: (_) => _triggerSave(),
                ),
              ),
              const SizedBox(width: 10),

              // Price input
              Expanded(
                flex: 10,
                child: _InlineBoxField(
                  controller: _priceCtrl,
                  enabled: widget.isReviewing && !widget.working,
                  hasError: !widget.valid && _hasPriceError,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  onSubmitted: (_) => _triggerSave(),
                ),
              ),
              const SizedBox(width: 10),

              // Low-stock input
              Expanded(
                flex: 10,
                child: _InlineBoxField(
                  controller: _thresholdCtrl,
                  enabled: widget.isReviewing && !widget.working,
                  hasError: !widget.valid && _hasThresholdError,
                  hintText: '10',
                  keyboardType: TextInputType.number,
                  onSubmitted: (_) => _triggerSave(),
                ),
              ),
              const SizedBox(width: 10),

              // Nearest expiry date field
              Expanded(
                flex: 16,
                child: InkWell(
                  onTap: _pickDate,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    height: 38,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFFD8E8DE),
                        width: 1.1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            _expiryDate != null
                                ? _formatDateSlash(_expiryDate)
                                : '—',
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: const Color(0xFF1A2E22),
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.calendar_today_outlined,
                          size: 13,
                          color: Color(0xFF4B5563),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // Result pill (Update / Add / Fix needed)
              SizedBox(
                width: 78,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _ResultBadge(
                    valid: widget.valid,
                    isUpdate: isUpdate,
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // Remove button
              SizedBox(
                width: 78,
                height: 38,
                child: OutlinedButton(
                  onPressed:
                      widget.isReviewing && !widget.working ? widget.onRemove : null,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFC93B3B),
                    side: const BorderSide(
                      color: Color(0xFFE5EBE7),
                      width: 1.1,
                    ),
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    'Remove',
                    style: GoogleFonts.inter(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFFC93B3B),
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Sub-lines under row (out of stock warning, match info, or errors)
          if (outOfStockNote != null ||
              matchInfo != null ||
              widget.errors.isNotEmpty ||
              widget.warnings.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 28, top: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (outOfStockNote != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text(
                        outOfStockNote,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFFB45309),
                        ),
                      ),
                    ),
                  for (final w in widget.warnings)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text(
                        w,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFFB45309),
                        ),
                      ),
                    ),
                  for (final err in widget.errors)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text(
                        err,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFFC93B3B),
                        ),
                      ),
                    ),
                  if (matchInfo != null && widget.errors.isEmpty)
                    Text(
                      matchInfo,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: const Color(0xFF6B7280),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _InlineBoxField extends StatelessWidget {
  const _InlineBoxField({
    required this.controller,
    required this.enabled,
    required this.hasError,
    required this.onSubmitted,
    this.hintText,
    this.keyboardType,
  });

  final TextEditingController controller;
  final bool enabled;
  final bool hasError;
  final ValueChanged<String> onSubmitted;
  final String? hintText;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    final borderColor =
        hasError ? const Color(0xFFC93B3B) : const Color(0xFFD8E8DE);
    final fillColor =
        hasError ? const Color(0xFFFFF5F5) : Colors.white;

    return SizedBox(
      height: 38,
      child: Focus(
        onFocusChange: (hasFocus) {
          if (!hasFocus && enabled) {
            onSubmitted(controller.text);
          }
        },
        child: TextField(
          controller: controller,
          enabled: enabled,
          keyboardType: keyboardType,
          onSubmitted: onSubmitted,
          textAlignVertical: TextAlignVertical.center,
          expands: true,
          maxLines: null,
          minLines: null,
          style: GoogleFonts.inter(
            fontSize: 12,
            color: const Color(0xFF1A2E22),
          ),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: GoogleFonts.inter(
              fontSize: 12,
              color: const Color(0xFF9CA3AF),
            ),
            filled: true,
            fillColor: fillColor,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 0,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: borderColor, width: 1.1),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: borderColor, width: 1.1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: hasError
                    ? const Color(0xFFC93B3B)
                    : const Color(0xFF2E6B46),
                width: 1.4,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ResultBadge extends StatelessWidget {
  const _ResultBadge({
    required this.valid,
    required this.isUpdate,
  });

  final bool valid;
  final bool isUpdate;

  @override
  Widget build(BuildContext context) {
    final (String label, Color bg, Color fg) = !valid
        ? ('Fix needed', const Color(0xFFFEE2E2), const Color(0xFFDC2626))
        : isUpdate
            ? ('Update', const Color(0xFFE5EEFF), const Color(0xFF2563EB))
            : ('Add', const Color(0xFFE4F4E8), const Color(0xFF2E6B46));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }
}

class _FooterActionBar extends StatelessWidget {
  const _FooterActionBar({
    required this.working,
    required this.canPublish,
    required this.errorRows,
    required this.validRows,
    required this.onDiscard,
    required this.onPublish,
  });

  final bool working;
  final bool canPublish;
  final int errorRows;
  final int validRows;
  final VoidCallback onDiscard;
  final VoidCallback onPublish;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(18)),
        border: Border(
          top: BorderSide(color: Color(0xFFE5EBE7)),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: errorRows > 0
                ? Text(
                    '$errorRows ${errorRows == 1 ? 'row needs' : 'rows need'} '
                    'fixing or removing before you can publish.',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: const Color(0xFFC93B3B),
                      fontWeight: FontWeight.w700,
                    ),
                  )
                : Text(
                    'All rows are ready to publish.',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: const Color(0xFF6B7280),
                    ),
                  ),
          ),
          const SizedBox(width: 12),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 40,
                child: OutlinedButton(
                  onPressed: working ? null : onDiscard,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF1A2E22),
                    backgroundColor: Colors.white,
                    side: const BorderSide(
                      color: Color(0xFFD8E8DE),
                      width: 1.2,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(
                    'Discard import',
                    style: GoogleFonts.inter(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1A2E22),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                height: 40,
                child: ElevatedButton(
                  onPressed: working || !canPublish ? null : onPublish,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E6B46),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: const Color(0xFFD2DDD5),
                    disabledForegroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: working
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          'Publish $validRows ${validRows == 1 ? 'record' : 'records'}',
                          style: GoogleFonts.inter(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.error_outline,
            size: 40,
            color: AppColors.textMuted,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textMuted),
          ),
          const SizedBox(height: AppSpacing.lg),
          ElevatedButton(
            onPressed: onRetry,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2E6B46),
              foregroundColor: Colors.white,
            ),
            child: const Text('Try again'),
          ),
        ],
      ),
    );
  }
}
