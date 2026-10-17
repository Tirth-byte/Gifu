import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/haptics/app_haptics.dart';
import '../../../core/theme/app_typography.dart';
import '../domain/models/admin_audit_log.dart';
import '../domain/models/admin_user_summary.dart';
import 'providers/admin_providers.dart';
import 'widgets/admin_user_detail_sheet.dart';

const Color _bg = Color(0xFFFFFFFF);
const Color _navy = Color(0xFF1E3365);
const Color _blue = Color(0xFF5880DA);
const Color _muted = Color(0xFF77839A);
const Color _border = Color(0xFFD3E2F4);
const Color _headerBg = Color(0xFFF2F6FB);
const Color _gridLine = Color(0xFFE5EDF7);
const Color _selectedRow = Color(0xFFEDF3FC);

enum AdminTableTab { users, auditLogs }

/// Live spreadsheet-style database grid view for Gufi Admin.
/// Built strictly around Reference #5: compact, dense, single selection column,
/// row numbers, clean toolbar, sticky header, and horizontal swiping.
class AdminDatabaseGridPage extends ConsumerStatefulWidget {
  const AdminDatabaseGridPage({super.key});

  @override
  ConsumerState<AdminDatabaseGridPage> createState() =>
      _AdminDatabaseGridPageState();
}

class _AdminDatabaseGridPageState extends ConsumerState<AdminDatabaseGridPage> {
  AdminTableTab _currentTab = AdminTableTab.users;
  final TextEditingController _searchController = TextEditingController();
  bool _searchActive = false;

  bool _loading = true;
  List<AdminUserSummary> _users = [];
  List<AdminAuditLog> _auditLogs = [];

  final Set<String> _selectedUserIds = {};

  String _selectedSortField = 'Created At';
  String _selectedSortDirection = 'Newest'; // 'Newest', 'Oldest', 'A-Z', 'Z-A'

  String _filterVerified = 'All';
  String _filterProvider = 'All';
  String _filterProfile = 'All';
  String _filterStatus = 'All';

  final Map<String, bool> _visibleColumns = {
    'Profile': true,
    'Username': true,
    'Display Name': true,
    'Email': true,
    'Verified': true,
    'Provider': true,
    'Status': true,
    'Created At': true,
    'User ID': false,
    'Updated At': false,
    'Profile Complete': false,
  };

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  int get _activeFilterCount {
    int count = 0;
    if (_filterVerified != 'All') count++;
    if (_filterProvider != 'All') count++;
    if (_filterProfile != 'All') count++;
    if (_filterStatus != 'All') count++;
    return count;
  }

