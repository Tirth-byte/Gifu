import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../core/haptics/app_haptics.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/uuid_util.dart';
import '../../../core/widgets/account_action_button.dart';
import '../../auth/data/repositories/supabase_auth_repository.dart';
import '../data/repositories/supabase_circle_repository.dart';

/// Create a Circle — Step 1: Circle Identity & Purpose
///
/// Production-quality, warm, premium, Gen Z friendly first step of
/// the Create a Circle flow.
///
/// Refined composition:
/// - Top Bar: Back arrow + "Create a Circle"
/// - Editorial Headline: "Name your Circle." (Gambarino, navy)
/// - Subtitle: "Give your group a name and a reason to show up together."
/// - Form: Circle name (3-24 chars) + Purpose (0-80 chars)
/// - Compact Privacy Card: "Private by default"
/// - Connected Continue CTA: sits directly beneath the privacy card (28-36px gap)
/// - Stable composition: NO scroll when keyboard is closed; utility scroll only when keyboard is open
class CircleCreatePage extends StatefulWidget {
  final VoidCallback? onCreated;

  const CircleCreatePage({super.key, this.onCreated});

  @override
  State<CircleCreatePage> createState() => _CircleCreatePageState();
}

class _CircleCreatePageState extends State<CircleCreatePage> {
  final _nameController = TextEditingController();
  final _purposeController = TextEditingController();
  final _nameFocusNode = FocusNode();
  final _purposeFocusNode = FocusNode();

  bool _isNameFocused = false;
  bool _isPurposeFocused = false;
  bool _submittedAttempted = false;
  bool _isCreating = false;
  String? _creationRequestId;

  static const Color canvasColor = Color(0xFFFFFFFF);
  static const Color gufiNavy = Color(0xFF1E3365);
  static const Color gufiBlue = Color(0xFF5880DA);
  static const Color mutedSlate = Color(0xFF5C6E8C);
  static const Color errorColor = Color(0xFFE5484D);

  @override
  void initState() {
    super.initState();
    _nameController.addListener(_onTextChanged);
    _purposeController.addListener(_onTextChanged);

    _nameFocusNode.addListener(() {
      setState(() => _isNameFocused = _nameFocusNode.hasFocus);
    });
    _purposeFocusNode.addListener(() {
      setState(() => _isPurposeFocused = _purposeFocusNode.hasFocus);
    });
  }

  @override
  void dispose() {
    _nameController.removeListener(_onTextChanged);
    _purposeController.removeListener(_onTextChanged);
    _nameController.dispose();
    _purposeController.dispose();
    _nameFocusNode.dispose();
    _purposeFocusNode.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    _creationRequestId = null;
    setState(() {});
  }

  String get _trimmedName => _nameController.text.trim();

  bool get _isNameValid =>
      _trimmedName.length >= 3 && _trimmedName.length <= 24;

  String? get _nameError {
    if (!_submittedAttempted && _trimmedName.isEmpty) return null;
    if (_trimmedName.isEmpty) {
      return 'Give your Circle a name.';
    }
    if (_trimmedName.length < 3) {
      return 'Circle name must be at least 3 characters.';
    }
    if (_trimmedName.length > 24) {
      return 'Circle name must be 24 characters or less.';
    }
    return null;
  }

