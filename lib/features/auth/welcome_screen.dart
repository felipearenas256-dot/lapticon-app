import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/session.dart';
import '../../widgets/brand.dart';
import 'login_screen.dart';
import 'register_screen.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final onHero = scheme.brightness == Brightness.light
        ? Colors.white
        : scheme.onSurface;
    final hero = scheme.brightness == Brightness.light
        ? const Color(0xFF0F2F86)
        : scheme.surface;

    return Scaffold(
      backgroundColor: hero,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight - 44,
              ),
              child: IntrinsicHeight(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const LapticonMark(size: 44),
                        const SizedBox(width: 12),
                        Text(
                          'Lapticon',
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: onHero,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    const SizedBox(height: 40),
                    Text(
                      'Tu encomienda viaja con alguien que ya va para allá.',
                      style: theme.textTheme.displaySmall?.copyWith(
                        color: onHero,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Publica lo que necesitas enviar o aprovecha tu próximo '
                      'vuelo para llevar una encomienda.',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: onHero.withValues(alpha: 0.85),
                      ),
                    ),
                    const SizedBox(height: 32),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: scheme.secondary,
                        foregroundColor: scheme.onSecondary,
                      ),
                      onPressed: () => _open(context, const RegisterScreen()),
                      child: const Text('Crear cuenta'),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: onHero,
                        side: BorderSide(
                          color: onHero.withValues(alpha: 0.6),
                        ),
                      ),
                      onPressed: () => _open(context, const LoginScreen()),
                      child: const Text('Ya tengo cuenta'),
                    ),
                    const SizedBox(height: 4),
                    TextButton(
                      style: TextButton.styleFrom(foregroundColor: onHero),
                      onPressed: context.read<Session>().continueAsGuest,
                      child: const Text('Explorar sin cuenta'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _open(BuildContext context, Widget screen) => Navigator.push(
        context,
        MaterialPageRoute<void>(builder: (_) => screen),
      );
}
