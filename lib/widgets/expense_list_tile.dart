/// Expense List Tile — compact row for showing a single expense entry.
///
/// Shows the category icon, merchant/title, date, and amount.
/// Used in the "Recent Expenses" section of the home dashboard and
/// in the full expenses list screen.
library;

import 'package:flutter/material.dart';
import '../utils/constants.dart';

class ExpenseListTile extends StatelessWidget {
  const ExpenseListTile({
    super.key,
    required this.title,
    required this.category,
    required this.amount,
    required this.date,
    this.onTap,
  });

  /// Merchant name or expense title.
  final String title;

  /// Expense category (maps to an icon via [_categoryIcon]).
  final String category;

  /// Formatted amount string (e.g. "\$42.50").
  final String amount;

  /// Formatted date string (e.g. "Today", "Feb 24").
  final String date;

  /// Callback when the tile is tapped for detail view.
  final VoidCallback? onTap;

  /// Maps a category name to an appropriate Material icon.
  IconData _categoryIcon() {
    switch (category) {
      case 'Groceries':
        return Icons.shopping_cart_outlined;
      case 'Food/Restaurant':
        return Icons.restaurant_outlined;
      case 'Medicine':
        return Icons.medical_services_outlined;
      case 'Clothes':
        return Icons.checkroom_outlined;
      case 'Hardware':
        return Icons.hardware_outlined;
      case 'Cosmetics':
        return Icons.face_outlined;
      case 'Entertainment':
        return Icons.movie_outlined;
      default:
        return Icons.receipt_outlined;
    }
  }

  /// Maps a category name to a theme colour.
  Color _categoryColor() {
    switch (category) {
      case 'Groceries':
        return AppConstants.primaryGreen;
      case 'Food/Restaurant':
        return const Color(0xFFE65100); // deep orange
      case 'Medicine':
        return AppConstants.errorRed;
      case 'Clothes':
        return const Color(0xFF7B1FA2); // purple
      case 'Hardware':
        return const Color(0xFF455A64); // blue-grey
      case 'Cosmetics':
        return const Color(0xFFD81B60); // pink
      case 'Entertainment':
        return AppConstants.infoBlue;
      default:
        return AppConstants.textMediumGray;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _categoryColor();

    return InkWell(
      onTap: onTap,
      borderRadius:
          BorderRadius.circular(AppConstants.borderRadiusMedium),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: 10,
          horizontal: AppConstants.paddingMedium,
        ),
        child: Row(
          children: [
            // ── Category icon ──
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius:
                    BorderRadius.circular(AppConstants.borderRadiusMedium),
              ),
              child: Icon(_categoryIcon(), size: 22, color: color),
            ),

            const SizedBox(width: 12),

            // ── Title + category ──
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppConstants.textDark,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    category,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppConstants.textMediumGray,
                    ),
                  ),
                ],
              ),
            ),

            // ── Amount + date ──
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  amount,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppConstants.textDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  date,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppConstants.textLightGray,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
