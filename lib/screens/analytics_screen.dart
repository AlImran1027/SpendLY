/// Analytics Screen — placeholder tab.
///
/// Temporary scaffold for the Analytics tab in the bottom navigation.
/// Will be replaced with charts and insights later.
library;

import 'package:flutter/material.dart';
import '../utils/constants.dart';

class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConstants.backgroundColor,
      appBar: AppBar(title: const Text('Analytics')),
      body: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.analytics_outlined, size: 64, color: AppConstants.textLightGray),
            SizedBox(height: AppConstants.paddingMedium),
            Text(
              'Analytics & Insights',
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
