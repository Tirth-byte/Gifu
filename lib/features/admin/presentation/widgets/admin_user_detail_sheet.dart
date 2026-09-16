import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/haptics/app_haptics.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/models/admin_user_summary.dart';

const Color _navy = Color(0xFF1E3365);
const Color _muted = Color(0xFF77839A);
const Color _border = Color(0xFFBCDBFA);
const Color _errorRed = Color(0xFFB54848);
const Color _success = Color(0xFF3D7A62);

/// Modal sheet displaying safe user metadata with confirmation-protected status actions.
class AdminUserDetailSheet extends StatelessWidget {
  final AdminUserSummary user;
  final Future<void> Function(String newStatus)? onStatusChanged;
  final Future<void> Function(String targetUserId, String newStatus)?
  onToggleStatus;

  const AdminUserDetailSheet({
    super.key,
    required this.user,
    this.onStatusChanged,
    this.onToggleStatus,
  });

  Future<void> _confirmToggleStatus(BuildContext context) async {
    final willDisable = user.isActive;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          willDisable
              ? 'Disable @${user.username}?'
              : 'Re-enable @${user.username}?',
          style: AppTypography.inter(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: _navy,
          ),
        ),
        content: Text(
          willDisable
              ? 'This user will no longer be able to log in or access Gufi until re-enabled.'
              : 'This user will regain full access to their Gufi account.',
          style: AppTypography.inter(fontSize: 14, color: _muted, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Cancel',
              style: AppTypography.inter(fontSize: 14, color: _muted),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: willDisable ? _errorRed : _success,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(
              willDisable ? 'Disable Account' : 'Re-enable Account',
              style: AppTypography.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      AppHaptics.medium();
      final newStatus = willDisable ? 'disabled' : 'active';
      if (onStatusChanged != null) {
        await onStatusChanged!(newStatus);
      }
      if (onToggleStatus != null) {
        await onToggleStatus!(user.id, newStatus);
      }
      if (context.mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag Handle
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
          const SizedBox(height: 18),

          // User Header
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFE8EEF5),
                  border: Border.all(color: _border),
                ),
                child: const Center(
                  child: HugeIcon(
                    icon: HugeIcons.strokeRoundedUser,
                    size: 24,
                    color: _navy,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '@${user.username}',
                      style: AppTypography.inter(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: _navy,
                      ),
                    ),
                    Text(
                      user.email,
                      style: AppTypography.inter(fontSize: 13, color: _muted),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: user.isActive
                      ? const Color(0xFFE6F4EA)
                      : const Color(0xFFFCE8E6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  user.accountStatus.toUpperCase(),
                  style: AppTypography.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: user.isActive ? _success : _errorRed,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 12),

          // Safe Metadata Fields
          _buildField('User ID', user.id),
          _buildField('Display Name', user.displayName ?? '—'),
          _buildField('Email Verified', user.emailVerified ? 'YES' : 'NO'),
          _buildField('Auth Provider', user.authProvider.toUpperCase()),
          _buildField(
            'Profile Status',
            user.onboardingCompleted ? 'Completed' : 'Incomplete',
          ),
          _buildField('Role', user.role.toUpperCase()),
          _buildField(
            'Created At (UTC)',
            user.createdAt.toUtc().toString().split('.').first,
          ),
          _buildField(
            'Last Updated (UTC)',
            user.updatedAt.toUtc().toString().split('.').first,
          ),

          const SizedBox(height: 24),

          // Action Button
          ElevatedButton(
            onPressed: () => _confirmToggleStatus(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: user.isActive
                  ? const Color(0xFFFCE8E6)
                  : const Color(0xFFE6F4EA),
              foregroundColor: user.isActive ? _errorRed : _success,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(
                  color: user.isActive
                      ? const Color(0x4DB54848)
                      : const Color(0x4D3D7A62),
                ),
              ),
            ),
            child: Text(
              user.isActive ? 'Disable User Account' : 'Re-enable User Account',
              style: AppTypography.inter(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildField(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTypography.inter(fontSize: 13, color: _muted)),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: AppTypography.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _navy,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
