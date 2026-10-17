import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_typography.dart';

/// Minimal placeholder screen for /circle-create.
/// Identifies the route cleanly for testing. Full flow will be built in the next phase.
class CircleCreatePlaceholderPage extends StatelessWidget {
  const CircleCreatePlaceholderPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(CupertinoIcons.arrow_left, color: Color(0xFF1E3365)),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/circle-entry');
            }
          },
        ),
        title: Text(
          'Create a Circle',
          style: TextStyle(
            fontFamily: AppTypography.gambarinoFontFamily,
            fontSize: 22,
            fontWeight: FontWeight.w400,
            color: const Color(0xFF1E3365),
          ),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            'Create Circle Flow\n(Placeholder for testing)',
            textAlign: TextAlign.center,
            style: AppTypography.inter(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF5C6E8C),
            ),
          ),
        ),
      ),
    );
  }
}
