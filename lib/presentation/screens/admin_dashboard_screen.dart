import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/theme/app_colors.dart';
import '../../domain/entities/rescue_request.dart';
import '../providers/app_providers.dart';
import '../../data/repositories/request_repository.dart';
import '../../data/repositories/auth_repository.dart';

import 'package:shayak/data/repositories/inventory_repository.dart';

class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  ConsumerState<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen> with SingleTickerProviderStateMixin {
  GoogleMapController? _mapController;
  late TabController _tabController;
  String _priorityFilter = 'all'; // all, high, medium, low
  bool _showVolunteers = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Set<Marker> _buildMarkers(List<RescueRequest> requests, List<ShayakUser> volunteers) {
    final Set<Marker> markers = {};

    final filteredRequests = requests.where((r) {
      if (_priorityFilter == 'all') return true;
      if (_priorityFilter == 'high' && r.priorityScore >= 0.7) return true;
      if (_priorityFilter == 'medium' && r.priorityScore >= 0.4 && r.priorityScore < 0.7) return true;
      if (_priorityFilter == 'low' && r.priorityScore < 0.4) return true;
      return false;
    });

    for (var req in filteredRequests) {
      markers.add(
        Marker(
          markerId: MarkerId('req_${req.id}'),
          position: req.location,
          icon: BitmapDescriptor.defaultMarkerWithHue(_getHue(req.priorityScore)),
          infoWindow: InfoWindow(title: 'Req: ${req.type.name}', snippet: req.description),
        ),
      );
    }

    if (_showVolunteers) {
      for (var vol in volunteers) {
        if (vol.latitude != null && vol.longitude != null) {
          markers.add(
            Marker(
              markerId: MarkerId('vol_${vol.uid}'),
              position: LatLng(vol.latitude!, vol.longitude!),
              icon: BitmapDescriptor.defaultMarkerWithHue(
                vol.isAvailable ? BitmapDescriptor.hueBlue : BitmapDescriptor.hueAzure,
              ),
              infoWindow: InfoWindow(title: 'Vol: ${vol.name}', snippet: vol.isAvailable ? 'Available' : 'Offline'),
            ),
          );
        }
      }
    }

    return markers;
  }

