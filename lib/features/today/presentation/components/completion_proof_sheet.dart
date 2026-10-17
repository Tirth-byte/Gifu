import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/haptics/app_haptics.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../commitments/domain/models/commitment.dart';
import '../../../commitments/domain/models/proof_type.dart';

/// Focused completion proof sheet opened when user taps "I did it →" or "Resubmit →".
/// Title: "Show that you did it."
/// Subtitle: "A little proof keeps the promise real."
/// Options: Photo (Camera/Gallery preview) or Text.
class CompletionProofSheet extends StatefulWidget {
  const CompletionProofSheet({
    super.key,
    required this.commitment,
    required this.onSubmitPhoto,
    required this.onSubmitText,
  });

  final Commitment commitment;
  final Future<void> Function(String mediaUrl) onSubmitPhoto;
  final Future<void> Function(String text) onSubmitText;

  @override
  State<CompletionProofSheet> createState() => _CompletionProofSheetState();
}

class _CompletionProofSheetState extends State<CompletionProofSheet> {
  ProofType _selectedType = ProofType.photo;
  final TextEditingController _textController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  String? _pickedImagePath;
  bool _submitting = false;
  String? _errorMessage;

  static const Color primaryBlue = Color(0xFF5880DA);
  static const Color gufiNavy = Color(0xFF1E3365);

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    AppHaptics.selection();
    try {
      final XFile? file = await _picker.pickImage(
        source: source,
        imageQuality: 82,
        maxWidth: 1600,
      );
      if (file == null) return;

      setState(() {
        _pickedImagePath = file.path;
        _errorMessage = null;
      });
    } catch (e) {
      setState(() => _errorMessage = 'Could not access image: $e');
    }
  }

  Future<void> _handleSubmit() async {
    setState(() {
      _submitting = true;
      _errorMessage = null;
    });

    try {
      AppHaptics.light();
      if (_selectedType == ProofType.photo) {
        if (_pickedImagePath == null || _pickedImagePath!.isEmpty) {
          setState(() {
            _submitting = false;
            _errorMessage = 'Please take or choose a photo first.';
          });
          return;
        }
        await widget.onSubmitPhoto(_pickedImagePath!);
      } else {
        final text = _textController.text.trim();
        if (text.isEmpty) {
          setState(() {
            _submitting = false;
            _errorMessage = 'Please describe what you completed.';
          });
          return;
        }
        await widget.onSubmitText(text);
      }

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

  @override
  Widget build(BuildContext context) {
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
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
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
              'Show that you did it.',
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
              'A little proof keeps the promise real.',
              style: AppTypography.inter(
                fontSize: 14,
                color: gufiNavy.withValues(alpha: 0.55),
              ),
            ),

            const SizedBox(height: 14),

            // Commitment Title Pill
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFAFBFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: gufiNavy.withValues(alpha: 0.08)),
              ),
              child: Text(
                widget.commitment.title,
                style: AppTypography.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: gufiNavy,
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Proof Format Segment (Photo vs Text)
            Row(
              children: [
                Expanded(
                  child: _buildTypeSegment(
                    type: ProofType.photo,
                    label: 'Add a photo',
                    icon: Icons.camera_alt_outlined,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTypeSegment(
                    type: ProofType.text,
                    label: 'Write a proof',
                    icon: Icons.notes_rounded,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 18),

            if (_errorMessage != null) ...[
              Text(
                _errorMessage!,
                style: AppTypography.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFFDC2626),
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Content Area depending on selected proof type
            if (_selectedType == ProofType.photo) ...[
              if (_pickedImagePath != null) ...[
                // Small preview
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        height: 140,
                        width: double.infinity,
                        color: const Color(0xFFFAFBFC),
                        child: Image.file(
                          File(_pickedImagePath!),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: GestureDetector(
                        onTap: () => setState(() => _pickedImagePath = null),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close_rounded,
                            size: 16,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ] else ...[
                Row(
                  children: [
                    Expanded(
                      child: _buildPickerButton(
                        icon: Icons.camera_alt_rounded,
                        label: 'Take photo',
                        onTap: () => _pickImage(ImageSource.camera),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildPickerButton(
                        icon: Icons.photo_library_rounded,
                        label: 'Choose photo',
                        onTap: () => _pickImage(ImageSource.gallery),
                      ),
                    ),
                  ],
                ),
              ],
            ] else ...[
              // Text Proof input
              Text(
                'What did you complete?',
                style: AppTypography.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: gufiNavy.withValues(alpha: 0.65),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _textController,
                autofocus: true,
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
                style: AppTypography.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: gufiNavy,
                ),
                decoration: InputDecoration(
                  hintText: 'e.g. Finished the full 3 km run in 24 minutes.',
                  hintStyle: AppTypography.inter(
                    fontSize: 15,
                    color: gufiNavy.withValues(alpha: 0.35),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.all(14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: gufiNavy.withValues(alpha: 0.08),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: gufiNavy.withValues(alpha: 0.08),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(
                      color: primaryBlue,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 24),

            // Submit CTA Button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _submitting ? null : _handleSubmit,
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
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : Text(
                        'Submit proof',
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
      ),
    );
  }

  Widget _buildTypeSegment({
    required ProofType type,
    required String label,
    required IconData icon,
  }) {
    final isSelected = _selectedType == type;

    return InkWell(
      onTap: () {
        AppHaptics.selection();
        setState(() => _selectedType = type);
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFE8F2FD) : const Color(0xFFFAFBFC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? primaryBlue : gufiNavy.withValues(alpha: 0.08),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected
                  ? primaryBlue
                  : gufiNavy.withValues(alpha: 0.55),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: AppTypography.inter(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected
                    ? primaryBlue
                    : gufiNavy.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPickerButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: const Color(0xFFFAFBFC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: gufiNavy.withValues(alpha: 0.08),
            width: 1.0,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, size: 24, color: primaryBlue),
            const SizedBox(height: 6),
            Text(
              label,
              style: AppTypography.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: gufiNavy,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
