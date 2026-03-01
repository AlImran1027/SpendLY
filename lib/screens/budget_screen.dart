/// Budget Screen — placeholder tab.
///
/// Temporary scaffold for the Budget tab in the bottom navigation.
/// Will be replaced with a full budget management implementation later.
library;

import 'package:flutter/material.dart';
import '../utils/constants.dart';

class BudgetScreen extends StatelessWidget {
  const BudgetScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConstants.backgroundColor,
      appBar: AppBar(title: const Text('Budget')),
      body: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.account_balance_wallet_outlined, size: 64, color: AppConstants.textLightGray),
            SizedBox(height: AppConstants.paddingMedium),
            Text(
              'Budget Management',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppConstants.textDark),
            ),
            SizedBox(height: AppConstants.paddingSmall),
            Text('Coming soon', style: TextStyle(color: AppConstants.textMediumGray)),
          ],
        ),
      ),
    );
  }
}
