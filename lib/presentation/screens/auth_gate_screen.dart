import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../providers/app_providers.dart';
import '../../data/repositories/auth_repository.dart';
import 'home_screen.dart';
import 'map_screen.dart';
import 'requests_list_screen.dart';
import 'profile_screen.dart';
import 'role_selection_screen.dart';
import 'admin_dashboard_screen.dart';

class AuthGateScreen extends ConsumerWidget {
  const AuthGateScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    return authState.when(
      data: (user) => user != null ? const _MainShell() : const RoleSelectionScreen(),
      loading: () => const _SplashScreen(),
      error: (_, __) => const RoleSelectionScreen(),
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/images/logo.png',
              width: 150,
            ),
            const SizedBox(height: 48),
            const CircularProgressIndicator(
                color: AppColors.primaryBlue, strokeWidth: 3),
          ],
        ),
      ),
    );
  }
}

class _MainShell extends ConsumerStatefulWidget {
  const _MainShell();

  @override
  ConsumerState<_MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<_MainShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentShayakUserProvider);
    final userRole = userAsync.value?.role ?? UserRole.user;
    final isAdmin = userRole == UserRole.admin;

    final screens = [
      const HomeScreen(),
      const MapScreen(),
      const RequestsListScreen(),
      if (isAdmin) const AdminDashboardScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      body: IndexedStack(index: _index, children: screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        backgroundColor: Colors.white,
        indicatorColor: AppColors.lightBlue.withOpacity(0.5),
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home, color: AppColors.primaryBlue),
            label: 'Home',
          ),
          const NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map, color: AppColors.primaryBlue),
            label: 'Map',
          ),
          const NavigationDestination(
            icon: Icon(Icons.list_alt_outlined),
            selectedIcon: Icon(Icons.list_alt, color: AppColors.primaryBlue),
            label: 'Requests',
          ),
          if (isAdmin)
            const NavigationDestination(
              icon: Icon(Icons.admin_panel_settings_outlined),
              selectedIcon: Icon(Icons.admin_panel_settings,
                  color: AppColors.primaryBlue),
              label: 'Admin',
            ),
          const NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person, color: AppColors.primaryBlue),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
