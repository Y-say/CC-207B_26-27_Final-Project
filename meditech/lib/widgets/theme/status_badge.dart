import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

// Badge colours
enum BadgeTone { success, warning, danger, info, neutral }

// Small coloured label: Available, Low Stock, Pending, Rx, and so on
class StatusBadge extends StatelessWidget {
  const StatusBadge(this.label, {super.key, this.tone = BadgeTone.neutral});

  // Rx badge for prescription medicines
  const StatusBadge.rx({super.key})
      : label = 'Rx',
        tone = BadgeTone.info;

  // Stock labels customers see
  factory StatusBadge.availability(String status, {Key? key}) {
    final (label, tone) = switch (status) {
      'available' => ('Available', BadgeTone.success),
      'low_stock' => ('Low Stock', BadgeTone.warning),
      'unavailable' => ('Unavailable', BadgeTone.danger),
      _ => ('Unconfirmed', BadgeTone.neutral),
    };
    return StatusBadge(label, key: key, tone: tone);
  }

  // Reservation statuses
  factory StatusBadge.reservation(String status, {Key? key}) {
    final (label, tone) = switch (status) {
      'pending' => ('Pending', BadgeTone.warning),
      'confirmed' => ('Confirmed', BadgeTone.info),
      'ready_for_pickup' => ('Ready for Pickup', BadgeTone.success),
      'completed' => ('Completed', BadgeTone.neutral),
      'rejected' => ('Rejected', BadgeTone.danger),
      'cancelled' => ('Cancelled', BadgeTone.neutral),
      _ => ('Expired', BadgeTone.neutral),
    };
    return StatusBadge(label, key: key, tone: tone);
  }

  final String label;
  final BadgeTone tone;

  @override
  Widget build(BuildContext context) {
    final (text, background) = switch (tone) {
      BadgeTone.success => (AppColors.primary, AppColors.primaryLight),
      BadgeTone.warning => (AppColors.warning, AppColors.warningLight),
      BadgeTone.danger => (AppColors.danger, AppColors.dangerLight),
      BadgeTone.info => (AppColors.info, AppColors.infoLight),
      BadgeTone.neutral => (AppColors.neutral, AppColors.neutralLight),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(6)),
      child: Text(
        label,
        style: TextStyle(color: text, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}