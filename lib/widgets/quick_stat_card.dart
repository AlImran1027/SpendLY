/// Quick Stat Card — compact metric card for the dashboard.
///
/// Displays a coloured icon, a label, and a value in a rounded card.
/// Designed to be placed in a horizontal scrollable row.
library;

import 'package:flutter/material.dart';
import '../utils/constants.dart';

class QuickStatCard extends StatelessWidget {
  const QuickStatCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.iconColor,
    this.iconBackgroundColor,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color iconColor;
  final Color? iconBackgroundColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 148,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius:
              BorderRadius.circular(AppConstants.borderRadiusMedium),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Icon chip ──
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: (iconBackgroundColor ?? iconColor)
                    .withValues(alpha: 0.12),
                borderRadius:
                    BorderRadius.circular(AppConstants.borderRadiusSmall),
              ),
              child: Icon(icon, size: 22, color: iconColor),
            ),

            const SizedBox(height: 10),

            // ── Value ──
            Text(
              value,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppConstants.textDark,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),

            const SizedBox(height: 2),

            // ── Label ──
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: AppConstants.textMediumGray,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