  double _getHue(double score) {
    if (score >= 0.7) return BitmapDescriptor.hueRed;
    if (score >= 0.4) return BitmapDescriptor.hueYellow;
    return BitmapDescriptor.hueGreen;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Command Center', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2)),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: false,
          indicatorColor: Colors.white,
          indicatorWeight: 4,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal, fontSize: 10),
          tabs: const [
            Tab(icon: Icon(Icons.dashboard, size: 20), text: 'OVERVIEW'),
            Tab(icon: Icon(Icons.list_alt, size: 20), text: 'REQUESTS'),
            Tab(icon: Icon(Icons.people, size: 20), text: 'VOLUNTEERS'),
            Tab(icon: Icon(Icons.notification_important, size: 20), text: 'ALERTS'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        physics: const BouncingScrollPhysics(),
        children: [
          _buildOverviewTab(),
          _buildRequestsTab(),
          _buildVolunteersTab(),
          _buildAlertsTab(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showBroadcastDialog(context),
        backgroundColor: AppColors.priorityRed,
        child: const Icon(Icons.broadcast_on_personal, color: Colors.white),
      ),
    );
  }

  Widget _buildOverviewTab() {
    final allRequestsAsync = ref.watch(allRequestsProvider);
    final allVolunteersAsync = ref.watch(allVolunteersProvider);
    final inventoryAsync = ref.watch(inventoryStreamProvider);

    return allRequestsAsync.when(
        data: (requests) {
          final volunteers = allVolunteersAsync.value ?? [];
          final high = requests.where((r) => r.priorityScore >= 0.7).length;

          return Column(
            children: [
              // Admin Map View
              SizedBox(
                height: 350,
                child: GoogleMap(
                  initialCameraPosition: const CameraPosition(
                    target: LatLng(20.5937, 78.9629), // India center
                    zoom: 4,
                  ),
                  onMapCreated: (ctrl) => _mapController = ctrl,
                  markers: _buildMarkers(requests, volunteers),
                  mapType: MapType.normal,
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Row(
                      children: [
                        _StatCard(label: 'High Priority', count: high, color: AppColors.priorityRed),
                        const SizedBox(width: 12),
                        _StatCard(label: 'Available Help', count: volunteers.where((v) => v.isAvailable).length, color: AppColors.primaryBlue),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const _SectionHeader(icon: Icons.inventory_2, title: 'Resource Inventory'),
                    const SizedBox(height: 12),
                    inventoryAsync.when(
                      data: (items) => _ResourceInventoryCard(items: items),
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (e, _) => Text('Error: $e'),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
    );
  }

  Widget _buildRequestsTab() {
    final allRequestsAsync = ref.watch(allRequestsProvider);
    return allRequestsAsync.when(
      data: (requests) => ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: requests.length,
        itemBuilder: (context, i) {
          final r = requests[i];
          return _AdminRequestTile(
            request: r,
            onAssign: () => _showAssignVolunteerDialog(context, r),
            onStatusChange: (status) => ref.read(requestRepoProvider).updateStatus(r.id, status),
          );
        },
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Text('Error: $e'),
    );
  }

  void _showAssignVolunteerDialog(BuildContext context, RescueRequest request) {
    final volunteers = ref.read(allVolunteersProvider).value ?? [];
    final availableVolunteers = volunteers.where((v) => v.isAvailable).toList();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Assign Volunteer'),
        content: availableVolunteers.isEmpty
            ? const Text('No volunteers currently available.')
            : SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: availableVolunteers.length,
                  itemBuilder: (context, i) {
                    final v = availableVolunteers[i];
                    return ListTile(
                      leading: const Icon(Icons.person, color: AppColors.primaryBlue),
                      title: Text(v.name),
                      subtitle: const Text('Available now'),
                      onTap: () async {
                        await ref.read(requestRepoProvider).updateStatus(
                          request.id,
                          RequestStatus.inProgress,
                          responderId: v.uid,
                        );
                        if (mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Assigned ${v.name} to this request.')),
                          );
                        }
                      },
                    );
                  },
                ),
              ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ],
      ),
    );
  }

  Widget _buildVolunteersTab() {
    final allVolunteersAsync = ref.watch(allVolunteersProvider);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton.icon(
            onPressed: () => _showAddVolunteerDialog(context),
            icon: const Icon(Icons.person_add),
            label: const Text('Add New Volunteer'),
            style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
          ),
        ),
        Expanded(
          child: allVolunteersAsync.when(
            data: (volunteers) => ListView.builder(
              itemCount: volunteers.length,
              itemBuilder: (context, i) {
                final v = volunteers[i];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: v.isAvailable ? AppColors.priorityGreen : Colors.grey,
                    child: Text(v.name[0], style: const TextStyle(color: Colors.white)),
                  ),
                  title: Text(v.name),
                  subtitle: Text(v.email),
                  trailing: Switch(
                    value: v.isAvailable,
                    onChanged: (val) => ref.read(authRepoProvider).toggleAvailability(v.uid, val),
                  ),
                );
              },
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Error: $e'),
          ),
        ),
      ],
    );
  }

  Widget _buildAlertsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Broadcast System', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        const Text('Send high-priority alerts to all users in the disaster zone.', style: TextStyle(color: Colors.grey)),
        const SizedBox(height: 24),
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const TextField(
                  decoration: InputDecoration(
                    labelText: 'Message Title',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                const TextField(
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Broadcast Content',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.priorityRed,
                    minimumSize: const Size(double.infinity, 50),
                  ),
                  child: const Text('SEND MASS ALERT', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showAddVolunteerDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.person_add, color: AppColors.primaryBlue),
            SizedBox(width: 8),
            Text('Add New Volunteer'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Full Name'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: emailCtrl,
              decoration: const InputDecoration(labelText: 'Email Address'),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: passwordCtrl,
              decoration: const InputDecoration(labelText: 'Temporary Password'),
              obscureText: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.isEmpty || emailCtrl.text.isEmpty || passwordCtrl.text.isEmpty) return;
              try {
                // Warning: This will log out the current admin in Firebase Auth.
                // In a production app, use a Cloud Function to create users without logging out.
                await ref.read(authRepoProvider).register(
                  name: nameCtrl.text.trim(),
                  email: emailCtrl.text.trim(),
                  password: passwordCtrl.text.trim(),
                  role: UserRole.volunteer,
                );
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Volunteer added successfully!')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryBlue),
            child: const Text('ADD', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showAddResourceDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final totalCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.add_business, color: AppColors.primaryBlue),
            SizedBox(width: 8),
            Text('Add Resource Type'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Resource Name (e.g. Tents)'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: totalCtrl,
              decoration: const InputDecoration(labelText: 'Total Quantity'),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameCtrl.text.trim();
              final total = int.tryParse(totalCtrl.text.trim()) ?? 0;
              if (name.isEmpty || total <= 0) return;

              await ref.read(inventoryRepoProvider).addItem(name, total, 'inventory');
              if (mounted) Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryBlue),
            child: const Text('ADD', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showBroadcastDialog(BuildContext context) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.broadcast_on_personal, color: AppColors.primaryBlue),
            SizedBox(width: 8),
            Text('Broadcast Alert'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'This will send a push notification to all users and volunteers.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: ctrl,
              decoration: InputDecoration(
                hintText: 'Type alert message...',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final message = ctrl.text.trim();
              if (message.isEmpty) return;
              
              // Simulate sending broadcast (in real app, this triggers a Cloud Function)
              await FirebaseFirestore.instance.collection('broadcasts').add({
                'message': message,
                'timestamp': FieldValue.serverTimestamp(),
                'sender': 'Admin',
              });

              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Global Alert Broadcasted: $message'),
                  backgroundColor: AppColors.priorityRed,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.priorityRed),
            child: const Text('BROADCAST',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard(
      {required this.label, required this.count, required this.color, this.suffix = ''});
  final String label;
  final int count;
  final String suffix;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3), width: 1.5),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.04), blurRadius: 6)
          ],
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text('$count',
                    style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: color)),
                if (suffix.isNotEmpty)
                  Text(suffix, style: TextStyle(fontSize: 14, color: color, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 4),
            Text(label,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.icon, required this.title});
  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primaryBlue, size: 20),
        const SizedBox(width: 8),
        Text(title,
            style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary)),
      ],
    );
  }
}