  void _handleContinue() async {
    if (_isCreating) return;
    setState(() => _submittedAttempted = true);

    if (!_isNameValid) {
      AppHaptics.warning();
      _nameFocusNode.requestFocus();
      return;
    }

    AppHaptics.selection();
    setState(() => _isCreating = true);

    final requestId = _creationRequestId ??= UuidUtil.generateV4();

    // Persist circle creation into store
    try {
      final currentUserId =
          SupabaseAuthRepository.instance.currentUserProfile?.id ??
          'usr-local-creator';
      final circle = await SupabaseCircleRepository.instance.createCircle(
        name: _trimmedName,
        ownerId: currentUserId,
        description: _purposeController.text.trim().isNotEmpty
            ? _purposeController.text.trim()
            : null,
        requestId: requestId,
      );

      if (mounted) {
        _creationRequestId = null;
        setState(() => _isCreating = false);
        if (widget.onCreated != null) {
          widget.onCreated!();
        } else {
          context.pushReplacement('/circle-invite/${circle.id}');
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isCreating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final isKeyboardOpen = mediaQuery.viewInsets.bottom > 0;
    final isCompact = mediaQuery.size.height < 750;

    // Responsive tight spacing
    final gapTopBarToHeadline = isCompact ? 20.0 : 28.0;
    final gapHeadlineToSubtitle = isCompact ? 8.0 : 12.0;
    final gapSubtitleToFirstField = isCompact ? 24.0 : 32.0;
    final gapBetweenFields = isCompact ? 14.0 : 18.0;
    final gapFieldsToPrivacy = isCompact ? 16.0 : 20.0;
    final gapPrivacyToCta = isCompact ? 26.0 : 32.0;

    return Scaffold(
      backgroundColor: canvasColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Top Bar: Elegant back navigation + title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(
                      CupertinoIcons.arrow_left,
                      color: gufiNavy,
                      size: 22,
                    ),
                    splashRadius: 24,
                    onPressed: () {
                      AppHaptics.selection();
                      if (context.canPop()) {
                        context.pop();
                      } else {
                        context.go('/circle-entry');
                      }
                    },
                  ),
                  Text(
                    'Create a Circle',
                    style: TextStyle(
                      fontFamily: AppTypography.gambarinoFontFamily,
                      fontSize: 20,
                      fontWeight: FontWeight.w400,
                      color: gufiNavy,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const AccountActionButton(),
                ],
              ),
            ),

            // 2. Form Area: Fixed composition when keyboard closed; utility scroll when keyboard open
            Expanded(
              child: SingleChildScrollView(
                physics: isKeyboardOpen
                    ? const ClampingScrollPhysics()
                    : const NeverScrollableScrollPhysics(),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: gapTopBarToHeadline),

                    // Main Headline: "Name your Circle." in Gambarino
                    Text(
                      'Name your Circle.',
                      style: TextStyle(
                        fontFamily: AppTypography.gambarinoFontFamily,
                        fontSize: isCompact ? 28 : 32,
                        fontWeight: FontWeight.w400,
                        color: gufiNavy,
                        letterSpacing: -0.8,
                        height: 1.1,
                      ),
                    ),

                    SizedBox(height: gapHeadlineToSubtitle),

                    // Supporting Copy
                    Text(
                      'Give your group a name and a reason to show up together.',
                      style: AppTypography.inter(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w400,
                        color: mutedSlate,
                        height: 1.35,
                      ),
                    ),

                    SizedBox(height: gapSubtitleToFirstField),

                    // Field 1: Circle name
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Circle name',
                          style: AppTypography.inter(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: gufiNavy,
                          ),
                        ),
                        Text(
                          '${_trimmedName.length}/24',
                          style: AppTypography.inter(
                            fontSize: 12.0,
                            fontWeight: FontWeight.w400,
                            color: _trimmedName.length > 24
                                ? errorColor
                                : mutedSlate.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    _FormFieldContainer(
                      isFocused: _isNameFocused,
                      hasError: _nameError != null,
                      child: TextField(
                        controller: _nameController,
                        focusNode: _nameFocusNode,
                        textCapitalization: TextCapitalization.words,
                        textInputAction: TextInputAction.next,
                        maxLength: 24,
                        maxLengthEnforcement: MaxLengthEnforcement.enforced,
                        style: AppTypography.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: gufiNavy,
                        ),
                        decoration: InputDecoration(
                          counterText: '',
                          hintText: 'e.g. Morning Momentum',
                          hintStyle: AppTypography.inter(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w400,
                            color: mutedSlate.withValues(alpha: 0.55),
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                        ),
                      ),
                    ),

                    if (_nameError != null) ...[
                      const SizedBox(height: 6),
                      Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: Row(
                          children: [
                            const Icon(
                              CupertinoIcons.exclamationmark_circle_fill,
                              size: 13,
                              color: errorColor,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              _nameError!,
                              style: AppTypography.inter(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w500,
                                color: errorColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    SizedBox(height: gapBetweenFields),

                    // Field 2: Purpose / why this Circle exists
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'What’s this Circle for?',
                          style: AppTypography.inter(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: gufiNavy,
                          ),
                        ),
                        Text(
                          '${_purposeController.text.length}/80',
                          style: AppTypography.inter(
                            fontSize: 12.0,
                            fontWeight: FontWeight.w400,
                            color: _purposeController.text.length > 80
                                ? errorColor
                                : mutedSlate.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    _FormFieldContainer(
                      isFocused: _isPurposeFocused,
                      hasError: false,
                      child: TextField(
                        controller: _purposeController,
                        focusNode: _purposeFocusNode,
                        minLines: 2,
                        maxLines: 3,
                        maxLength: 80,
                        maxLengthEnforcement: MaxLengthEnforcement.enforced,
                        textCapitalization: TextCapitalization.sentences,
                        textInputAction: TextInputAction.done,
                        style: AppTypography.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w400,
                          color: gufiNavy,
                          height: 1.3,
                        ),
                        decoration: InputDecoration(
                          counterText: '',
                          hintText: 'Show up daily, stay accountable, and finish what we say we’ll do.',
                          hintStyle: AppTypography.inter(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w400,
                            color: mutedSlate.withValues(alpha: 0.55),
                            height: 1.3,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ),

                    SizedBox(height: gapFieldsToPrivacy),

                    // 5. Privacy Info Card: Compact supporting information
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEEF5FD),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFFDFECFB),
                          width: 0.8,
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            margin: const EdgeInsets.only(top: 1),
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(0xFFDFEDFD),
                            ),
                            child: const Center(
                              child: Icon(
                                CupertinoIcons.lock_fill,
                                size: 12,
                                color: gufiBlue,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Private by default',
                                  style: AppTypography.inter(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: gufiNavy,
                                    letterSpacing: -0.1,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Only invited members can join and only your Circle can see what you share.',
                                  style: AppTypography.inter(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w400,
                                    color: mutedSlate,
                                    height: 1.25,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: gapPrivacyToCta),

                    // 6. Connected Continue CTA Button (visually belongs directly to the form)
                    _PrimarySubmitButton(
                      title: 'Continue',
                      isEnabled: _isNameValid,
                      isLoading: _isCreating,
                      onTap: _handleContinue,
                    ),

                    // Remaining natural breathing room below
                    const SizedBox(height: 36),
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

/// Form field container with smooth focus and error animation
class _FormFieldContainer extends StatelessWidget {
  final bool isFocused;
  final bool hasError;
  final Widget child;

  const _FormFieldContainer({
    required this.isFocused,
    required this.hasError,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    Color border;
    if (hasError) {
      border = const Color(0xFFE5484D);
    } else if (isFocused) {
      border = const Color(0xFF5880DA);
    } else {
      border = const Color(0xFFE2EAF4);
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border, width: isFocused ? 1.5 : 1.0),
      ),
      child: child,
    );
  }
}

/// Primary Continue CTA button with scale press feedback
class _PrimarySubmitButton extends StatefulWidget {
  final String title;
  final bool isEnabled;
  final bool isLoading;
  final VoidCallback onTap;

  const _PrimarySubmitButton({
    required this.title,
    required this.isEnabled,
    required this.isLoading,
    required this.onTap,
  });

  @override
  State<_PrimarySubmitButton> createState() => _PrimarySubmitButtonState();
}

class _PrimarySubmitButtonState extends State<_PrimarySubmitButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: _isPressed && widget.isEnabled ? 0.98 : 1.0,
      duration: const Duration(milliseconds: 80),
      curve: Curves.easeInOut,
      child: SizedBox(
        width: double.infinity,
        height: 54,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.isEnabled && !widget.isLoading ? widget.onTap : null,
            onHighlightChanged: (val) {
              if (widget.isEnabled) {
                setState(() => _isPressed = val);
              }
            },
            borderRadius: BorderRadius.circular(20),
            splashColor: Colors.white.withValues(alpha: 0.15),
            highlightColor: Colors.transparent,
            child: Ink(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: widget.isEnabled
                    ? const Color(0xFF5880DA)
                    : const Color(0xFFC0D2F8),
                boxShadow: widget.isEnabled
                    ? [
                        BoxShadow(
                          color: const Color(0xFF5880DA)
                              .withValues(alpha: 0.18),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Center(
                child: widget.isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : Text(
                        widget.title,
                        style: AppTypography.inter(
                          fontSize: 16.5,
                          fontWeight: FontWeight.w600,
                          color: widget.isEnabled
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.85),
                          letterSpacing: -0.2,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