  Future<void> _fetchData() async {
    setState(() => _loading = true);
    final repo = ref.read(adminRepositoryProvider);
    try {
      if (_currentTab == AdminTableTab.users) {
        final users = await repo.fetchUsers(query: _searchController.text);
        if (mounted) {
          setState(() {
            _users = _applyLocalFiltersAndSorting(users);
            _loading = false;
          });
        }
      } else {
        final logs = await repo.fetchAuditLogs();
        if (mounted) {
          setState(() {
            _auditLogs = logs;
            _loading = false;
          });
        }
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<AdminUserSummary> _applyLocalFiltersAndSorting(
    List<AdminUserSummary> list,
  ) {
    var filtered = list;

    if (_filterVerified == 'Verified') {
      filtered = filtered.where((u) => u.emailVerified).toList();
    } else if (_filterVerified == 'Unverified') {
      filtered = filtered.where((u) => !u.emailVerified).toList();
    }

    if (_filterProvider == 'Email') {
      filtered = filtered.where((u) => u.authProvider == 'email').toList();
    } else if (_filterProvider == 'Google') {
      filtered = filtered.where((u) => u.authProvider == 'google').toList();
    } else if (_filterProvider == 'Apple') {
      filtered = filtered.where((u) => u.authProvider == 'apple').toList();
    }

    if (_filterProfile == 'Complete') {
      filtered = filtered.where((u) => u.onboardingCompleted).toList();
    } else if (_filterProfile == 'Incomplete') {
      filtered = filtered.where((u) => !u.onboardingCompleted).toList();
    }

    if (_filterStatus == 'Active') {
      filtered = filtered.where((u) => u.isActive).toList();
    } else if (_filterStatus == 'Disabled') {
      filtered = filtered.where((u) => u.isDisabled).toList();
    }

    filtered.sort((a, b) {
      int cmp = 0;
      switch (_selectedSortField) {
        case 'Created At':
          cmp = a.createdAt.compareTo(b.createdAt);
          break;
        case 'Updated At':
          cmp = a.updatedAt.compareTo(b.updatedAt);
          break;
        case 'Username':
          cmp = a.usernameNormalized.compareTo(b.usernameNormalized);
          break;
        case 'Display Name':
          cmp = (a.displayName ?? '').compareTo(b.displayName ?? '');
          break;
        case 'Provider':
          cmp = a.authProvider.compareTo(b.authProvider);
          break;
        case 'Status':
          cmp = a.accountStatus.compareTo(b.accountStatus);
          break;
      }
      final isAsc =
          _selectedSortDirection == 'Oldest' || _selectedSortDirection == 'A-Z';
      return isAsc ? cmp : -cmp;
    });

    return filtered;
  }

  void _openUserDetail(AdminUserSummary user) {
    AppHaptics.selection();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AdminUserDetailSheet(
        user: user,
        onStatusChanged: (newStatus) async {
          final repo = ref.read(adminRepositoryProvider);
          await repo.setUserStatus(targetUserId: user.id, status: newStatus);
          await _fetchData();
        },
      ),
    );
  }

  Future<void> _handleExportUsers({bool selectedOnly = false}) async {
    AppHaptics.medium();
    final repo = ref.read(adminRepositoryProvider);
    final targetUsers = selectedOnly
        ? _users.where((u) => _selectedUserIds.contains(u.id)).toList()
        : _users;

    if (targetUsers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No users to export.'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    await repo.exportUsersCsv(explicitUsers: targetUsers);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Exported ${targetUsers.length} users to CSV. Ready for Excel/Sheets.',
          ),
          backgroundColor: _navy,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  // ==========================================
  // MODALS: SORT, FILTER, HIDE FIELDS, EXPORT
  // ==========================================

  void _showSortSheet() {
    AppHaptics.selection();
    final fields = [
      'Created At',
      'Username',
      'Display Name',
      'Provider',
      'Status',
    ];
    final directions = ['Newest', 'Oldest', 'A-Z', 'Z-A'];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: _border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Sort Database',
                  style: AppTypography.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: _navy,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Sort by field',
                  style: AppTypography.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _muted,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: fields.map((f) {
                    final isSel = _selectedSortField == f;
                    return ChoiceChip(
                      label: Text(f),
                      selected: isSel,
                      selectedColor: const Color(0xFFE8F0FE),
                      backgroundColor: const Color(0xFFFAFBFC),
                      labelStyle: AppTypography.inter(
                        fontSize: 12.5,
                        fontWeight: isSel ? FontWeight.w600 : FontWeight.w500,
                        color: isSel ? _blue : _navy,
                      ),
                      side: BorderSide(color: isSel ? _blue : _border),
                      onSelected: (_) {
                        setModalState(() => _selectedSortField = f);
                        setState(() => _selectedSortField = f);
                        _fetchData();
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),
                Text(
                  'Direction',
                  style: AppTypography.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _muted,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: directions.map((d) {
                    final isSel = _selectedSortDirection == d;
                    return ChoiceChip(
                      label: Text(d),
                      selected: isSel,
                      selectedColor: const Color(0xFFE8F0FE),
                      backgroundColor: const Color(0xFFFAFBFC),
                      labelStyle: AppTypography.inter(
                        fontSize: 12.5,
                        fontWeight: isSel ? FontWeight.w600 : FontWeight.w500,
                        color: isSel ? _blue : _navy,
                      ),
                      side: BorderSide(color: isSel ? _blue : _border),
                      onSelected: (_) {
                        setModalState(() => _selectedSortDirection = d);
                        setState(() => _selectedSortDirection = d);
                        _fetchData();
                      },
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showFilterSheet() {
    AppHaptics.selection();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: _border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Filter Users',
                      style: AppTypography.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: _navy,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        setModalState(() {
                          _filterVerified = 'All';
                          _filterProvider = 'All';
                          _filterProfile = 'All';
                          _filterStatus = 'All';
                        });
                        setState(() {
                          _filterVerified = 'All';
                          _filterProvider = 'All';
                          _filterProfile = 'All';
                          _filterStatus = 'All';
                        });
                        _fetchData();
                      },
                      child: Text(
                        'Clear All',
                        style: AppTypography.inter(fontSize: 13, color: _muted),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                _buildFilterGroup(
                  'Email',
                  ['All', 'Verified', 'Unverified'],
                  _filterVerified,
                  (val) {
                    setModalState(() => _filterVerified = val);
                    setState(() => _filterVerified = val);
                  },
                ),
                const SizedBox(height: 12),

                _buildFilterGroup(
                  'Provider',
                  ['All', 'Email', 'Google', 'Apple'],
                  _filterProvider,
                  (val) {
                    setModalState(() => _filterProvider = val);
                    setState(() => _filterProvider = val);
                  },
                ),
                const SizedBox(height: 12),

                _buildFilterGroup(
                  'Status',
                  ['All', 'Active', 'Disabled'],
                  _filterStatus,
                  (val) {
                    setModalState(() => _filterStatus = val);
                    setState(() => _filterStatus = val);
                  },
                ),
                const SizedBox(height: 12),

                _buildFilterGroup(
                  'Profile',
                  ['All', 'Complete', 'Incomplete'],
                  _filterProfile,
                  (val) {
                    setModalState(() => _filterProfile = val);
                    setState(() => _filterProfile = val);
                  },
                ),
                const SizedBox(height: 18),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      _fetchData();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _blue,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      'Apply Filters',
                      style: AppTypography.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterGroup(
    String title,
    List<String> options,
    String current,
    ValueChanged<String> onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppTypography.inter(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: _muted,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          children: options.map((opt) {
            final isSel = current == opt;
            return ChoiceChip(
              label: Text(opt),
              selected: isSel,
              selectedColor: const Color(0xFFE8F0FE),
              backgroundColor: const Color(0xFFFAFBFC),
              labelStyle: AppTypography.inter(
                fontSize: 12,
                fontWeight: isSel ? FontWeight.w600 : FontWeight.w500,
                color: isSel ? _blue : _navy,
              ),
              side: BorderSide(color: isSel ? _blue : _border),
              onSelected: (_) => onChanged(opt),
            );
          }).toList(),
        ),
      ],
    );
  }

  void _showHideFieldsSheet() {
    AppHaptics.selection();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: _border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Visible Columns',
                  style: AppTypography.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: _navy,
                  ),
                ),
                const SizedBox(height: 12),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 340),
                  child: ListView(
                    shrinkWrap: true,
                    children: _visibleColumns.keys.map((key) {
                      final val = _visibleColumns[key] ?? false;
                      return CheckboxListTile(
                        value: val,
                        dense: true,
                        activeColor: _blue,
                        title: Text(
                          key,
                          style: AppTypography.inter(
                            fontSize: 13.5,
                            color: _navy,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        onChanged: (checked) {
                          setModalState(
                            () => _visibleColumns[key] = checked ?? false,
                          );
                          setState(
                            () => _visibleColumns[key] = checked ?? false,
                          );
                        },
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showExportOptions() {
    AppHaptics.selection();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: _border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Export Database',
                style: AppTypography.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: _navy,
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.table_view_outlined, color: _blue),
                title: Text(
                  'Export all matching users (${_users.length})',
                  style: AppTypography.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _navy,
                  ),
                ),
                subtitle: Text(
                  'Respects active filters and search query as CSV',
                  style: AppTypography.inter(fontSize: 12, color: _muted),
                ),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _handleExportUsers(selectedOnly: false);
                },
              ),
              if (_selectedUserIds.isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.check_box_outlined, color: _blue),
                  title: Text(
                    'Export selected rows (${_selectedUserIds.length})',
                    style: AppTypography.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _navy,
                    ),
                  ),
                  subtitle: Text(
                    'Exports only checked records as CSV',
                    style: AppTypography.inter(fontSize: 12, color: _muted),
                  ),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _handleExportUsers(selectedOnly: true);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // TOP BAR & HORIZONTAL TOOLBAR
  // ==========================================

  Widget _buildTopHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(
                  Icons.chevron_left_rounded,
                  size: 28,
                  color: _navy,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => Navigator.of(context).pop(),
              ),
              const SizedBox(width: 8),
              Text(
                'Database',
                style: TextStyle(
                  fontFamily: AppTypography.gambarinoFontFamily,
                  fontSize: 24,
                  color: _navy,
                  letterSpacing: -0.4,
                ),
              ),
              const Spacer(),
              if (_loading)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: _blue,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),

          // Table Tabs
          Row(
            children: [
              _buildTabButton('Users', AdminTableTab.users),
              const SizedBox(width: 8),
              _buildTabButton('Audit Logs', AdminTableTab.auditLogs),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton(String label, AdminTableTab tab) {
    final isSel = _currentTab == tab;
    return InkWell(
      onTap: () {
        if (_currentTab != tab) {
          AppHaptics.selection();
          setState(() {
            _currentTab = tab;
            _selectedUserIds.clear();
          });
          _fetchData();
        }
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSel ? const Color(0xFFEAF1FC) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSel ? _blue : _border.withValues(alpha: 0.6),
          ),
        ),
        child: Text(
          label,
          style: AppTypography.inter(
            fontSize: 13,
            fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
            color: isSel ? _blue : _navy,
          ),
        ),
      ),
    );
  }

  Widget _buildToolbar() {
    if (_selectedUserIds.isNotEmpty) {
      return Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        color: const Color(0xFFEAF1FC),
        child: Row(
          children: [
            Text(
              '${_selectedUserIds.length} selected',
              style: AppTypography.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _blue,
              ),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: () => _handleExportUsers(selectedOnly: true),
              icon: const Icon(Icons.download_rounded, size: 16, color: _blue),
              label: Text(
                'Export',
                style: AppTypography.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _blue,
                ),
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: () => setState(() => _selectedUserIds.clear()),
              child: Text(
                'Clear',
                style: AppTypography.inter(fontSize: 13, color: _muted),
              ),
            ),
          ],
        ),
      );
    }

    if (_searchActive) {
      return Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        color: Colors.white,
        child: Row(
          children: [
            const Icon(Icons.search, size: 18, color: _muted),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _searchController,
                autofocus: true,
                style: AppTypography.inter(fontSize: 13.5),
                decoration: InputDecoration(
                  hintText: 'Search users',
                  hintStyle: AppTypography.inter(fontSize: 13.5, color: _muted),
                  border: InputBorder.none,
                  isDense: true,
                ),
                onChanged: (_) => _fetchData(),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 18, color: _muted),
              onPressed: () {
                _searchController.clear();
                setState(() => _searchActive = false);
                _fetchData();
              },
            ),
          ],
        ),
      );
    }

    return Container(
      height: 48,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Color(0xFFEAEFF7)),
          bottom: BorderSide(color: Color(0xFFEAEFF7)),
        ),
      ),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        children: [
          _buildToolbarButton(
            icon: Icons.grid_view_rounded,
            label: 'Grid view',
            onTap: () {},
          ),
          const SizedBox(width: 8),
          _buildToolbarButton(
            icon: Icons.swap_vert_rounded,
            label: 'Sort',
            badge:
                _selectedSortField != 'Created At' ||
                    _selectedSortDirection != 'Newest'
                ? '•'
                : null,
            onTap: _showSortSheet,
          ),
          const SizedBox(width: 8),
          _buildToolbarButton(
            icon: Icons.visibility_outlined,
            label: 'Hide fields',
            onTap: _showHideFieldsSheet,
          ),
          const SizedBox(width: 8),
          _buildToolbarButton(
            icon: Icons.filter_list_rounded,
            label: 'Filter',
            badge: _activeFilterCount > 0 ? '$_activeFilterCount' : null,
            onTap: _showFilterSheet,
          ),
          const SizedBox(width: 8),
          _buildToolbarButton(
            icon: Icons.search_rounded,
            label: 'Search',
            onTap: () => setState(() => _searchActive = true),
          ),
          const SizedBox(width: 8),
          _buildToolbarButton(
            icon: Icons.download_rounded,
            label: 'Export',
            onTap: _showExportOptions,
          ),
          const SizedBox(width: 8),
          _buildToolbarButton(
            icon: Icons.refresh_rounded,
            label: 'Refresh',
            onTap: _fetchData,
          ),
        ],
      ),
    );
  }

