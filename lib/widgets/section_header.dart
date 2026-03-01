/// Section Header — reusable title row for dashboard sections.
///
/// Displays a bold section title on the left and an optional "See all"
/// action button on the right. Used throughout the home dashboard and
/// other list/grid screens.
library;

import 'package:flutter/material.dart';
import '../utils/constants.dart';

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.actionText,
    this.onActionTap,
  });

  /// Section title (e.g. "Recent Expenses").
  final String title;

  /// Optional trailing action label (e.g. "See all").
  final String? actionText;

  /// Callback when the action label is tapped.
  final VoidCallback? onActionTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppConstants.textDark,
          ),
        ),
        if (actionText != null)
          TextButton(
            onPressed: onActionTap,
            style: TextButton.styleFrom(
              foregroundColor: AppConstants.primaryGreen,
              padding: const EdgeInsets.symmetric(
                horizontal: AppConstants.paddingSmall,
              ),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              actionText!,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }
}
