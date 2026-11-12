import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import '../auth/login_screen.dart';
import '../encomiendas/encomiendas_screen.dart';
import '../home/home_screen.dart';
import '../profile/profile_screen.dart';
import '../search/search_screen.dart';
import '../viajes/viajes_screen.dart';

class MainShell extends StatelessWidget {
  const MainShell({super.key});

  static const _destinations = [
    NavigationDestination(
      icon: Icon(Icons.home_outlined),
      selectedIcon: Icon(Icons.home),
      label: 'Inicio',
    ),
    NavigationDestination(
      icon: Icon(Icons.search),
      label: 'Buscar',
    ),
    NavigationDestination(
      icon: Icon(Icons.inventory_2_outlined),
      selectedIcon: Icon(Icons.inventory_2),
      label: 'Encomiendas',
    ),
    NavigationDestination(
      icon: Icon(Icons.flight_takeoff),
      label: 'Viajes',
    ),
    NavigationDestination(
      icon: Icon(Icons.person_outline),
      selectedIcon: Icon(Icons.person),
      label: 'Perfil',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final tab = context.watch<ShellTab>();
    return Scaffold(
      body: IndexedStack(
        index: tab.value,
        children: const [
          HomeScreen(),
          SearchScreen(),
          EncomiendasScreen(),
          ViajesScreen(),
          ProfileScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab.value,
        onDestinationSelected: (index) => tab.value = index,
        destinations: _destinations,
      ),
    );
  }
}

/// Sin cuenta solo está disponible la búsqueda pública de viajes.
class GuestShell extends StatelessWidget {
  const GuestShell({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Explorar rutas'),
          actions: [
            TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
              ),
              child: const Text('Iniciar sesión'),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: const SearchScreen(embedded: true),
      );
}
