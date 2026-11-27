import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

// Ph-33 & Ph-34: Branch owner views employees, adds staff, changes roles,
// updates/verifies PRC licenses, resets passwords, and toggles account status.
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

  Future<void> _runAction(Future<void> Function() work) async {
    setState(() {
      _busyAction = true;
      _offline = false;
    });
    try {
      await work();
    } on AppFailure catch (error) {
      if (!mounted) return;
      if (error.message == 'Could not reach Supabase.') {
        setState(() => _offline = true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message)),
        );
      }
    } finally {
      if (mounted) setState(() => _busyAction = false);
    }
  }

  Future<void> _addEmployee() async {
    final created = await showAddEmployeeDialog(
      context,
      onSubmit: ({
        required firstName,
        middleName,
        required lastName,
        required username,
        required role,
        prcLicenseNo,
        prcLicenseExpiry,
      }) {
        return ref.read(employeesProvider.notifier).createEmployee(
              firstName: firstName,
              middleName: middleName,
              lastName: lastName,
              username: username,
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
      username: null,
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

    await _runAction(() async {
      await ref.read(employeesProvider.notifier).setActive(
            employeeId: employee.accountId,
            isActive: nextActive,
          );
    });
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

    await _runAction(() async {
      await ref.read(employeesProvider.notifier).changeRole(
            employeeId: employee.accountId,
            newRole: nextRole,
            prcLicenseNo: prcNo,
            prcLicenseExpiry: prcExpiry,
          );
    });
  }

  Future<void> _uploadEmployeePhoto(Employee employee) async {
    final picked = await pickProfileImageBytes(context);
    if (picked == null || !mounted) return;
    await _runAction(() async {
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
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Employee photo updated.')),
    );
  }

  Future<void> _editProfile(Employee employee) async {
    final draft = await showEditEmployeeProfileDialog(
      context,
      employee: employee,
    );
    if (draft == null || !mounted) return;

    await _runAction(() async {
      await ref.read(employeesProvider.notifier).updateProfile(
            employeeId: employee.accountId,
            firstName: draft.firstName,
            middleName: draft.middleName,
            lastName: draft.lastName,
          );
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Employee profile updated.')),
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

    await _runAction(() async {
      await ref.read(employeesProvider.notifier).updateLicense(
            employeeId: employee.accountId,
            prcLicenseNo: result.prcLicenseNo,
            prcLicenseExpiry: result.prcLicenseExpiry,
            markVerified: result.markVerified,
            ownerConfirmed: employee.isOwner,
          );
    });
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
                                TabletColumn(title: 'Employee', flex: 2),
                                TabletColumn(
                                  title: 'Username',
                                  priority: TabletColumnPriority.medium,
                                ),
                                TabletColumn(title: 'Role'),
                                TabletColumn(
                                  title: 'PRC License',
                                  priority: TabletColumnPriority.medium,
                                  flex: 2,
                                ),
                                TabletColumn(title: 'Status'),
                              ],
                              items: filtered,
                              onItemTap: (emp) => setState(() => _selectedId = emp.accountId),
                              rowBuilder: (context, emp, index) => [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      emp.fullName,
                                      style: const TextStyle(fontWeight: FontWeight.w600),
                                    ),
                                    Text(
                                      emp.displayId,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                                Text(emp.username != null ? '@${emp.username}' : '—'),
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
                                    : Wrap(
                                        spacing: 8,
                                        crossAxisAlignment: WrapCrossAlignment.center,
                                        children: [
                                          Text(emp.prcLicenseNo!),
                                          _licenseBadge(emp),
                                        ],
                                      ),
                                StatusBadge(
                                  emp.isActive ? 'Active' : 'Deactivated',
                                  tone: emp.isActive ? BadgeTone.success : BadgeTone.danger,
                                ),
                              ],
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
      actions: employee.isOwner
          ? [
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
            ]
          : [
              SizedBox(
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
              SizedBox(
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
            ],
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
            const SizedBox(height: AppSpacing.md),
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
          if (!employee.isOwner) ...[
            const SizedBox(height: AppSpacing.xl),
            const Divider(),
            const SizedBox(height: AppSpacing.md),
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
          ],
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
