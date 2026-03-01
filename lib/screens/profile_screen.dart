/// Profile Screen — placeholder tab.
///
/// Temporary scaffold for the Profile tab in the bottom navigation.
/// Will be replaced with user profile and settings later.
library;

import 'package:flutter/material.dart';
import '../utils/constants.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConstants.backgroundColor,
      appBar: AppBar(title: const Text('Profile')),
      body: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.person_outline, size: 64, color: AppConstants.textLightGray),
            SizedBox(height: AppConstants.paddingMedium),
            Text(
              'Profile & Settings',
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
