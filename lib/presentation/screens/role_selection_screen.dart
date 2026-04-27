import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../data/repositories/auth_repository.dart';
import 'login_screen.dart';

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Image.asset(
                'assets/images/logo.png',
                height: 150,
              ),
              const SizedBox(height: 12),
              const Text(
                'Select your role to continue',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
              const SizedBox(height: 60),
              _RoleButton(
                title: 'Citizen (User)',
                subtitle: 'Request help in emergencies',
                icon: Icons.person,
                role: UserRole.user,
                onTap: () => _navigateToLogin(context, UserRole.user),
              ),
              const SizedBox(height: 16),
              _RoleButton(
                title: 'Volunteer',
                subtitle: 'Respond to nearby requests',
                icon: Icons.volunteer_activism,
                role: UserRole.volunteer,
                onTap: () => _navigateToLogin(context, UserRole.volunteer),
              ),
              const SizedBox(height: 16),
              _RoleButton(
                title: 'Administrator',
                subtitle: 'Manage resources and volunteers',
                icon: Icons.admin_panel_settings,
                role: UserRole.admin,
                onTap: () => _navigateToLogin(context, UserRole.admin),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToLogin(BuildContext context, UserRole role) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LoginScreen(expectedRole: role),
      ),
    );
  }
}

class _RoleButton extends StatelessWidget {
  const _RoleButton({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.role,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final UserRole role;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.lightBlue.withOpacity(0.3),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppColors.primaryBlue, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}
