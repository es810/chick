import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/auth_provider.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  Timer? _failsafe;

  @override
  void initState() {
    super.initState();
    // Hard failsafe: never stay on splash longer than 8 seconds.
    _failsafe = Timer(const Duration(seconds: 8), () {
      final auth = ref.read(authProvider);
      if (auth.isLoading) {
        ref.read(authProvider.notifier).forceFinishLoading();
      }
    });
  }

  @override
  void dispose() {
    _failsafe?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      backgroundColor: AppColors.primaryGreen,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(Icons.egg_alt, size: 64, color: AppColors.primaryGreen),
            )
                .animate()
                .scale(duration: 600.ms, curve: Curves.easeOutBack)
                .then()
                .shimmer(duration: 1200.ms),
            const SizedBox(height: 24),
            Text(
              l10n.appNameShort,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
            ).animate().fadeIn(delay: 300.ms),
            Text(
              l10n.managementSystem,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white70,
                  ),
            ).animate().fadeIn(delay: 500.ms),
            const SizedBox(height: 48),
            const CircularProgressIndicator(color: Colors.white),
          ],
        ),
      ),
    );
  }
}
