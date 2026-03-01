/// Expenses Screen — placeholder tab.
///
/// Temporary scaffold for the Expenses tab in the bottom navigation.
/// Will be replaced with a full expense list implementation later.
library;

import 'package:flutter/material.dart';
import '../utils/constants.dart';

class ExpensesScreen extends StatelessWidget {
  const ExpensesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConstants.backgroundColor,
      appBar: AppBar(title: const Text('Expenses')),
      body: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.receipt_long_outlined, size: 64, color: AppConstants.textLightGray),
            SizedBox(height: AppConstants.paddingMedium),
            Text(
              'Expenses List',
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
