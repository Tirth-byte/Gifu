import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/haptics/app_haptics.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../circles/domain/models/circle.dart';
import '../../../circles/presentation/providers/circle_providers.dart';
import '../../../commitments/domain/models/accountability_scope.dart';

/// Redesigned lightweight Make Promise Sheet.
/// Asks only:
/// - WHAT am I promising?
/// - WHO keeps you accountable? (Accountability Circle or Private)
/// - WHEN is it due?
///
/// Private promises do NOT affect Momentum and have no peer review.
class MakePromiseSheet extends ConsumerStatefulWidget {
  const MakePromiseSheet({super.key, required this.onCommit});

  final Future<void> Function({
    required String title,
    String? circleId,
    required AccountabilityScope accountabilityScope,
    DateTime? dueAt,
  })
  onCommit;

  @override
  ConsumerState<MakePromiseSheet> createState() => _MakePromiseSheetState();
}

class _MakePromiseSheetState extends ConsumerState<MakePromiseSheet> {
  final TextEditingController _titleController = TextEditingController();
  final FocusNode _titleFocusNode = FocusNode();

  AccountabilityScope _selectedScope = AccountabilityScope.circle;
  String? _selectedCircleId;
  String? _selectedCircleName;
  bool _preselected = false;

  TimeOfDay? _specificDueTime;
  bool _submitting = false;
  String? _errorMessage;

