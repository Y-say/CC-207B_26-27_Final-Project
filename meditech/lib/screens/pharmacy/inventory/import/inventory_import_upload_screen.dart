import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../services/inventory_import_service.dart';
import '../../../../widgets/theme/app_colors.dart';
import 'inventory_import_review_screen.dart';

// Ph-28: Inventory import upload modal matching Figma wireframe.
class InventoryImportUploadScreen extends StatefulWidget {
  InventoryImportUploadScreen({super.key, InventoryImportService? service})
      : service = service ?? InventoryImportService();

  final InventoryImportService service;

  @override
  State<InventoryImportUploadScreen> createState() =>
      _InventoryImportUploadScreenState();
}

class _InventoryImportUploadScreenState
    extends State<InventoryImportUploadScreen> {
  static const int _maxFileSize = 2 * 1024 * 1024;

  bool _isDownloading = false;
  bool _isUploading = false;
  String? _selectedFileName;
  String? _errorMessage;

  Future<void> _downloadTemplate() async {
    setState(() {
      _isDownloading = true;
      _errorMessage = null;
    });

    try {
      final bytes = await widget.service.downloadTemplate();

      if (!mounted) return;

      final savedPath = await FilePicker.saveFile(
        dialogTitle: 'Save inventory import template',
        fileName: 'meditech_inventory_template.xlsx',
        bytes: bytes,
        mimeType:
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      );

      if (!mounted) return;

      _showSnack(
        kIsWeb || savedPath != null
            ? 'Template downloaded successfully.'
            : 'Template download cancelled.',
      );
    } catch (error) {
      if (mounted) {
        setState(() => _errorMessage = error.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _isDownloading = false);
      }
    }
  }

  Future<void> _selectAndUploadFile() async {
    setState(() => _errorMessage = null);

    try {
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['csv', 'xlsx'],
      );

      if (!mounted || file == null) return;

      final extension = (file.extension?.toLowerCase().isNotEmpty == true)
          ? file.extension!.toLowerCase()
          : file.name.trim().toLowerCase().split('.').last;

      if (extension != 'csv' && extension != 'xlsx') {
        setState(() => _errorMessage = 'Please select a CSV or XLSX file.');
        return;
      }

      final bytes = await file.readAsBytes();
      final fileSize = bytes.length;

      if (fileSize > _maxFileSize) {
        setState(
          () => _errorMessage = 'The selected file exceeds the 2 MB limit.',
        );
        return;
      }

      if (fileSize == 0) {
        setState(() => _errorMessage = 'The selected file is empty.');
        return;
      }

      if (!mounted) return;

      setState(() {
        _selectedFileName = file.name;
        _isUploading = true;
      });

      final response = await widget.service.uploadFile(
        bytes: bytes,
        fileName: file.name,
      );

      if (!mounted) return;

      final batchId = response['batch_id']?.toString();

      if (batchId == null || batchId.isEmpty) {
        throw Exception('The import service did not return a batch ID.');
      }

      final nav = Navigator.of(context);
      nav.pop();
      await showDialog<void>(
        context: nav.context,
        barrierDismissible: false,
        barrierColor: Colors.black54,
        builder: (_) => InventoryImportReviewScreen(
          batchId: batchId,
          service: widget.service,
        ),
      );
    } catch (error) {
      if (mounted) {
        setState(() => _errorMessage = error.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final busy = _isDownloading || _isUploading;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 920),
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Modal Header
              Padding(
                padding: const EdgeInsets.fromLTRB(26, 22, 22, 18),
                child: _ImportModalHeader(
                  activeStep: 1,
                  subtitle: 'Upload a file from your POS export',
                  onClose: () => Navigator.of(context).maybePop(),
                ),
              ),
              const Divider(height: 1, color: Color(0xFFE5EBE7)),

              // Modal Body
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 34,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 460),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Export a stock report from your POS and paste it into the MediTech template. You\'ll review every row before anything changes in your inventory.',
                            style: GoogleFonts.inter(
                              fontSize: 12.5,
                              height: 1.5,
                              color: const Color(0xFF4B5563),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF3F6F3),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: RichText(
                              text: TextSpan(
                                style: GoogleFonts.inter(
                                  fontSize: 11.5,
                                  height: 1.5,
                                  color: const Color(0xFF4B5563),
                                ),
                                children: [
                                  TextSpan(
                                    text: 'Template columns: ',
                                    style: GoogleFonts.inter(
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF1A2E22),
                                    ),
                                  ),
                                  const TextSpan(
                                    text:
                                        'medicine (brand and strength), stock_quantity, price_per_unit, low_stock_threshold (optional), nearest_expiry_date (optional, YYYY-MM-DD)',
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            height: 36,
                            child: OutlinedButton(
                              onPressed: busy ? null : _downloadTemplate,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF2E6B46),
                                backgroundColor: Colors.white,
                                side: const BorderSide(
                                  color: Color(0xFF2E6B46),
                                  width: 1.2,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: Text(
                                _isDownloading
                                    ? 'Downloading...'
                                    : 'Download template (.xlsx)',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF2E6B46),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          _DashedUploadDropZone(
                            fileName: _selectedFileName,
                            uploading: _isUploading,
                            onTap: busy ? null : _selectAndUploadFile,
                          ),
                          if (_isUploading) ...[
                            const SizedBox(height: 16),
                            const LinearProgressIndicator(
                              color: Color(0xFF2E6B46),
                              backgroundColor: Color(0xFFE6F0E9),
                            ),
                            const SizedBox(height: 8),
                            Center(
                              child: Text(
                                'Processing file. Inventory will not change until you publish.',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(
                                  fontSize: 11.5,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ),
                          ],
                          if (_errorMessage != null) ...[
                            const SizedBox(height: 16),
                            _UploadError(message: _errorMessage!),
                          ],
                        ],
                      ),
                    ),
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

class _ImportModalHeader extends StatelessWidget {
  const _ImportModalHeader({
    required this.activeStep,
    required this.subtitle,
    required this.onClose,
  });

  final int activeStep;
  final String subtitle;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Row(
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
                subtitle,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: const Color(0xFF6B7280),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        _StepBadge(
          number: 1,
          label: 'Upload',
          active: activeStep == 1,
        ),
        const SizedBox(width: 6),
        _StepBadge(
          number: 2,
          label: 'Review and edit',
          active: activeStep == 2,
        ),
        const SizedBox(width: 6),
        _StepBadge(
          number: 3,
          label: 'Publish',
          active: activeStep == 3,
        ),
        const SizedBox(width: 12),
        InkWell(
          onTap: onClose,
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
    );
  }
}

class _StepBadge extends StatelessWidget {
  const _StepBadge({
    required this.number,
    required this.label,
    required this.active,
  });

  final int number;
  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: active ? const Color(0xFF2E6B46) : const Color(0xFFF1F4F1),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        '$number $label',
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: active ? Colors.white : const Color(0xFF4B5563),
        ),
      ),
    );
  }
}

class _DashedUploadDropZone extends StatelessWidget {
  const _DashedUploadDropZone({
    required this.fileName,
    required this.uploading,
    required this.onTap,
  });

  final String? fileName;
  final bool uploading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final hasFile = fileName != null;

    return CustomPaint(
      foregroundPainter: _DashedRectPainter(
        color: const Color(0xFF2E6B46),
        strokeWidth: 1.3,
        radius: 14,
        dashWidth: 6,
        dashSpace: 4,
      ),
      child: Material(
        color: const Color(0xFFF4F8F4),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 165),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  hasFile
                      ? Icons.description_outlined
                      : Icons.file_upload_outlined,
                  size: 28,
                  color: const Color(0xFF2E6B46),
                ),
                const SizedBox(height: 10),
                Text(
                  uploading
                      ? 'Uploading and processing...'
                      : hasFile
                          ? fileName!
                          : 'Choose CSV or Excel file',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF2E6B46),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  hasFile
                      ? 'Tap to choose a different file'
                      : '.csv or .xlsx · up to 2 MB · up to 1,000 rows',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: const Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DashedRectPainter extends CustomPainter {
  _DashedRectPainter({
    required this.color,
    required this.strokeWidth,
    required this.radius,
    required this.dashWidth,
    required this.dashSpace,
  });

  final Color color;
  final double strokeWidth;
  final double radius;
  final double dashWidth;
  final double dashSpace;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );

    final path = Path()..addRRect(rrect);
    for (final metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final next = math.min(distance + dashWidth, metric.length);
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRectPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.strokeWidth != strokeWidth ||
      oldDelegate.radius != radius;
}

class _UploadError extends StatelessWidget {
  const _UploadError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.dangerLight,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppColors.danger.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.error_outline,
            color: AppColors.danger,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppColors.danger,
                fontSize: 12.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
