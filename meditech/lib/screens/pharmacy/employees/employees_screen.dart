import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../models/employee.dart';
import '../../../providers/employee_providers.dart';
import '../../../providers/pharmacy_staff_providers.dart';
import '../../../services/staff_avatar_service.dart';
import '../../../utils/app_failure.dart';
import '../../../utils/pick_profile_image.dart';
import '../../../utils/staff_avatar_refresh.dart';
import '../../../widgets/common/profile_photo_avatar.dart';
import '../../../widgets/common/async_view.dart';
import '../../../widgets/tablet/tablet_data_table.dart';
import '../../../widgets/tablet/tablet_details_drawer.dart';
import '../../../widgets/tablet/tablet_dialogs.dart';
import '../../../widgets/tablet/tablet_filter_panel.dart';
import '../../../widgets/theme/app_colors.dart';
import '../../../widgets/theme/app_spacing.dart';
import '../../../widgets/theme/status_badge.dart';
import 'employee_dialogs.dart';

// Ph-33 & Ph-34: Owner-only. Pharmacists submit PRC on Profile; owner verifies here.
class EmployeesScreen extends ConsumerStatefulWidget {
  const EmployeesScreen({super.key});

  @override
  ConsumerState<EmployeesScreen> createState() => _EmployeesScreenState();
}

class _EmployeesScreenState extends ConsumerState<EmployeesScreen> {
  final GlobalKey _filterButtonKey = GlobalKey();
  final GlobalKey _stackKey = GlobalKey();
  double _filterTop = 140;
  double _filterLeft = 400;
  String _search = '';
  String? _roleFilter;
  bool? _activeFilter;
  bool _showFilters = false;
  String? _selectedId;
  bool _offline = false;
  bool _busyAction = false;

  void _toggleFilters() {
    if (!_showFilters) {
      final renderBox =
          _filterButtonKey.currentContext?.findRenderObject() as RenderBox?;
      final stackBox =
          _stackKey.currentContext?.findRenderObject() as RenderBox?;
      if (renderBox != null && stackBox != null && renderBox.hasSize) {
        final offset = renderBox.localToGlobal(Offset.zero, ancestor: stackBox);
        _filterTop = offset.dy + renderBox.size.height + 8;
        _filterLeft = offset.dx;
      }
    }
    setState(() => _showFilters = !_showFilters);
  }

