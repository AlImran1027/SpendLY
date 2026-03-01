/// Spending Summary Card — prominent card showing total monthly spend.
///
/// Displays the current month's total spending in a gradient-background
/// card with a subtle icon. Placed at the top of the home dashboard.
library;

import 'package:flutter/material.dart';
import '../utils/constants.dart';

class SpendingSummaryCard extends StatelessWidget {
  const SpendingSummaryCard({
    super.key,
    required this.totalSpent,
    required this.monthLabel,
    this.budgetTotal,
    this.onTap,
  });

  /// Formatted total (e.g. "\$1,234.56").
  final String totalSpent;

  /// Month label (e.g. "February 2026").
  final String monthLabel;

  /// Optional total budget — if provided, a progress indicator is shown.
  final double? budgetTotal;

  /// Callback when the card is tapped (navigates to budget details).
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppConstants.paddingLarge),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppConstants.primaryGreen,
              AppConstants.darkGreen,
            ],
          ),
          borderRadius:
              BorderRadius.circular(AppConstants.borderRadiusLarge),
          boxShadow: [
            BoxShadow(
              color: AppConstants.primaryGreen.withValues(alpha: 0.35),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            // ── Decorative background icon ──
            Positioned(
              right: -8,
              top: -8,
              child: Icon(
                Icons.account_balance_wallet_outlined,
                size: 80,
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),

            // ── Content ──
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Month label
                Row(
                  children: [
                    const Icon(
                      Icons.calendar_today_outlined,
                      size: 14,
                      color: Colors.white70,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      monthLabel,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                // Total amount
                Text(
                  totalSpent,
                  style: const TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),

                const SizedBox(height: 4),

                const Text(
                  'Total Spending',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white70,
                    fontWeight: FontWeight.w500,
                  ),
                ),

                // ── Optional budget progress bar ──
                if (budgetTotal != null) ...[
                  const SizedBox(height: 16),
                  _buildBudgetProgress(),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBudgetProgress() {
    // Parse the amount from the formatted string for progress calculation.
    // In production this would come from a numeric value directly.
    final spent = double.tryParse(
          totalSpent.replaceAll(RegExp(r'[^\d.]'), ''),
        ) ??
        0;
    final progress = budgetTotal! > 0 ? (spent / budgetTotal!).clamp(0.0, 1.0) : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Budget: \$${budgetTotal!.toStringAsFixed(0)}',
              style: const TextStyle(
                fontSize: 12,
                color: Colors.white70,
              ),
            ),
            Text(
              '${(progress * 100).toStringAsFixed(0)}%',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 6,
            backgroundColor: Colors.white.withValues(alpha: 0.2),
            valueColor: AlwaysStoppedAnimation<Color>(
              progress >= AppConstants.budgetCriticalThreshold
                  ? AppConstants.errorRed
                  : progress >= AppConstants.budgetWarningThreshold
                      ? AppConstants.warningAmber
                      : AppConstants.lightGreen,
            ),
          ),
        ),
      ],
    );
  }
}
