import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/haptics/app_haptics.dart';
import '../../../../core/theme/app_typography.dart';

const Color _bg = Color(0xFFF7F9F5);
const Color _navy = Color(0xFF1E3365);
const Color _blue = Color(0xFF5880DA);
const Color _muted = Color(0xFF77839A);
const Color _border = Color(0xFFBCDBFA);

/// Screen displayed after creating a password account to verify email ownership.
class EmailVerificationScreen extends StatefulWidget {
  final String email;
  final Future<void> Function() onResend;
  final Future<bool> Function() onCheckVerified;
  final VoidCallback onVerified;
  final VoidCallback onChangeEmail;

  const EmailVerificationScreen({
    super.key,
    required this.email,
    required this.onResend,
    required this.onCheckVerified,
    required this.onVerified,
    required this.onChangeEmail,
  });

  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  int _resendCooldown = 0;
  Timer? _timer;
  bool _checking = false;
  String? _message;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startCooldown() {
    setState(() => _resendCooldown = 60);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_resendCooldown > 1) {
        setState(() => _resendCooldown--);
      } else {
        _timer?.cancel();
        setState(() => _resendCooldown = 0);
      }
    });
  }

  Future<void> _handleResend() async {
    if (_resendCooldown > 0) return;
    AppHaptics.light();
    _startCooldown();
    try {
      await widget.onResend();
      if (mounted) {
        setState(() => _message = 'Verification email sent!');
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _message = 'Could not send verification email. Try again.',
        );
      }
    }
  }

  Future<void> _handleCheck() async {
    if (_checking) return;
    setState(() {
      _checking = true;
      _message = null;
    });
    AppHaptics.selection();
    try {
      final isVerified = await widget.onCheckVerified();
      if (!mounted) return;
      if (isVerified) {
        widget.onVerified();
      } else {
        setState(() {
          _message =
              'Email not yet verified. Please click the link in your email.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _message = 'Error checking verification status.');
      }
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Back / Change Email button
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  icon: const HugeIcon(
                    icon: HugeIcons.strokeRoundedArrowLeft01,
                    size: 24,
                    color: _navy,
                  ),
                  onPressed: widget.onChangeEmail,
                ),
              ),
              const SizedBox(height: 24),

              // Title
              Text(
                'Check your email.',
                style: TextStyle(
                  fontFamily: AppTypography.gambarinoFontFamily,
                  fontSize: 36,
                  color: _navy,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 12),

              // Subtitle
              Text(
                'We sent a verification link to:\n${widget.email}',
                style: AppTypography.inter(
                  fontSize: 15,
                  color: _muted,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 24),

              if (_message != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F0FE),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _border),
                  ),
                  child: Text(
                    _message!,
                    textAlign: TextAlign.center,
                    style: AppTypography.inter(fontSize: 13, color: _navy),
                  ),
                ),
                const SizedBox(height: 20),
              ],

              const Spacer(),

              // Primary Action: I've verified my email
              ElevatedButton(
                onPressed: _checking ? null : _handleCheck,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _blue,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _checking
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : Text(
                        "I've verified my email",
                        style: AppTypography.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
              const SizedBox(height: 12),

              // Resend Action
              TextButton(
                onPressed: _resendCooldown > 0 ? null : _handleResend,
                child: Text(
                  _resendCooldown > 0
                      ? 'Resend email in ${_resendCooldown}s'
                      : 'Resend email',
                  style: AppTypography.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _resendCooldown > 0 ? _muted : _navy,
                  ),
                ),
              ),
              const SizedBox(height: 4),

              // Change Email Action
              TextButton(
                onPressed: widget.onChangeEmail,
                child: Text(
                  'Change email',
                  style: AppTypography.inter(fontSize: 14, color: _muted),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