  Future<bool> _runAction(Future<void> Function() work) async {
    setState(() {
      _busyAction = true;
      _offline = false;
    });
    try {
      await work();
      return true;
    } on AppFailure catch (error) {
      if (!mounted) return false;
      if (error.message == 'Could not reach Supabase.') {
        setState(() => _offline = true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message)),
        );
      }
      return false;
    } finally {
      if (mounted) setState(() => _busyAction = false);
    }
  }

  Future<void> _showDoneModal({
    required String title,
    required List<String> bullets,
  }) {
    return showTabletMessageDialog(
      context: context,
      title: title,
      bullets: bullets,
      isWarning: false,
      buttonLabel: 'Done',
    );
  }

  Future<void> _addEmployee() async {
    final created = await showAddEmployeeDialog(
      context,
      onSubmit: ({
        required firstName,
        middleName,
        required lastName,
        required username,
        email,
        required role,
        prcLicenseNo,
        prcLicenseExpiry,
      }) {
        return ref.read(employeesProvider.notifier).createEmployee(
              firstName: firstName,
              middleName: middleName,
              lastName: lastName,
              username: username,
              email: email,
              role: role,
              prcLicenseNo: prcLicenseNo,
              prcLicenseExpiry: prcLicenseExpiry,
            );
      },
    );
    if (created == null || !mounted) return;
    setState(() => _selectedId = created.accountId);
    await showTemporaryPasswordDialog(
      context,
      title: 'Employee added',
      employeeName: created.displayId,
      username: created.username,
      temporaryPassword: created.temporaryPassword,
    );
  }

  Future<void> _resetPassword(Employee employee) async {
    final confirmed = await showTabletConfirmDialog(
      context: context,
      title: 'Reset password?',
      targetName: '${employee.fullName} · ${employee.displayId}',
      message: 'Are you sure you want to reset this employee\'s password?',
      cancelLabel: 'Cancel',
      confirmLabel: 'Reset password',
    );
    if (confirmed != true || !mounted) return;

    await _runAction(() async {
      final tempPassword = await ref
          .read(employeesProvider.notifier)
          .resetPassword(employeeId: employee.accountId);
      if (!mounted) return;
      await showTemporaryPasswordDialog(
        context,
        title: 'Password reset',
        employeeName: employee.fullName,
        username: employee.username,
        temporaryPassword: tempPassword,
      );
    });
  }

  Future<void> _toggleActive(Employee employee) async {
    final nextActive = !employee.isActive;
    final confirmed = await showTabletConfirmDialog(
      context: context,
      title: nextActive ? 'Reactivate employee?' : 'Deactivate employee?',
      targetName: '${employee.fullName} · ${employee.displayId}',
      message: nextActive
          ? 'Are you sure you want to reactivate this employee?'
          : 'Are you sure you want to deactivate this employee?',
      cancelLabel: 'Cancel',
      confirmLabel: nextActive ? 'Reactivate' : 'Deactivate',
      isDanger: !nextActive,
    );
    if (confirmed != true || !mounted) return;

    final ok = await _runAction(() async {
      await ref.read(employeesProvider.notifier).setActive(
            employeeId: employee.accountId,
            isActive: nextActive,
          );
    });
    if (!ok || !mounted) return;
    await _showDoneModal(
      title: nextActive ? 'Employee reactivated' : 'Employee deactivated',
      bullets: nextActive
          ? [
              '${employee.fullName} · ${employee.displayId}',
              'They can sign in again with their existing username.',
            ]
          : [
              '${employee.fullName} · ${employee.displayId}',
              'They were signed out and cannot sign in until reactivated.',
            ],
    );
  }

  Future<void> _changeRole(Employee employee) async {
    final nextRole = employee.isPharmacist ? 'staff' : 'pharmacist';
    String? prcNo;
    DateTime? prcExpiry;

    if (nextRole == 'pharmacist') {
      final result = await showEmployeeLicenseDialog(
        context,
        employee: employee,
        requireLicenseOnly: true,
      );
      if (result == null || !mounted) return;
      prcNo = result.prcLicenseNo;
      prcExpiry = result.prcLicenseExpiry;
    }

    final confirmed = await showTabletConfirmDialog(
      context: context,
      title: nextRole == 'pharmacist' ? 'Promote to Pharmacist?' : 'Change role to Staff?',
      targetName: '${employee.fullName} · ${employee.displayId}',
      message: nextRole == 'pharmacist'
          ? 'Are you sure you want to promote this employee to Pharmacist (PRC $prcNo)?'
          : 'Are you sure you want to change this employee\'s role to Staff?',
      cancelLabel: 'Cancel',
      confirmLabel: 'Change role',
      isDanger: nextRole == 'staff',
    );
    if (confirmed != true || !mounted) return;

    final ok = await _runAction(() async {
      await ref.read(employeesProvider.notifier).changeRole(
            employeeId: employee.accountId,
            newRole: nextRole,
            prcLicenseNo: prcNo,
            prcLicenseExpiry: prcExpiry,
          );
    });
    if (!ok || !mounted) return;
    await _showDoneModal(
      title: nextRole == 'pharmacist' ? 'Promoted to pharmacist' : 'Changed to staff',
      bullets: nextRole == 'pharmacist'
          ? [
              '${employee.fullName} · ${employee.displayId}',
              if (prcNo != null) 'PRC $prcNo on file.',
              'License is Pending until you verify it.',
            ]
          : [
              '${employee.fullName} · ${employee.displayId}',
              'They can no longer confirm or release Rx reservations.',
            ],
    );
  }

  Future<void> _uploadEmployeePhoto(Employee employee) async {
    final picked = await pickProfileImageBytes(context);
    if (picked == null || !mounted) return;
    final ok = await _runAction(() async {
      final path = await ref.read(employeeServiceProvider).uploadEmployeeAvatar(
            employeeAccountId: employee.accountId,
            fileName: picked.fileName,
            bytes: picked.bytes,
          );
      final uid = Supabase.instance.client.auth.currentUser?.id;
      if (uid != null && uid == employee.accountId) {
        await applyStaffAvatarRefresh(ref, storedPath: path);
      }
      ref.invalidate(employeesProvider);
    });
    if (!ok || !mounted) return;
    await _showDoneModal(
      title: 'Profile photo updated',
      bullets: [
        employee.fullName,
        'The photo appears in the header and employee list.',
      ],
    );
  }

  Future<void> _openPharmacyProfileEdit() async {
    final changed = await context.push<bool>('/profile/edit');
    if (!mounted) return;
    if (changed == true) {
      ref.invalidate(pharmacyStaffProfileProvider);
      ref.invalidate(employeesProvider);
    }
  }

  Future<void> _setContactEmail(Employee employee) async {
    final email = await showSetEmployeeContactEmailDialog(
      context,
      employee: employee,
    );
    if (email == null || !mounted) return;

    final ok = await _runAction(() async {
      await ref.read(employeeServiceProvider).updateContactEmail(
            employeeId: employee.accountId,
            email: email,
          );
    });
    if (!ok || !mounted) return;
    await _showDoneModal(
      title: 'Contact Gmail saved',
      bullets: [
        employee.fullName,
        email,
        'They can use Forgot password on branch sign-in with this Gmail or their username.',
      ],
    );
  }

  Future<void> _editProfile(Employee employee) async {
    final draft = await showEditEmployeeProfileDialog(
      context,
      employee: employee,
    );
    if (draft == null || !mounted) return;

    final ok = await _runAction(() async {
      await ref.read(employeesProvider.notifier).updateProfile(
            employeeId: employee.accountId,
            firstName: draft.firstName,
            middleName: draft.middleName,
            lastName: draft.lastName,
          );
    });
    if (!ok || !mounted) return;
    final middle = (draft.middleName ?? '').trim();
    final savedName = [
      draft.firstName.trim(),
      if (middle.isNotEmpty) middle,
      draft.lastName.trim(),
    ].join(' ');
    await _showDoneModal(
      title: 'Name updated',
      bullets: [
        '$savedName · ${employee.displayId}',
        'Display name on file was saved. They change username and Gmail on their own Profile.',
      ],
    );
  }

  Future<void> _updateLicense(Employee employee) async {
    final result = await showEmployeeLicenseDialog(context, employee: employee);
    if (result == null || !mounted) return;

    // Owner's own license always requires an explicit confirmation step
    final confirmed = await showTabletConfirmDialog(
      context: context,
      title: employee.isOwner ? 'Confirm your own PRC license?' : 'Save license changes?',
      targetName: '${employee.fullName} · PRC ${result.prcLicenseNo}',
      message: employee.isOwner
          ? 'Are you sure these PRC license details belong to you and are true?'
          : 'Are you sure you want to save these license changes?',
      cancelLabel: 'Cancel',
      confirmLabel: result.markVerified ? 'Save & verify' : 'Save license',
    );
    if (confirmed != true || !mounted) return;

    final ok = await _runAction(() async {
      await ref.read(employeesProvider.notifier).updateLicense(
            employeeId: employee.accountId,
            prcLicenseNo: result.prcLicenseNo,
            prcLicenseExpiry: result.prcLicenseExpiry,
            markVerified: result.markVerified,
            ownerConfirmed: employee.isOwner,
          );
    });
    if (!ok || !mounted) return;
    ref.invalidate(pharmacyStaffProfileProvider);
    await _showDoneModal(
      title: result.markVerified ? 'PRC license verified' : 'PRC license saved',
      bullets: [
        '${employee.fullName} · PRC ${result.prcLicenseNo}',
        'Expires ${formatEmployeeDate(result.prcLicenseExpiry)}.',
        if (result.markVerified)
          employee.isOwner
              ? 'You can confirm reservations and release Rx items when this license is current.'
              : '${employee.firstName} can confirm reservations and release Rx items.'
        else
          'Status is Pending until you verify the license under Employees.',
      ],
    );
  }

  StatusBadge _licenseBadge(Employee employee) {
    return switch (employee.licenseStatus) {
      'verified' => const StatusBadge('Verified', tone: BadgeTone.success),
      'pending' => const StatusBadge('Pending', tone: BadgeTone.warning),
      'expired' => const StatusBadge('Expired', tone: BadgeTone.danger),
      _ => const StatusBadge('None', tone: BadgeTone.neutral),
    };
  }

  List<Employee> _applyFilters(List<Employee> all) {
    final q = _search.trim().toLowerCase();
    return all.where((e) {
      if (_roleFilter != null && e.role != _roleFilter) return false;
      if (_activeFilter != null && e.isActive != _activeFilter) return false;
      if (q.isNotEmpty) {
        final haystack =
            '${e.fullName} ${e.displayId} ${e.username ?? ''}'.toLowerCase();
        if (!haystack.contains(q)) return false;
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final asyncEmployees = ref.watch(employeesProvider);
    final all = asyncEmployees.asData?.value ?? const <Employee>[];
    final selected = _selectedId == null
        ? null
        : all.where((e) => e.accountId == _selectedId).firstOrNull;
    final filterCount = (_roleFilter != null ? 1 : 0) + (_activeFilter != null ? 1 : 0);
    final avatarRevision = ref.watch(staffAvatarRevisionProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Stack(
              key: _stackKey,
              children: [
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_offline) const OfflineBanner(),
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.md),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Employees',
                                    style: GoogleFonts.inter(
                                      fontSize: 26,
                                      fontWeight: FontWeight.w800,
                                      color: const Color(0xFF1A2E22),
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Manage team members, roles, PRC licenses, and permissions.',
                                    style: GoogleFonts.inter(
                                      color: AppColors.textMuted,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(
                              height: 44,
                              child: ElevatedButton.icon(
                                onPressed: _busyAction ? null : _addEmployee,
                                icon: const Icon(
                                  Icons.person_add_alt_1,
                                  size: 18,
                                  color: Colors.white,
                                ),
                                label: Text(
                                  'Add employee',
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF2E6B46),
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 18,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: AsyncView<List<Employee>>(
                          value: asyncEmployees,
                          isEmpty: (items) => items.isEmpty,
                          emptyMessage: 'No employees yet. Add your first team member.',
                          onRetry: () => ref.read(employeesProvider.notifier).reload(),
                          builder: (items) {
                            final filtered = _applyFilters(items);
                            return TabletDataTable<Employee>(
                              compactForDrawer: _selectedId != null,
                              filterButtonKey: _filterButtonKey,
                              searchHint: 'Search...',
                              searchQuery: _search,
                              onSearchChanged: (v) => setState(() => _search = v),
                              totalCount: items.length,
                              filteredCount: filtered.length,
                              countLabel: 'staff',
                              activeFilterCount: filterCount,
                              onFiltersTap: _toggleFilters,
                              columns: const [
                                TabletColumn(
                                  title: 'Employee',
                                  priority: TabletColumnPriority.high,
                                  width: 220,
                                ),
                                TabletColumn(
                                  title: 'Username',
                                  priority: TabletColumnPriority.medium,
                                  width: 140,
                                ),
                                TabletColumn(
                                  title: 'Role',
                                  priority: TabletColumnPriority.high,
                                  width: 120,
                                ),
                                TabletColumn(
                                  title: 'PRC License',
                                  priority: TabletColumnPriority.medium,
                                  width: 180,
                                ),
                                TabletColumn(
                                  title: 'Status',
                                  priority: TabletColumnPriority.high,
                                  width: 120,
                                ),
                                TabletColumn(
                                  title: 'VIEW',
                                  priority: TabletColumnPriority.high,
                                  width: 72,
                                  alignment: Alignment.center,
                                ),
                              ],
                              items: filtered,
                              rowBuilder: (context, emp, index) {
                                final isSelected = emp.accountId == _selectedId;
                                return [
                                  Text(
                                    '${emp.fullName} · ${emp.displayId}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.inter(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14,
                                      color: isSelected
                                          ? AppColors.primary
                                          : const Color(0xFF1A2E22),
                                    ),
                                  ),
                                  Text(
                                    emp.username != null ? '@${emp.username}' : '—',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  StatusBadge(
                                    emp.roleLabel,
                                    tone: emp.isOwner
                                        ? BadgeTone.info
                                        : emp.isPharmacist
                                            ? BadgeTone.success
                                            : BadgeTone.neutral,
                                  ),
                                  emp.prcLicenseNo == null
                                      ? const Text('—')
                                      : Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Flexible(
                                              child: Text(
                                                emp.prcLicenseNo!,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            _licenseBadge(emp),
                                          ],
                                        ),
                                  StatusBadge(
                                    emp.isActive ? 'Active' : 'Deactivated',
                                    tone: emp.isActive
                                        ? BadgeTone.success
                                        : BadgeTone.danger,
                                  ),
                                  IconButton(
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(
                                      minWidth: 40,
                                      minHeight: 40,
                                    ),
                                    icon: Icon(
                                      isSelected
                                          ? Icons.visibility
                                          : Icons.visibility_outlined,
                                      color: isSelected
                                          ? AppColors.primary
                                          : AppColors.textMuted,
                                      size: 20,
                                    ),
                                    tooltip: 'View employee',
                                    onPressed: () => setState(
                                      () => _selectedId = emp.accountId,
                                    ),
                                  ),
                                ];
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                if (_showFilters) ...[
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTap: () => setState(() => _showFilters = false),
                    ),
                  ),
                  Positioned(
                    top: _filterTop,
                    left: _filterLeft,
                    child: TabletFilterPanel(
                      title: 'Filter employees',
                      activeFilterCount: filterCount,
                      onReset: () => setState(() {
                        _roleFilter = null;
                        _activeFilter = null;
                        _showFilters = false;
                      }),
                      onApply: () => setState(() => _showFilters = false),
                      content: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Role',
                              style: TextStyle(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 8,
                            children: [
                              for (final role in ['owner', 'pharmacist', 'staff'])
                                ChoiceChip(
                                  label: Text(role[0].toUpperCase() + role.substring(1)),
                                  selected: _roleFilter == role,
                                  onSelected: (on) => setState(
                                    () => _roleFilter = on ? role : null,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.md),
                          const Text('Account status',
                              style: TextStyle(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 8,
                            children: [
                              ChoiceChip(
                                label: const Text('Active'),
                                selected: _activeFilter == true,
                                onSelected: (on) => setState(
                                  () => _activeFilter = on ? true : null,
                                ),
                              ),
                              ChoiceChip(
                                label: const Text('Deactivated'),
                                selected: _activeFilter == false,
                                onSelected: (on) => setState(
                                  () => _activeFilter = on ? false : null,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (selected != null)
            _EmployeeDetailsDrawer(
              employee: selected,
              photoUrl: staffAvatarPublicUrl(
                selected.avatarPath,
                cacheBust: avatarRevision,
              ),
              busy: _busyAction,
              licenseBadge: _licenseBadge(selected),
              onClose: () => setState(() => _selectedId = null),
              onResetPassword: () => _resetPassword(selected),
              onToggleActive: () => _toggleActive(selected),
              onChangeRole: () => _changeRole(selected),
              onUpdateLicense: () => _updateLicense(selected),
              onUploadPhoto: () => _uploadEmployeePhoto(selected),
              onEditProfile:
                  selected.isOwner ? null : () => _editProfile(selected),
              onEditPharmacyProfile:
                  selected.isOwner ? _openPharmacyProfileEdit : null,
              onSetContactEmail:
                  selected.isOwner ? null : () => _setContactEmail(selected),
            ),
        ],
      ),
    );
  }
}

class _EmployeeDetailsDrawer extends StatelessWidget {
  final Employee employee;
  final bool busy;
  final Widget licenseBadge;
  final VoidCallback onClose;
  final VoidCallback onResetPassword;
  final VoidCallback onToggleActive;
  final VoidCallback onChangeRole;
  final VoidCallback onUpdateLicense;
  final VoidCallback onUploadPhoto;
  final VoidCallback? onEditProfile;
  final VoidCallback? onEditPharmacyProfile;
  final VoidCallback? onSetContactEmail;
  final String? photoUrl;

  const _EmployeeDetailsDrawer({
    required this.employee,
    required this.busy,
    required this.licenseBadge,
    required this.photoUrl,
    required this.onClose,
    required this.onResetPassword,
    required this.onToggleActive,
    required this.onChangeRole,
    required this.onUpdateLicense,
    required this.onUploadPhoto,
    this.onEditProfile,
    this.onEditPharmacyProfile,
    this.onSetContactEmail,
  });

  @override
  Widget build(BuildContext context) {
    return TabletDetailsDrawer(
      title: employee.fullName,
      subtitle: '${employee.displayId} · ${employee.roleLabel}',
      statusBadge: StatusBadge(
        employee.isActive ? 'Active' : 'Deactivated',
        tone: employee.isActive ? BadgeTone.success : BadgeTone.danger,
      ),
      onClose: onClose,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: ProfilePhotoAvatar(
              displayName: employee.fullName,
              photoUrl: photoUrl,
              radius: 36,
              onTap: busy ? null : onUploadPhoto,
              showCameraBadge: true,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Center(
            child: Text(
              employee.isPharmacist
                  ? 'Tap to set pharmacist profile photo'
                  : 'Tap to set profile photo',
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          if (onEditProfile != null) ...[
            SizedBox(
              height: 44,
              child: ElevatedButton.icon(
                onPressed: busy ? null : onEditProfile,
                icon: const Icon(Icons.edit_outlined, size: 18, color: Colors.white),
                label: Text(
                  'Edit name',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E6B46),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          if (!employee.isOwner) ...[
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 44,
                    child: OutlinedButton(
                      onPressed: busy ? null : onResetPassword,
                      style: OutlinedButton.styleFrom(
                        backgroundColor: Colors.white,
                        side: const BorderSide(
                          color: Color(0xFFD8E8DE),
                          width: 1.2,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(
                        'Reset password',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF1A2E22),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SizedBox(
                    height: 44,
                    child: ElevatedButton(
                      onPressed: busy ? null : onToggleActive,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: employee.isActive
                            ? AppColors.danger
                            : const Color(0xFF2E6B46),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(
                        employee.isActive ? 'Deactivate' : 'Reactivate',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
          if (employee.isOwner) ...[
            if (onEditPharmacyProfile != null) ...[
              SizedBox(
                height: 44,
                child: ElevatedButton.icon(
                  onPressed: busy ? null : onEditPharmacyProfile,
                  icon: const Icon(Icons.edit_outlined, size: 18, color: Colors.white),
                  label: Text(
                    'Edit profile',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E6B46),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
            SizedBox(
              height: 44,
              child: ElevatedButton(
                onPressed: busy ? null : onUpdateLicense,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E6B46),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(
                  'Update my license',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
          if (!employee.isOwner) ...[
            if (onSetContactEmail != null) ...[
              SizedBox(
                height: 44,
                child: OutlinedButton.icon(
                  onPressed: busy ? null : onSetContactEmail,
                  icon: const Icon(Icons.mail_outline, size: 18, color: Color(0xFF1A2E22)),
                  label: Text(
                    'Set Gmail for password reset',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF1A2E22),
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.white,
                    side: const BorderSide(
                      color: Color(0xFFD8E8DE),
                      width: 1.2,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
            SizedBox(
              height: 44,
              child: OutlinedButton.icon(
                onPressed: busy ? null : onChangeRole,
                icon: const Icon(Icons.swap_horiz, size: 18, color: Color(0xFF1A2E22)),
                label: Text(
                  employee.isPharmacist ? 'Change role to Staff' : 'Promote to Pharmacist',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1A2E22),
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  backgroundColor: Colors.white,
                  side: const BorderSide(
                    color: Color(0xFFD8E8DE),
                    width: 1.2,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
            if (employee.isPharmacist) ...[
              const SizedBox(height: AppSpacing.sm),
              SizedBox(
                height: 44,
                child: OutlinedButton.icon(
                  onPressed: busy ? null : onUpdateLicense,
                  icon: const Icon(Icons.verified_user_outlined, size: 18, color: Color(0xFF1A2E22)),
                  label: Text(
                    'Update / verify PRC license',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF1A2E22),
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.white,
                    side: const BorderSide(
                      color: Color(0xFFD8E8DE),
                      width: 1.2,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
          ],
          _DetailRow('Username', employee.username != null ? '@${employee.username}' : '—'),
          _DetailRow('Role', employee.roleLabel),
          _DetailRow('PRC license no.', employee.prcLicenseNo ?? 'None'),
          _DetailRow(
            'PRC expiry',
            employee.prcLicenseExpiry != null
                ? formatEmployeeDate(employee.prcLicenseExpiry!)
                : '—',
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              const SizedBox(
                width: 120,
                child: Text('License status',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
              ),
              licenseBadge,
            ],
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
