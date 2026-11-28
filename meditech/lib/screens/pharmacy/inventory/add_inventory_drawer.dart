import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../models/inventory_item.dart';
import '../../../providers/inventory_providers.dart';
import '../../../providers/stock_alerts_providers.dart';
import '../../../widgets/common/status_badge.dart';
import '../../../widgets/theme/app_colors.dart';
import '../../../widgets/theme/app_spacing.dart';
import '../requests/medicine_request_dialog.dart';

// Slide-in drawer to add a new medicine from the active catalogue to branch inventory
class AddInventoryDrawer extends ConsumerStatefulWidget {
  const AddInventoryDrawer({super.key});

  @override
  ConsumerState<AddInventoryDrawer> createState() => _AddInventoryDrawerState();
}

class _AddInventoryDrawerState extends ConsumerState<AddInventoryDrawer> {
  final _formKey = GlobalKey<FormState>();
  final _searchController = TextEditingController();
  final _stockController = TextEditingController();
  final _priceController = TextEditingController();
  final _thresholdController = TextEditingController(text: '10');

  CatalogueMedicine? _selectedMedicine;
  DateTime? _expiryDate;
  bool _isSaving = false;
  String? _error;

  @override
  void dispose() {
    _searchController.dispose();
    _stockController.dispose();
    _priceController.dispose();
    _thresholdController.dispose();
    super.dispose();
  }

