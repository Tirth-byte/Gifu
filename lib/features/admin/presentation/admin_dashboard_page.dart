import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/haptics/app_haptics.dart';
import '../../../core/theme/app_typography.dart';
import '../../auth/presentation/providers/auth_providers.dart';
import '../domain/models/admin_user_summary.dart';
import 'admin_database_grid_page.dart';
import 'providers/admin_providers.dart';
import 'widgets/admin_user_detail_sheet.dart';

const Color _bg = Color(0xFFF7F9F5);
const Color _navy = Color(0xFF1E3365);
const Color _blue = Color(0xFF5880DA);
const Color _muted = Color(0xFF77839A);
const Color _border = Color(0xFFBCDBFA);

/// Simplified, professional Gufi Admin Overview.
/// Eliminates 9-card walls and duplicate user lists in favor of a restrained,
/// high-hierarchy health summary and quick jump to the full Database Grid.
class AdminDashboardPage extends ConsumerStatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  ConsumerState<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends ConsumerState<AdminDashboardPage> {
  bool _loading = true;
  Map<String, int> _metrics = {};
  List<AdminUserSummary> _recentUsers = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final repo = ref.read(adminRepositoryProvider);
    try {
      final metrics = await repo.fetchMetrics();
      final users = await repo.fetchUsers(sortBy: 'Newest');
      if (mounted) {
        setState(() {
          _metrics = metrics;
          _recentUsers = users.take(5).toList();
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _handleLogout() async {
    AppHaptics.light();
    await ref.read(authRepositoryProvider).signOut();
    if (mounted) {
      context.go('/auth');
    }
  }

  void _openDatabase() {
    AppHaptics.selection();
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const AdminDatabaseGridPage()))
        .then((_) => _loadData());
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
          await _loadData();
        },
      ),
    );
  }

  Widget _buildOverviewSummary() {
    final total = _metrics['total'] ?? 0;
    final verified = _metrics['verified'] ?? 0;
    final newToday = _metrics['newToday'] ?? 0;
    final completed = _metrics['completed'] ?? 0;
    final password = _metrics['password'] ?? 0;
    final google = _metrics['google'] ?? 0;
    final apple = _metrics['apple'] ?? 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'System Overview',
                style: AppTypography.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: _navy,
                ),
              ),
              if (_loading)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: _blue,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),

          // Primary metric row
          Row(
            children: [
              _buildMetricItem(label: 'Total users', count: total),
              const SizedBox(width: 18),
              _buildMetricItem(label: 'Verified', count: verified),
              const SizedBox(width: 18),
              _buildMetricItem(label: 'New today', count: newToday),
              const SizedBox(width: 18),
              _buildMetricItem(label: 'Profile complete', count: completed),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0xFFE8EEF5)),
          const SizedBox(height: 12),

          // Secondary provider breakdown
          Wrap(
            spacing: 14,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'Providers:',
                style: AppTypography.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _muted,
                ),
              ),
              _buildProviderTag('Email', password),
              _buildProviderTag('Google', google),
              _buildProviderTag('Apple', apple),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricItem({required String label, required int count}) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            count.toString(),
            style: AppTypography.inter(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: _navy,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.inter(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: _muted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProviderTag(String name, int count) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: const BoxDecoration(color: _blue, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          '$name · $count',
          style: AppTypography.inter(
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
            color: _navy,
          ),
        ),
      ],
    );
  }

  Widget _buildRecentRegistrations() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recent Registrations',
              style: AppTypography.inter(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: _navy,
              ),
            ),
            TextButton(
              onPressed: _openDatabase,
              style: TextButton.styleFrom(
                foregroundColor: _blue,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Open Database',
                    style: AppTypography.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _blue,
                    ),
                  ),
                  const SizedBox(width: 3),
                  const Icon(
                    Icons.arrow_forward_rounded,
                    size: 14,
                    color: _blue,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (_recentUsers.isEmpty && !_loading)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _border.withValues(alpha: 0.6)),
            ),
            child: Column(
              children: [
                const HugeIcon(
                  icon: HugeIcons.strokeRoundedUserAdd01,
                  size: 28,
                  color: _muted,
                ),
                const SizedBox(height: 10),
                Text(
                  'No users yet',
                  style: AppTypography.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
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
          )
        else
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _border.withValues(alpha: 0.6)),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _recentUsers.length,
              separatorBuilder: (context, index) =>
                  const Divider(height: 1, color: Color(0xFFF0F4FA)),
              itemBuilder: (context, index) {
                final user = _recentUsers[index];
                return ListTile(
                  onTap: () => _openUserDetail(user),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  leading: CircleAvatar(
                    radius: 17,
                    backgroundColor: const Color(0xFFE8EEF5),
                    child: Text(
                      user.username.isNotEmpty
                          ? user.username[0].toUpperCase()
                          : 'U',
                      style: AppTypography.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _navy,
                      ),
                    ),
                  ),
                  title: Row(
                    children: [
                      Text(
                        '@${user.username}',
                        style: AppTypography.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: _navy,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: user.authProvider == 'google'
                              ? const Color(0xFFE8F0FE)
                              : (user.authProvider == 'apple'
                                    ? const Color(0xFFF1F3F5)
                                    : const Color(0xFFE6F4EA)),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          user.authProvider == 'google'
                              ? 'Google'
                              : (user.authProvider == 'apple'
                                    ? 'Apple'
                                    : 'Email'),
                          style: AppTypography.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: _navy,
                          ),
                        ),
                      ),
                      if (user.isDisabled) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFDECEC),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Disabled',
                            style: AppTypography.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFFB54848),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  subtitle: Text(
                    user.email,
                    style: AppTypography.inter(fontSize: 12.5, color: _muted),
                  ),
                  trailing: const Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: _muted,
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            // Simplified Minimal Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(bottom: BorderSide(color: _border)),
              ),
              child: Row(
                children: [
                  Text(
                    'Gufi Admin',
                    style: TextStyle(
                      fontFamily: AppTypography.gambarinoFontFamily,
                      fontSize: 24,
                      color: _navy,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const Spacer(),
                  // Database primary button
                  ElevatedButton.icon(
                    onPressed: _openDatabase,
                    icon: const HugeIcon(
                      icon: HugeIcons.strokeRoundedTable01,
                      size: 15,
                      color: Colors.white,
                    ),
                    label: Text(
                      'Database',
                      style: AppTypography.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _blue,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 9,
                      ),
                      minimumSize: const Size(0, 36),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Overflow menu
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, color: _navy, size: 20),
                    onSelected: (action) {
                      if (action == 'refresh') {
                        _loadData();
                      } else if (action == 'logout') {
                        _handleLogout();
                      }
                    },
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'refresh',
                        child: Row(
                          children: [
                            const HugeIcon(
                              icon: HugeIcons.strokeRoundedRefresh,
                              size: 16,
                              color: _navy,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Refresh',
                              style: AppTypography.inter(
                                fontSize: 13.5,
                                color: _navy,
                              ),
                            ),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'logout',
                        child: Row(
                          children: [
                            const HugeIcon(
                              icon: HugeIcons.strokeRoundedLogout01,
                              size: 16,
                              color: Color(0xFFB54848),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Log out',
                              style: AppTypography.inter(
                                fontSize: 13.5,
                                color: const Color(0xFFB54848),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Scrollable Content
            Expanded(
              child: RefreshIndicator(
                color: _blue,
                onRefresh: _loadData,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _buildOverviewSummary(),
                    const SizedBox(height: 20),
                    _buildRecentRegistrations(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
