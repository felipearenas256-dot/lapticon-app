import 'dart:async';

import 'package:flutter/material.dart';

import '../../widgets/brand.dart';
import '../../widgets/loader.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _slow = false;
  late final Timer _timer = Timer(const Duration(seconds: 6), () {
    if (mounted) setState(() => _slow = true);
  });

  @override
  void initState() {
    super.initState();
    _timer;
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const LapticonMark(size: 72),
                const SizedBox(height: 24),
                const CircularProgressIndicator(),
                if (_slow) const WakingServerNotice(),
              ],
            ),
          ),
        ),
      );
}