  Future<void> _pickExpiryDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _expiryDate ?? DateTime.now().add(const Duration(days: 365)),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _expiryDate = picked);
    }
  }

  String _formatDate(DateTime dt) {
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$m/$d/${dt.year}';
  }

  Future<void> _save() async {
    if (_selectedMedicine == null) {
      setState(() => _error = 'Please select a medicine from the catalogue.');
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final stock = int.tryParse(_stockController.text.trim());
    final price = double.tryParse(_priceController.text.trim());
    final threshold = int.tryParse(_thresholdController.text.trim()) ?? 10;

    if (stock == null || price == null) return;

    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      await ref.read(inventoryServiceProvider).addItem(
            medicineId: _selectedMedicine!.id,
            stockQuantity: stock,
            price: price,
            lowStockThreshold: threshold,
            nearestExpiry: _expiryDate,
          );

      ref.invalidate(inventoryProvider);
      ref.invalidate(stockAlertsProvider);

      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${_selectedMedicine!.label} added to inventory.'),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString());
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final catalogueAsync = ref.watch(catalogueProvider);
    final existingInventory =
        ref.watch(inventoryProvider).asData?.value ?? <InventoryItem>[];
    final existingIds = {for (final i in existingInventory) i.medicineId};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Drawer Header
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 16, 16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Add inventory entry',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF1A2E22),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Pick a medicine from the active MediTech catalogue.',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: const Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close, color: Color(0xFF1A2E22)),
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: Color(0xFFE5EBE7)),

        // Body
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Medicine (catalogue picker)',
                    style: GoogleFonts.inter(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1A2E22),
                    ),
                  ),
                  const SizedBox(height: 8),

                  if (_selectedMedicine != null)
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F8F4),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: const Color(0xFF2E6B46),
                          width: 1.2,
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        _selectedMedicine!.label,
                                        style: GoogleFonts.inter(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: const Color(0xFF1A2E22),
                                        ),
                                      ),
                                    ),
                                    if (_selectedMedicine!.isRx) ...[
                                      const SizedBox(width: 6),
                                      const StatusBadge.rx(),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${_selectedMedicine!.genericName} · ${_selectedMedicine!.dosageForm} · per ${_selectedMedicine!.unit}',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: const Color(0xFF6B7280),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          TextButton(
                            onPressed: () =>
                                setState(() => _selectedMedicine = null),
                            child: Text(
                              'Change',
                              style: GoogleFonts.inter(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF2E6B46),
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  else ...[
                    // Search box for catalogue
                    TextField(
                      controller: _searchController,
                      onChanged: (_) => setState(() {}),
                      style: GoogleFonts.inter(fontSize: 13.5),
                      decoration: InputDecoration(
                        hintText: 'Search brand or generic name...',
                        prefixIcon: const Icon(
                          Icons.search,
                          size: 18,
                          color: Color(0xFF6B7280),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                            color: Color(0xFFD8E8DE),
                            width: 1.2,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                            color: Color(0xFFD8E8DE),
                            width: 1.2,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                            color: Color(0xFF2E6B46),
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    catalogueAsync.when(
                      loading: () => const Padding(
                        padding: EdgeInsets.all(20),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                      error: (e, _) => Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          'Could not load catalogue: $e',
                          style: const TextStyle(
                            color: AppColors.danger,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      data: (catalogue) {
                        final q = _searchController.text.trim().toLowerCase();
                        final available = catalogue.where((m) {
                          if (existingIds.contains(m.id)) return false;
                          if (q.isEmpty) return true;
                          return m.brandName.toLowerCase().contains(q) ||
                              m.genericName.toLowerCase().contains(q) ||
                              m.strength.toLowerCase().contains(q);
                        }).toList();

                        if (available.isEmpty) {
                          final canRequest = q.isNotEmpty;
                          return Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF9FAFB),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFD8E8DE)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  q.isEmpty
                                      ? 'All active catalogue medicines are already in your inventory.'
                                      : 'No matching medicine found in the active catalogue.',
                                  style: GoogleFonts.inter(
                                    fontSize: 12.5,
                                    color: const Color(0xFF6B7280),
                                  ),
                                ),
                                if (canRequest) ...[
                                  const SizedBox(height: 12),
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: OutlinedButton.icon(
                                      onPressed: () => openMedicineRequestFlow(
                                        context,
                                        searchedName: _searchController.text.trim(),
                                      ),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: const Color(0xFF2E6B46),
                                        side: const BorderSide(color: Color(0xFF2E6B46)),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 14,
                                          vertical: 10,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                      ),
                                      icon: const Icon(Icons.add_circle_outline, size: 18),
                                      label: Text(
                                        'Request this medicine',
                                        style: GoogleFonts.inter(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          );
                        }

                        return Container(
                          constraints: const BoxConstraints(maxHeight: 200),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: const Color(0xFFD8E8DE),
                              width: 1.2,
                            ),
                          ),
                          child: ListView.separated(
                            shrinkWrap: true,
                            itemCount: available.length,
                            separatorBuilder: (_, _) => const Divider(
                              height: 1,
                              color: Color(0xFFE5EBE7),
                            ),
                            itemBuilder: (context, index) {
                              final med = available[index];
                              return InkWell(
                                onTap: () => setState(() {
                                  _selectedMedicine = med;
                                  _error = null;
                                }),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 10,
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              med.label,
                                              style: GoogleFonts.inter(
                                                fontSize: 13.5,
                                                fontWeight: FontWeight.w700,
                                                color: const Color(0xFF1A2E22),
                                              ),
                                            ),
                                            Text(
                                              '${med.genericName} · ${med.dosageForm}',
                                              style: GoogleFonts.inter(
                                                fontSize: 11.5,
                                                color: const Color(0xFF6B7280),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (med.isRx) const StatusBadge.rx(),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
                  ],

                  const SizedBox(height: 18),

                  // Stock quantity
                  _fieldLabel('Stock quantity'),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _stockController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: GoogleFonts.inter(fontSize: 14),
                    decoration: _inputDecoration('e.g. 100'),
                    validator: (v) {
                      final n = int.tryParse((v ?? '').trim());
                      if (n == null || n < 0) {
                        return 'Enter a valid stock quantity (0 or more).';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Price per unit
                  _fieldLabel(
                    'Price per ${_selectedMedicine?.unit ?? 'unit'} (₱)',
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _priceController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    style: GoogleFonts.inter(fontSize: 14),
                    decoration: _inputDecoration('e.g. 12.50'),
                    validator: (v) {
                      final p = double.tryParse((v ?? '').trim());
                      if (p == null || p <= 0) {
                        return 'Enter a price greater than 0.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Low-stock threshold
                  _fieldLabel('Low-stock threshold'),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _thresholdController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: GoogleFonts.inter(fontSize: 14),
                    decoration: _inputDecoration('10'),
                    validator: (v) {
                      final n = int.tryParse((v ?? '').trim());
                      if (n == null || n < 1) {
                        return 'Enter at least 1.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Nearest expiry date
                  _fieldLabel('Nearest expiry date (optional)'),
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: _pickExpiryDate,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      height: 46,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: const Color(0xFFD8E8DE),
                          width: 1.2,
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              _expiryDate != null
                                  ? _formatDate(_expiryDate!)
                                  : 'mm/dd/yyyy',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                color: _expiryDate != null
                                    ? const Color(0xFF1A2E22)
                                    : const Color(0xFF9CA3AF),
                              ),
                            ),
                          ),
                          if (_expiryDate != null)
                            IconButton(
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              icon: const Icon(
                                Icons.close,
                                size: 16,
                                color: Color(0xFF6B7280),
                              ),
                              onPressed: () =>
                                  setState(() => _expiryDate = null),
                            )
                          else
                            const Icon(
                              Icons.calendar_today_outlined,
                              size: 16,
                              color: Color(0xFF4B5563),
                            ),
                        ],
                      ),
                    ),
                  ),

                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.dangerLight,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.danger),
                      ),
                      child: Text(
                        _error!,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: AppColors.danger,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),

        // Footer Save Button
        const Divider(height: 1, color: Color(0xFFE5EBE7)),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: SizedBox(
            height: 46,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E6B46),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      'Add to inventory',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _fieldLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.inter(
        fontSize: 12.5,
        fontWeight: FontWeight.w700,
        color: const Color(0xFF1A2E22),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.inter(
        fontSize: 13.5,
        color: const Color(0xFF9CA3AF),
      ),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFD8E8DE), width: 1.2),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFD8E8DE), width: 1.2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFF2E6B46), width: 1.5),
      ),
    );
  }
}
