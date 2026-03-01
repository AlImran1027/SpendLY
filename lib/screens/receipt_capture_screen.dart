/// Receipt Capture Screen — entry point for scanning receipts.
///
/// Provides a camera-themed interface with:
///   - A visual guide frame showing how to position the receipt
///   - Tips for optimal capture quality
///   - A large capture button that launches the device camera via [ImagePicker]
///   - A secondary option to upload from the device gallery
///   - Graceful permission-denied handling
///
/// After a successful capture the image path is forwarded to
/// [ReceiptPreviewScreen] for quality review before processing.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../utils/constants.dart';

/// Enum indicating the image source for receipt capture.
enum CaptureSource { camera, gallery }

class ReceiptCaptureScreen extends StatefulWidget {
  const ReceiptCaptureScreen({super.key});

  @override
  State<ReceiptCaptureScreen> createState() => _ReceiptCaptureScreenState();
}

class _ReceiptCaptureScreenState extends State<ReceiptCaptureScreen>
    with SingleTickerProviderStateMixin {
  final ImagePicker _picker = ImagePicker();

  /// True while the system camera / gallery is being presented.
  bool _isCapturing = false;

  /// Controls the breathing animation on the guide frame.
  late AnimationController _breatheController;
  late Animation<double> _breatheAnim;

  /// True if the initial auto-launch has already been triggered.
  bool _hasAutoLaunched = false;

  // ─── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();

    // Breathing animation for the guide-frame border
    _breatheController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _breatheAnim = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _breatheController, curve: Curves.easeInOut),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Auto-launch the picker if a source was passed via route arguments.
    if (!_hasAutoLaunched) {
      _hasAutoLaunched = true;
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is CaptureSource) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _pickImage(
            args == CaptureSource.camera
                ? ImageSource.camera
                : ImageSource.gallery,
          );
        });
      }
    }
  }

  @override
  void dispose() {
    _breatheController.dispose();
    super.dispose();
  }

  // ─── Image Capture Logic ────────────────────────────────────────────────────

  /// Launches the native camera or gallery picker.
  ///
  /// On success, navigates to the preview screen with the captured file path.
  /// On denial / cancellation, shows an informative snackbar.
  Future<void> _pickImage(ImageSource source) async {
    if (_isCapturing) return; // prevent double-tap
    setState(() => _isCapturing = true);

    try {
      final XFile? photo = await _picker.pickImage(
        source: source,
        imageQuality: 90, // slight compression to keep file size manageable
        maxWidth: 2400, // cap resolution for faster processing later
        maxHeight: 3200,
      );

      if (!mounted) return;

      if (photo != null) {
        // Verify the file exists before navigating.
        final file = File(photo.path);
        if (await file.exists()) {
          _navigateToPreview(photo.path);
        } else {
          _showError('The captured image could not be found. Please try again.');
        }
      } else {
        // User cancelled the picker — stay on this screen.
        setState(() => _isCapturing = false);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isCapturing = false);

      // Handle common platform exceptions (permission denied, etc.)
      final message = e.toString().toLowerCase();
      if (message.contains('permission') ||
          message.contains('denied') ||
          message.contains('access')) {
        _showPermissionDialog(source);
      } else {
        _showError('Something went wrong. Please try again.');
      }
    }
  }

  /// Navigates to the receipt preview screen, passing the image path.
  void _navigateToPreview(String imagePath) {
    Navigator.pushReplacementNamed(
      context,
      AppConstants.receiptPreviewRoute,
      arguments: imagePath,
    );
  }

  /// Shows a snackbar with the given error [message].
  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppConstants.errorRed,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.borderRadiusSmall),
        ),
      ),
    );
  }

  /// Shows a dialog explaining that camera/gallery permission is required.
  void _showPermissionDialog(ImageSource source) {
    final isCamera = source == ImageSource.camera;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.borderRadiusMedium),
        ),
        icon: Icon(
          isCamera ? Icons.camera_alt_rounded : Icons.photo_library_rounded,
          color: AppConstants.primaryGreen,
          size: 40,
        ),
        title: Text('${isCamera ? "Camera" : "Gallery"} Access Required'),
        content: Text(
          'Spendly needs access to your ${isCamera ? "camera" : "photo library"} '
          'to capture receipt images. Please grant permission in your device settings.',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppConstants.textMediumGray,
            fontSize: 14,
            height: 1.5,
          ),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              // Re-try picking (the OS will re-prompt permission).
              _pickImage(source);
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppConstants.primaryGreen,
            ),
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  // ─── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A), // dark background
      appBar: AppBar(
        backgroundColor: AppConstants.darkGreen,
        foregroundColor: Colors.white,
        title: const Text(
          'Scan Receipt',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ── Guide Frame Area ────────────────────────────────────────────
            Expanded(child: _buildGuideArea()),

            // ── Capture Tips ────────────────────────────────────────────────
            _buildTipsSection(),

            // ── Bottom Controls ─────────────────────────────────────────────
            _buildBottomControls(),
          ],
        ),
      ),
    );
  }

  /// Central area showing a receipt-shaped guide frame with corner brackets
  /// and a breathing opacity animation.
  Widget _buildGuideArea() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppConstants.paddingXLarge,
          vertical: AppConstants.paddingLarge,
        ),
        child: AnimatedBuilder(
              animation: _breatheAnim,
              builder: (context, child) {
                return CustomPaint(
                  painter: _GuideFramePainter(opacity: _breatheAnim.value),
                  child: child,
                );
              },
          child: AspectRatio(
            aspectRatio: 3 / 4, // portrait receipt shape
            child: Container(
              padding: const EdgeInsets.all(AppConstants.paddingLarge),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.receipt_long_rounded,
                    size: 64,
                    color: Colors.white.withValues(alpha: 0.4),
                  ),
                  const SizedBox(height: AppConstants.paddingMedium),
                  Text(
                    'Position your receipt\nwithin the frame',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: AppConstants.paddingSmall),
                  Text(
                    'Ensure all text is visible and legible',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.4),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Row of quick tips shown above the capture button.
  Widget _buildTipsSection() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.paddingLarge,
        vertical: AppConstants.paddingMedium,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildTip(Icons.lightbulb_outline, 'Good\nLighting'),
          _buildTip(Icons.crop_free, 'Full\nReceipt'),
          _buildTip(Icons.straighten, 'Lay\nFlat'),
          _buildTip(Icons.blur_off, 'Avoid\nBlur'),
        ],
      ),
    );
  }

  /// Single tip item — icon + two-line label.
  Widget _buildTip(IconData icon, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppConstants.primaryGreen.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: AppConstants.lightGreen, size: 22),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.6),
            fontSize: 11,
            height: 1.3,
          ),
        ),
      ],
    );
  }

  /// Bottom bar with the main capture button and a gallery shortcut.
  Widget _buildBottomControls() {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppConstants.paddingLarge,
        AppConstants.paddingMedium,
        AppConstants.paddingLarge,
        AppConstants.paddingLarge,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppConstants.borderRadiusLarge),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Gallery shortcut
          _buildControlButton(
            icon: Icons.photo_library_outlined,
            label: 'Gallery',
            onTap: () => _pickImage(ImageSource.gallery),
          ),

          // Main capture button — large green circle
          GestureDetector(
            onTap: _isCapturing ? null : () => _pickImage(ImageSource.camera),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _isCapturing
                    ? AppConstants.primaryGreen.withValues(alpha: 0.5)
                    : AppConstants.primaryGreen,
                border: Border.all(color: Colors.white, width: 4),
                boxShadow: [
                  BoxShadow(
                    color: AppConstants.primaryGreen.withValues(alpha: 0.4),
                    blurRadius: 16,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: _isCapturing
                  ? const Padding(
                      padding: EdgeInsets.all(22),
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(
                      Icons.camera_alt_rounded,
                      color: Colors.white,
                      size: 36,
                    ),
            ),
          ),

          // Flash info (informational only — actual flash controlled by OS)
          _buildControlButton(
            icon: Icons.flash_auto,
            label: 'Auto Flash',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text(
                    'Flash is controlled by your device camera settings',
                  ),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      AppConstants.borderRadiusSmall,
                    ),
                  ),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  /// Small control button used in the bottom bar (gallery, flash).
  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: _isCapturing ? null : onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Custom Painter — Guide Frame ────────────────────────────────────────────

/// Draws corner brackets around the guide area with an animated opacity to
/// create a gentle "breathing" effect that draws the user's eye.
class _GuideFramePainter extends CustomPainter {
  final double opacity;

  _GuideFramePainter({required this.opacity});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppConstants.lightGreen.withValues(alpha: opacity)
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const cornerLen = 30.0;
    const radius = 12.0;

    // Top-left corner
    canvas.drawPath(
      Path()
        ..moveTo(0, cornerLen)
        ..lineTo(0, radius)
        ..quadraticBezierTo(0, 0, radius, 0)
        ..lineTo(cornerLen, 0),
      paint,
    );

    // Top-right corner
    canvas.drawPath(
      Path()
        ..moveTo(size.width - cornerLen, 0)
        ..lineTo(size.width - radius, 0)
        ..quadraticBezierTo(size.width, 0, size.width, radius)
        ..lineTo(size.width, cornerLen),
      paint,
    );

    // Bottom-left corner
    canvas.drawPath(
      Path()
        ..moveTo(0, size.height - cornerLen)
        ..lineTo(0, size.height - radius)
        ..quadraticBezierTo(0, size.height, radius, size.height)
        ..lineTo(cornerLen, size.height),
      paint,
    );

    // Bottom-right corner
    canvas.drawPath(
      Path()
        ..moveTo(size.width - cornerLen, size.height)
        ..lineTo(size.width - radius, size.height)
        ..quadraticBezierTo(
            size.width, size.height, size.width, size.height - radius)
        ..lineTo(size.width, size.height - cornerLen),
      paint,
    );
  }

  @override
  bool shouldRepaint(_GuideFramePainter oldDelegate) =>
      oldDelegate.opacity != opacity;
}
