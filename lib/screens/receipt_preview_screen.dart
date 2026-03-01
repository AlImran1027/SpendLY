/// Receipt Preview Screen — review a captured receipt before processing.
///
/// Displays the captured receipt image with:
///   - Pinch-to-zoom via [InteractiveViewer] for close inspection
///   - Simulated quality assessment indicators (Clarity, Brightness, Orientation)
///   - Two action buttons: **Retake** (returns to capture) and **Continue**
///     (simulates processing with a loading state)
///   - Smooth fade-in animation for the quality indicators
///
/// Receives the image file path as a route argument (String).
library;

import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../utils/constants.dart';

class ReceiptPreviewScreen extends StatefulWidget {
  const ReceiptPreviewScreen({super.key});

  @override
  State<ReceiptPreviewScreen> createState() => _ReceiptPreviewScreenState();
}

class _ReceiptPreviewScreenState extends State<ReceiptPreviewScreen>
    with SingleTickerProviderStateMixin {
  /// Path to the captured receipt image (received via route arguments).
  late String _imagePath;

  /// Whether the quality analysis has completed (drives fade-in).
  bool _analysisComplete = false;

  /// Whether the "Continue" button is in its loading state.
  bool _isProcessing = false;

  /// Simulated quality scores (0.0 – 1.0).
  late double _clarityScore;
  late double _brightnessScore;
  late double _orientationScore;

  /// Overall quality label derived from the three sub-scores.
  String get _overallLabel {
    final avg = (_clarityScore + _brightnessScore + _orientationScore) / 3;
    if (avg >= 0.8) return 'Excellent';
    if (avg >= 0.6) return 'Good';
    if (avg >= 0.4) return 'Fair';
    return 'Poor';
  }

  /// Overall quality color derived from the average score.
  Color get _overallColor {
    final avg = (_clarityScore + _brightnessScore + _orientationScore) / 3;
    if (avg >= 0.8) return AppConstants.primaryGreen;
    if (avg >= 0.6) return AppConstants.lightGreen;
    if (avg >= 0.4) return AppConstants.warningAmber;
    return AppConstants.errorRed;
  }

  /// Controller for the quality-card slide-up animation.
  late AnimationController _slideController;
  late Animation<Offset> _slideAnim;
  late Animation<double> _fadeAnim;

  // ─── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();

    // Slide + fade animation for the quality card.
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
    );
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _slideController, curve: Curves.easeIn),
    );

    // Generate simulated quality scores after a brief delay (mimics analysis).
    _simulateQualityAnalysis();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Extract the image path from route arguments.
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is String) {
      _imagePath = args;
    } else {
      // Defensive fallback — should never happen.
      _imagePath = '';
    }
  }

  @override
  void dispose() {
    _slideController.dispose();
    super.dispose();
  }

  // ─── Quality Analysis (Simulated) ──────────────────────────────────────────

  /// Simulates an image-quality analysis with a short delay.
  ///
  /// In a production app this would call a real image-analysis function
  /// (e.g. edge detection for clarity, histogram for brightness).
  Future<void> _simulateQualityAnalysis() async {
    await Future.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;

    final rng = math.Random();
    setState(() {
      // Bias toward higher scores so the demo usually looks optimistic.
      _clarityScore = 0.65 + rng.nextDouble() * 0.35; // 0.65–1.0
      _brightnessScore = 0.60 + rng.nextDouble() * 0.40; // 0.60–1.0
      _orientationScore = 0.70 + rng.nextDouble() * 0.30; // 0.70–1.0
      _analysisComplete = true;
    });

    _slideController.forward();
  }

  // ─── Actions ────────────────────────────────────────────────────────────────

  /// Returns to the capture screen so the user can retake the photo.
  void _onRetake() {
    Navigator.pushReplacementNamed(
      context,
      AppConstants.receiptCaptureRoute,
    );
  }

  /// Navigates to the AI extraction results screen with the captured image.
  Future<void> _onContinue() async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    // Brief delay so the user sees the loading state before transition.
    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;

    Navigator.pushReplacementNamed(
      context,
      AppConstants.extractionResultsRoute,
      arguments: _imagePath,
    );
  }

  // ─── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConstants.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppConstants.backgroundColor,
        foregroundColor: AppConstants.textDark,
        title: const Text(
          'Preview Receipt',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          // Quick-action: rotate hint
          IconButton(
            icon: const Icon(Icons.rotate_right_rounded),
            tooltip: 'Pinch to zoom, drag to pan',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Pinch to zoom • Drag to pan'),
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
      body: Column(
        children: [
          // ── Image Preview ───────────────────────────────────────────────
          Expanded(child: _buildImagePreview()),

          // ── Quality Indicators ──────────────────────────────────────────
          _buildQualitySection(),

          // ── Action Buttons ──────────────────────────────────────────────
          _buildActionButtons(),
        ],
      ),
    );
  }

  /// Displays the receipt image inside an [InteractiveViewer] for
  /// pinch-to-zoom and panning.
  Widget _buildImagePreview() {
    if (_imagePath.isEmpty) {
      return const Center(
        child: Text(
          'No image available',
          style: TextStyle(color: AppConstants.textMediumGray),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.all(AppConstants.paddingMedium),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppConstants.borderRadiusMedium),
        border: Border.all(
          color: AppConstants.textLightGray.withValues(alpha: 0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppConstants.borderRadiusMedium),
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4.0,
          child: Image.file(
            File(_imagePath),
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                color: Colors.grey.shade100,
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.broken_image_outlined,
                        size: 48,
                        color: AppConstants.textLightGray,
                      ),
                      SizedBox(height: 12),
                      Text(
                        'Unable to load image',
                        style: TextStyle(color: AppConstants.textMediumGray),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  /// Quality assessment section — three horizontal indicators with an
  /// overall quality label. Slides up once analysis finishes.
  Widget _buildQualitySection() {
    // Show a loading shimmer while analysing.
    if (!_analysisComplete) {
      return Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppConstants.paddingLarge,
          vertical: AppConstants.paddingMedium,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppConstants.primaryGreen.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Analysing image quality…',
              style: TextStyle(
                color: AppConstants.textMediumGray,
                fontSize: 13,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      );
    }

    return SlideTransition(
      position: _slideAnim,
      child: FadeTransition(
        opacity: _fadeAnim,
        child: Container(
          margin: const EdgeInsets.symmetric(
            horizontal: AppConstants.paddingMedium,
          ),
          padding: const EdgeInsets.all(AppConstants.paddingMedium),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(
              AppConstants.borderRadiusMedium,
            ),
            border: Border.all(
              color: _overallColor.withValues(alpha: 0.3),
            ),
            boxShadow: [
              BoxShadow(
                color: _overallColor.withValues(alpha: 0.08),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Overall quality badge
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _overallLabel == 'Excellent' || _overallLabel == 'Good'
                        ? Icons.check_circle_rounded
                        : Icons.info_rounded,
                    color: _overallColor,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Image Quality: $_overallLabel',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: _overallColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Individual indicators
              Row(
                children: [
                  Expanded(
                    child: _buildIndicator(
                      label: 'Clarity',
                      score: _clarityScore,
                      icon: Icons.visibility_rounded,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildIndicator(
                      label: 'Brightness',
                      score: _brightnessScore,
                      icon: Icons.wb_sunny_rounded,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildIndicator(
                      label: 'Orientation',
                      score: _orientationScore,
                      icon: Icons.crop_rotate_rounded,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// A single quality indicator with an icon, label, coloured progress bar,
  /// and percentage text.
  Widget _buildIndicator({
    required String label,
    required double score,
    required IconData icon,
  }) {
    final color = _colorForScore(score);
    final percent = (score * 100).toInt();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: AppConstants.textMediumGray,
          ),
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: score,
            minHeight: 6,
            backgroundColor: color.withValues(alpha: 0.15),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '$percent%',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }

  /// Maps a 0–1 score to a traffic-light colour.
  Color _colorForScore(double score) {
    if (score >= 0.8) return AppConstants.primaryGreen;
    if (score >= 0.6) return AppConstants.lightGreen;
    if (score >= 0.4) return AppConstants.warningAmber;
    return AppConstants.errorRed;
  }

  /// Bottom action bar with **Retake** and **Continue** buttons.
  Widget _buildActionButtons() {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppConstants.paddingMedium,
        AppConstants.paddingMedium,
        AppConstants.paddingMedium,
        AppConstants.paddingLarge,
      ),
      child: Row(
        children: [
          // Retake button (outlined)
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _isProcessing ? null : _onRetake,
              icon: const Icon(Icons.replay_rounded, size: 20),
              label: const Text('Retake'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppConstants.primaryGreen,
                side: const BorderSide(
                  color: AppConstants.primaryGreen,
                  width: 1.5,
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    AppConstants.borderRadiusMedium,
                  ),
                ),
                textStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),

          const SizedBox(width: AppConstants.paddingMedium),

          // Continue button (filled)
          Expanded(
            flex: 2,
            child: FilledButton.icon(
              onPressed:
                  (_isProcessing || !_analysisComplete) ? null : _onContinue,
              icon: _isProcessing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.arrow_forward_rounded, size: 20),
              label: Text(_isProcessing ? 'Processing…' : 'Continue'),
              style: FilledButton.styleFrom(
                backgroundColor: AppConstants.primaryGreen,
                disabledBackgroundColor:
                    AppConstants.primaryGreen.withValues(alpha: 0.5),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    AppConstants.borderRadiusMedium,
                  ),
                ),
                textStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