  static const Color primaryBlue = Color(0xFF5880DA);
  static const Color gufiNavy = Color(0xFF1E3365);
  static const Color mutedText = Color(0xFF768B9E);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _titleFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _titleFocusNode.dispose();
    super.dispose();
  }

  void _ensurePreselection(List<Circle> circles) {
    if (_preselected) return;
    _preselected = true;
    if (circles.length == 1) {
      _selectedCircleId = circles.first.id;
      _selectedCircleName = circles.first.name;
      _selectedScope = AccountabilityScope.circle;
    }
  }

  String _displayAccountabilityValue() {
    if (_selectedScope == AccountabilityScope.private) {
      return 'Private';
    }
    if (_selectedCircleName != null && _selectedCircleName!.isNotEmpty) {
      return _selectedCircleName!;
    }
    return 'Choose a circle';
  }

  DateTime? _computeDueDateTime() {
    if (_specificDueTime == null) return null;
    final now = DateTime.now();
    return DateTime(
      now.year,
      now.month,
      now.day,
      _specificDueTime!.hour,
      _specificDueTime!.minute,
    ).toUtc();
  }

  Future<void> _handleCommit() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      setState(() => _errorMessage = 'Please name your promise.');
      return;
    }

    if (_selectedScope == AccountabilityScope.circle &&
        _selectedCircleId == null) {
      setState(
        () => _errorMessage =
            'Please choose an accountability circle or keep it private.',
      );
      return;
    }

    setState(() {
      _submitting = true;
      _errorMessage = null;
    });

    try {
      AppHaptics.light();
      await widget.onCommit(
        title: title,
        circleId: _selectedScope == AccountabilityScope.circle
            ? _selectedCircleId
            : null,
        accountabilityScope: _selectedScope,
        dueAt: _computeDueDateTime(),
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() {
          _submitting = false;
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  Future<void> _openAccountabilityPicker(List<Circle> circles) async {
    AppHaptics.selection();
    _titleFocusNode.unfocus();

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Modal Drag Handle
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: gufiNavy.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Who keeps you accountable?',
                  style: TextStyle(
                    fontFamily: AppTypography.gambarinoFontFamily,
                    fontSize: 22,
                    color: gufiNavy,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Socially verified promises build real Momentum.',
                  style: AppTypography.inter(
                    fontSize: 13,
                    color: gufiNavy.withValues(alpha: 0.55),
                  ),
                ),
                const SizedBox(height: 16),

                // 1. Circle Options (Primary default path)
                if (circles.isNotEmpty) ...[
                  ...circles.map(
                    (c) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: primaryBlue.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.group_outlined,
                          size: 20,
                          color: primaryBlue,
                        ),
                      ),
                      title: Text(
                        c.name,
                        style: AppTypography.inter(
                          fontSize: 15,
                          fontWeight:
                              (_selectedScope == AccountabilityScope.circle &&
                                  _selectedCircleId == c.id)
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color: gufiNavy,
                        ),
                      ),
                      trailing:
                          (_selectedScope == AccountabilityScope.circle &&
                              _selectedCircleId == c.id)
                          ? const Icon(Icons.check_rounded, color: primaryBlue)
                          : null,
                      onTap: () {
                        setState(() {
                          _selectedScope = AccountabilityScope.circle;
                          _selectedCircleId = c.id;
                          _selectedCircleName = c.name;
                          _errorMessage = null;
                        });
                        Navigator.pop(ctx);
                      },
                    ),
                  ),
                ] else ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'No active circles found. Choose private below or join a circle.',
                      style: AppTypography.inter(
                        fontSize: 13,
                        color: gufiNavy.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 12),
                Divider(
                  height: 1,
                  thickness: 1,
                  color: gufiNavy.withValues(alpha: 0.08),
                ),
                const SizedBox(height: 12),

                // 2. Secondary Alternative: Keep it private
                InkWell(
                  onTap: () {
                    setState(() {
                      _selectedScope = AccountabilityScope.private;
                      _selectedCircleId = null;
                      _selectedCircleName = null;
                      _errorMessage = null;
                    });
                    Navigator.pop(ctx);
                  },
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: _selectedScope == AccountabilityScope.private
                          ? primaryBlue.withValues(alpha: 0.06)
                          : const Color(0xFFFAFBFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: _selectedScope == AccountabilityScope.private
                            ? primaryBlue.withValues(alpha: 0.25)
                            : gufiNavy.withValues(alpha: 0.06),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.lock_outline_rounded,
                          size: 20,
                          color: _selectedScope == AccountabilityScope.private
                              ? primaryBlue
                              : mutedText,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Keep it private',
                                style: AppTypography.inter(
                                  fontSize: 15,
                                  fontWeight:
                                      _selectedScope ==
                                          AccountabilityScope.private
                                      ? FontWeight.w600
                                      : FontWeight.w500,
                                  color: gufiNavy,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                "Personal promise · Doesn't affect Momentum",
                                style: AppTypography.inter(
                                  fontSize: 12,
                                  color: gufiNavy.withValues(alpha: 0.5),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (_selectedScope == AccountabilityScope.private)
                          const Icon(Icons.check_rounded, color: primaryBlue),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openDueTimePicker() async {
    AppHaptics.selection();
    _titleFocusNode.unfocus();

    final picked = await showTimePicker(
      context: context,
      initialTime:
          _specificDueTime ??
          const TimeOfDay(hour: 22, minute: 0), // 10:00 PM default
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: primaryBlue,
              onPrimary: Colors.white,
              onSurface: gufiNavy,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() => _specificDueTime = picked);
    }
  }

  String _formatDueTime() {
    if (_specificDueTime == null) {
      return 'Today · Anytime';
    }
    final hour = _specificDueTime!.hourOfPeriod == 0
        ? 12
        : _specificDueTime!.hourOfPeriod;
    final minute = _specificDueTime!.minute.toString().padLeft(2, '0');
    final period = _specificDueTime!.period == DayPeriod.am ? 'AM' : 'PM';
    return 'Today by $hour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProfileProvider);
    final circlesAsync = user != null
        ? ref.watch(userCirclesProvider(user.id))
        : const AsyncValue<List<Circle>>.data([]);

    final circles = circlesAsync.value ?? [];
    if (circles.isNotEmpty) {
      _ensurePreselection(circles);
    }

    return Container(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 28,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Small drag handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: gufiNavy.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          const SizedBox(height: 18),

          // Gambarino Title
          Text(
            'What will you do?',
            style: TextStyle(
              fontFamily: AppTypography.gambarinoFontFamily,
              fontSize: 26,
              fontWeight: FontWeight.w400,
              color: gufiNavy,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 4),

          // Subtitle
          Text(
            'Make one promise worth keeping today.',
            style: AppTypography.inter(
              fontSize: 14,
              color: gufiNavy.withValues(alpha: 0.55),
            ),
          ),

          const SizedBox(height: 18),

          // Large clean text input
          TextField(
            controller: _titleController,
            focusNode: _titleFocusNode,
            textCapitalization: TextCapitalization.sentences,
            style: AppTypography.inter(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: gufiNavy,
            ),
            decoration: InputDecoration(
              hintText: 'Run 3 km before dinner',
              hintStyle: AppTypography.inter(
                fontSize: 17,
                color: gufiNavy.withValues(alpha: 0.3),
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide(color: gufiNavy.withValues(alpha: 0.08)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide(color: gufiNavy.withValues(alpha: 0.08)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: const BorderSide(color: primaryBlue, width: 1.5),
              ),
            ),
          ),

          if (_errorMessage != null) ...[
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              style: AppTypography.inter(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: const Color(0xFFDC2626),
              ),
            ),
          ],

          const SizedBox(height: 16),

          // Two Compact Selector Rows:
          // Row 1: WHO KEEPS YOU ACCOUNTABLE?
          _buildCompactSelectorRow(
            label: 'WHO KEEPS YOU ACCOUNTABLE?',
            value: _displayAccountabilityValue(),
            onTap: () => _openAccountabilityPicker(circles),
          ),

          // Tiny explanatory note when user selects Private (Section 5)
          if (_selectedScope == AccountabilityScope.private) ...[
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 4, right: 4),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 13,
                    color: gufiNavy.withValues(alpha: 0.45),
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      "Private promises aren't peer-verified and don't affect Momentum.",
                      style: AppTypography.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: gufiNavy.withValues(alpha: 0.55),
                        height: 1.25,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 10),

          // Row 2: WHEN?
          _buildCompactSelectorRow(
            label: 'WHEN?',
            value: _formatDueTime(),
            onTap: _openDueTimePicker,
            trailingAction: _specificDueTime != null
                ? InkWell(
                    onTap: () => setState(() => _specificDueTime = null),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Icon(
                        Icons.close_rounded,
                        size: 16,
                        color: gufiNavy.withValues(alpha: 0.4),
                      ),
                    ),
                  )
                : null,
          ),

          const SizedBox(height: 24),

          // Primary CTA: "Commit" (Not "+ Commit promise")
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _submitting ? null : _handleCommit,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryBlue,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(22),
                ),
              ),
              child: _submitting
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      'Commit',
                      style: AppTypography.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        letterSpacing: -0.2,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactSelectorRow({
    required String label,
    required String value,
    required VoidCallback onTap,
    Widget? trailingAction,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFFAFBFC),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: gufiNavy.withValues(alpha: 0.06),
            width: 1.0,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTypography.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: gufiNavy.withValues(alpha: 0.45),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: AppTypography.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: gufiNavy,
                  ),
                ),
              ],
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ?trailingAction,
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: gufiNavy.withValues(alpha: 0.35),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