  Widget _buildToolbarButton({
    required IconData icon,
    required String label,
    String? badge,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: () {
        AppHaptics.selection();
        onTap();
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _border.withValues(alpha: 0.8)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: _navy),
            const SizedBox(width: 5),
            Text(
              label,
              style: AppTypography.inter(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: _navy,
              ),
            ),
            if (badge != null) ...[
              const SizedBox(width: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: _blue,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  badge,
                  style: AppTypography.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ==========================================
  // USERS SPREADSHEET TABLE
  // ==========================================

  Widget _buildUsersTable() {
    if (_users.isEmpty && !_loading) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.table_chart_outlined, size: 36, color: _muted),
              const SizedBox(height: 12),
              Text(
                'No users yet',
                style: AppTypography.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: _navy,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'New registrations will appear here.',
                style: AppTypography.inter(fontSize: 13, color: _muted),
              ),
            ],
          ),
        ),
      );
    }

    final allSelected =
        _users.isNotEmpty && _selectedUserIds.length == _users.length;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const ClampingScrollPhysics(),
      child: SizedBox(
        width: _calculateTableWidth(),
        child: Column(
          children: [
            // Sticky Table Header
            _buildTableHeader(allSelected),

            // Scrollable Table Body
            Expanded(
              child: ListView.builder(
                itemCount: _users.length,
                itemBuilder: (context, index) {
                  final user = _users[index];
                  final isSelected = _selectedUserIds.contains(user.id);
                  return _buildUserRow(index + 1, user, isSelected);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  double _calculateTableWidth() {
    double width = 44 + 44; // # and Selection checkbox
    if (_visibleColumns['Profile'] == true) width += 56;
    if (_visibleColumns['Username'] == true) width += 130;
    if (_visibleColumns['Display Name'] == true) width += 140;
    if (_visibleColumns['Email'] == true) width += 190;
    if (_visibleColumns['Verified'] == true) width += 84;
    if (_visibleColumns['Provider'] == true) width += 96;
    if (_visibleColumns['Status'] == true) width += 96;
    if (_visibleColumns['Created At'] == true) width += 120;
    if (_visibleColumns['User ID'] == true) width += 120;
    if (_visibleColumns['Updated At'] == true) width += 120;
    if (_visibleColumns['Profile Complete'] == true) width += 120;
    return width < 600 ? 600 : width;
  }

  Widget _buildTableHeader(bool allSelected) {
    return Container(
      height: 48,
      decoration: const BoxDecoration(
        color: _headerBg,
        border: Border(bottom: BorderSide(color: _gridLine, width: 1.2)),
      ),
      child: Row(
        children: [
          // 1. # Row number column
          _headerCell('#', 44, centered: true),
          // 2. Selection checkbox column
          SizedBox(
            width: 44,
            child: Checkbox(
              value: allSelected,
              activeColor: _blue,
              onChanged: (val) {
                AppHaptics.selection();
                setState(() {
                  if (val == true) {
                    _selectedUserIds.addAll(_users.map((u) => u.id));
                  } else {
                    _selectedUserIds.clear();
                  }
                });
              },
            ),
          ),
          if (_visibleColumns['Profile'] == true)
            _headerCell('Profile', 56, centered: true),
          if (_visibleColumns['Username'] == true) _headerCell('Username', 130),
          if (_visibleColumns['Display Name'] == true)
            _headerCell('Display Name', 140),
          if (_visibleColumns['Email'] == true) _headerCell('Email', 190),
          if (_visibleColumns['Verified'] == true)
            _headerCell('Verified', 84, centered: true),
          if (_visibleColumns['Provider'] == true) _headerCell('Provider', 96),
          if (_visibleColumns['Status'] == true) _headerCell('Status', 96),
          if (_visibleColumns['Created At'] == true)
            _headerCell('Created At', 120),
          if (_visibleColumns['User ID'] == true) _headerCell('User ID', 120),
          if (_visibleColumns['Updated At'] == true)
            _headerCell('Updated At', 120),
          if (_visibleColumns['Profile Complete'] == true)
            _headerCell('Complete', 120, centered: true),
        ],
      ),
    );
  }

  Widget _headerCell(String title, double width, {bool centered = false}) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      alignment: centered ? Alignment.center : Alignment.centerLeft,
      decoration: const BoxDecoration(
        border: Border(right: BorderSide(color: _gridLine)),
      ),
      child: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTypography.inter(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: _navy,
        ),
      ),
    );
  }

  Widget _buildUserRow(int rowIndex, AdminUserSummary user, bool isSelected) {
    return InkWell(
      onTap: () => _openUserDetail(user),
      child: Container(
        height: 54,
        decoration: BoxDecoration(
          color: isSelected ? _selectedRow : Colors.white,
          border: const Border(bottom: BorderSide(color: _gridLine)),
        ),
        child: Row(
          children: [
            // Row number
            Container(
              width: 44,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                border: Border(right: BorderSide(color: _gridLine)),
              ),
              child: Text(
                '$rowIndex',
                style: AppTypography.inter(
                  fontSize: 12.5,
                  color: _muted,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            // Selection checkbox
            Container(
              width: 44,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                border: Border(right: BorderSide(color: _gridLine)),
              ),
              child: Checkbox(
                value: isSelected,
                activeColor: _blue,
                onChanged: (val) {
                  AppHaptics.selection();
                  setState(() {
                    if (val == true) {
                      _selectedUserIds.add(user.id);
                    } else {
                      _selectedUserIds.remove(user.id);
                    }
                  });
                },
              ),
            ),
            // Profile avatar
            if (_visibleColumns['Profile'] == true)
              Container(
                width: 56,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  border: Border(right: BorderSide(color: _gridLine)),
                ),
                child: CircleAvatar(
                  radius: 15,
                  backgroundColor: const Color(0xFFE8EEF5),
                  child: Text(
                    user.username.isNotEmpty
                        ? user.username[0].toUpperCase()
                        : 'U',
                    style: AppTypography.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: _navy,
                    ),
                  ),
                ),
              ),
            // Username
            if (_visibleColumns['Username'] == true)
              _cell('@${user.username}', 130, isBold: true),
            // Display Name
            if (_visibleColumns['Display Name'] == true)
              _cell(user.displayName ?? '—', 140),
            // Email
            if (_visibleColumns['Email'] == true) _cell(user.email, 190),
            // Verified
            if (_visibleColumns['Verified'] == true)
              Container(
                width: 84,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  border: Border(right: BorderSide(color: _gridLine)),
                ),
                child: user.emailVerified
                    ? const Icon(
                        Icons.check_circle,
                        size: 16,
                        color: Color(0xFF3D7A62),
                      )
                    : const Text('—', style: TextStyle(color: _muted)),
              ),
            // Provider
            if (_visibleColumns['Provider'] == true)
              _cell(
                user.authProvider == 'google'
                    ? 'Google'
                    : (user.authProvider == 'apple' ? 'Apple' : 'Email'),
                96,
              ),
            // Status
            if (_visibleColumns['Status'] == true)
              Container(
                width: 96,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                alignment: Alignment.centerLeft,
                decoration: const BoxDecoration(
                  border: Border(right: BorderSide(color: _gridLine)),
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2.5,
                  ),
                  decoration: BoxDecoration(
                    color: user.isActive
                        ? const Color(0xFFEBF7F0)
                        : const Color(0xFFFDECEC),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    user.isActive ? 'Active' : 'Disabled',
                    style: AppTypography.inter(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: user.isActive
                          ? const Color(0xFF3D7A62)
                          : const Color(0xFFB54848),
                    ),
                  ),
                ),
              ),
            // Created At
            if (_visibleColumns['Created At'] == true)
              _cell(_formatDate(user.createdAt), 120),
            // Optional: User ID
            if (_visibleColumns['User ID'] == true) _cell(user.id, 120),
            // Optional: Updated At
            if (_visibleColumns['Updated At'] == true)
              _cell(_formatDate(user.updatedAt), 120),
            // Optional: Profile Complete
            if (_visibleColumns['Profile Complete'] == true)
              Container(
                width: 120,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  border: Border(right: BorderSide(color: _gridLine)),
                ),
                child: Text(
                  user.onboardingCompleted ? 'Complete' : 'Incomplete',
                  style: AppTypography.inter(
                    fontSize: 12,
                    color: user.onboardingCompleted
                        ? const Color(0xFF3D7A62)
                        : _muted,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _cell(String text, double width, {bool isBold = false}) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      alignment: Alignment.centerLeft,
      decoration: const BoxDecoration(
        border: Border(right: BorderSide(color: _gridLine)),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTypography.inter(
          fontSize: 13.5,
          fontWeight: isBold ? FontWeight.w600 : FontWeight.w400,
          color: _navy,
        ),
      ),
    );
  }

  // ==========================================
  // AUDIT LOGS SPREADSHEET TABLE
  // ==========================================

  Widget _buildAuditLogsTable() {
    if (_auditLogs.isEmpty && !_loading) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.history_toggle_off_rounded,
                size: 36,
                color: _muted,
              ),
              const SizedBox(height: 12),
              Text(
                'No admin activity yet',
                style: AppTypography.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: _navy,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Administrative operations will be recorded here.',
                style: AppTypography.inter(fontSize: 13, color: _muted),
              ),
            ],
          ),
        ),
      );
    }

    const double tableWidth = 44 + 130 + 150 + 130 + 140 + 180;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const ClampingScrollPhysics(),
      child: SizedBox(
        width: tableWidth,
        child: Column(
          children: [
            // Header
            Container(
              height: 48,
              decoration: const BoxDecoration(
                color: _headerBg,
                border: Border(
                  bottom: BorderSide(color: _gridLine, width: 1.2),
                ),
              ),
              child: Row(
                children: [
                  _headerCell('#', 44, centered: true),
                  _headerCell('Timestamp', 130),
                  _headerCell('Admin', 150),
                  _headerCell('Action', 130),
                  _headerCell('Target', 140),
                  _headerCell('Metadata / Details', 180),
                ],
              ),
            ),
            // Body
            Expanded(
              child: ListView.builder(
                itemCount: _auditLogs.length,
                itemBuilder: (context, index) {
                  final log = _auditLogs[index];
                  return Container(
                    height: 52,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      border: Border(bottom: BorderSide(color: _gridLine)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          alignment: Alignment.center,
                          decoration: const BoxDecoration(
                            border: Border(right: BorderSide(color: _gridLine)),
                          ),
                          child: Text(
                            '${index + 1}',
                            style: AppTypography.inter(
                              fontSize: 12.5,
                              color: _muted,
                            ),
                          ),
                        ),
                        _cell(_formatDate(log.createdAt), 130),
                        _cell(log.adminEmail ?? log.adminUserId, 150),
                        _cell(log.humanAction, 130, isBold: true),
                        _cell(log.targetEmail ?? log.targetUserId ?? '—', 140),
                        _cell(
                          log.details ?? log.metadata?.toString() ?? '—',
                          180,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopHeader(),
            _buildToolbar(),
            Expanded(
              child: RefreshIndicator(
                color: _blue,
                onRefresh: _fetchData,
                child: _currentTab == AdminTableTab.users
                    ? _buildUsersTable()
                    : _buildAuditLogsTable(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