class _ResourceInventoryCard extends ConsumerWidget {
  const _ResourceInventoryCard({required this.items});
  final List<InventoryItem> items;

  IconData _getIcon(String name) {
    switch (name) {
      case 'Food Packets': return Icons.restaurant;
      case 'Blood Units (B+)': return Icons.bloodtype;
      case 'Medicine Kits': return Icons.medical_services;
      case 'Rescue Boats': return Icons.directions_boat;
      default: return Icons.inventory;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05), blurRadius: 8)
        ],
      ),
      child: Column(
        children: items.map((item) {
          final pct = item.current / item.total;
          final color = pct < 0.3
              ? AppColors.priorityRed
              : pct < 0.6
                  ? AppColors.priorityYellow
                  : AppColors.priorityGreen;
          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(_getIcon(item.name), size: 16, color: AppColors.primaryBlue),
                    const SizedBox(width: 8),
                    Text(item.name,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline, size: 20, color: Colors.grey),
                      onPressed: () => ref.read(inventoryRepoProvider).updateStock(item.id, -1),
                    ),
                    Text('${item.current}/${item.total}',
                        style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline, size: 20, color: AppColors.primaryBlue),
                      onPressed: () => ref.read(inventoryRepoProvider).updateStock(item.id, 1),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: pct.clamp(0.0, 1.0),
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                    minHeight: 6,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _AdminRequestTile extends StatelessWidget {
  const _AdminRequestTile(
      {required this.request, required this.onStatusChange, required this.onAssign});
  final RescueRequest request;
  final void Function(RequestStatus) onStatusChange;
  final VoidCallback onAssign;

  Color get _priorityColor {
    if (request.priorityScore >= 0.7) return AppColors.priorityRed;
    if (request.priorityScore >= 0.4) return AppColors.priorityYellow;
    return AppColors.priorityGreen;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border(
            left: BorderSide(color: _priorityColor, width: 4)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04), blurRadius: 6)
        ],
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: _priorityColor.withOpacity(0.15),
          child: Text(
            '${(request.priorityScore * 100).toStringAsFixed(0)}',
            style: TextStyle(
                color: _priorityColor,
                fontWeight: FontWeight.bold,
                fontSize: 12),
          ),
        ),
        title: Text(request.type.name.toUpperCase(),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        subtitle: Text(request.description,
            maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (request.status == RequestStatus.pending)
              IconButton(
                icon: const Icon(Icons.person_add_alt_1, color: AppColors.primaryBlue),
                tooltip: 'Assign Volunteer',
                onPressed: onAssign,
              ),
            DropdownButton<RequestStatus>(
              value: request.status,
              underline: const SizedBox.shrink(),
              items: RequestStatus.values
                  .map((s) => DropdownMenuItem(
                      value: s,
                      child: Text(s.name,
                          style: const TextStyle(fontSize: 12))))
                  .toList(),
              onChanged: (s) {
                if (s != null) onStatusChange(s);
              },
            ),
          ],
        ),
      ),
    );
  }
}

