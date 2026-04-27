import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shayak/l10n/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import '../../data/repositories/auth_repository.dart';
import '../../domain/entities/rescue_request.dart';
import '../providers/app_providers.dart';
import '../providers/language_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentShayakUserProvider);
    final isAvailable = ref.watch(volunteerToggleProvider);
    final myRequestsAsync = ref.watch(userRequestsProvider);
    final locale = ref.watch(languageProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('My Profile'),
        actions: [
          TextButton(
            onPressed: () => ref.read(languageProvider.notifier).toggleLanguage(),
            child: Text(
              locale.languageCode == 'en' ? 'A/अ' : 'A/अ',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await ref.read(authRepoProvider).signOut();
            },
          ),
        ],
      ),
      body: userAsync.when(
        data: (user) {
          if (user == null) return const Center(child: Text('Not logged in'));
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // Profile header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primaryBlue, AppColors.lightBlue],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: Colors.white,
                      child: Text(
                        user.name.isNotEmpty
                            ? user.name[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryBlue),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(user.name,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold)),
                    Text(user.email,
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 14)),
                    if (user.role == UserRole.admin) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.accentYellow,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text('ADMIN',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                                fontSize: 12)),
                      )
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Volunteer Toggle Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10)
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: isAvailable
                            ? AppColors.priorityGreen.withOpacity(0.15)
                            : Colors.grey.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        isAvailable
                            ? Icons.volunteer_activism
                            : Icons.do_not_disturb,
                        color: isAvailable
                            ? AppColors.priorityGreen
                            : Colors.grey,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                              isAvailable
                                  ? 'You are available'
                                  : 'You are offline',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 15)),
                          Text(
                              isAvailable
                                  ? 'Visible to people nearby'
                                  : 'Hidden from rescue map',
                              style: const TextStyle(
                                  color: Colors.grey, fontSize: 13)),
                        ],
                      ),
                    ),
                    Switch(
                      value: isAvailable,
                      activeColor: AppColors.priorityGreen,
                      onChanged: (_) => ref
                          .read(volunteerToggleProvider.notifier)
                          .toggle(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              const Text('My Requests',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 12),
              myRequestsAsync.when(
                data: (requests) => requests.isEmpty
                    ? const Center(
                        child: Text('No requests yet',
                            style: TextStyle(color: Colors.grey)))
                    : Column(
                        children: requests
                            .map((r) => _MyRequestTile(request: r))
                            .toList()),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text('Error: $e'),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) =>
            Center(child: Text('Error: $e')),
      ),
    );
  }
}

class _MyRequestTile extends StatelessWidget {
  const _MyRequestTile({required this.request});
  final RescueRequest request;

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(request.status);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration:
                BoxDecoration(color: statusColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(request.type.name.toUpperCase(),
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 13)),
                Text(request.description,
                    style:
                        const TextStyle(color: Colors.grey, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          Text(request.status.name,
              style: TextStyle(
                  color: statusColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 12)),
        ],
      ),
    );
  }

  Color _statusColor(RequestStatus s) {
    switch (s) {
      case RequestStatus.pending:
        return AppColors.priorityYellow;
      case RequestStatus.inProgress:
        return AppColors.primaryBlue;
      case RequestStatus.resolved:
        return AppColors.priorityGreen;
      case RequestStatus.cancelled:
        return Colors.grey;
    }
  }
}
