import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class InventoryItem {
  final String id;
  final String name;
  final int current;
  final int total;
  final String icon;

  InventoryItem({
    required this.id,
    required this.name,
    required this.current,
    required this.total,
    required this.icon,
  });

  factory InventoryItem.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return InventoryItem(
      id: doc.id,
      name: data['name'] ?? '',
      current: data['current'] ?? 0,
      total: data['total'] ?? 100,
      icon: data['icon'] ?? 'inventory',
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'current': current,
        'total': total,
        'icon': icon,
      };
}

class InventoryRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<List<InventoryItem>> watchInventory() {
    return _firestore.collection('inventory').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => InventoryItem.fromDoc(doc)).toList();
    });
  }

  Future<void> updateStock(String id, int delta) async {
    final docRef = _firestore.collection('inventory').doc(id);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists) return;
      final current = snapshot.data()?['current'] ?? 0;
      transaction.update(docRef, {'current': current + delta});
    });
  }

  Future<void> addItem(String name, int total, String icon) async {
    await _firestore.collection('inventory').add({
      'name': name,
      'current': total,
      'total': total,
      'icon': icon,
    });
  }

  Future<void> seedInitialData() async {
    final items = [
      {'name': 'Food Packets', 'current': 340, 'total': 500, 'icon': 'restaurant'},
      {'name': 'Blood Units (B+)', 'current': 12, 'total': 50, 'icon': 'bloodtype'},
      {'name': 'Medicine Kits', 'current': 78, 'total': 100, 'icon': 'medical_services'},
      {'name': 'Rescue Boats', 'current': 3, 'total': 10, 'icon': 'directions_boat'},
    ];

    for (var item in items) {
      final doc = await _firestore.collection('inventory').where('name', isEqualTo: item['name']).get();
      if (doc.docs.isEmpty) {
        await _firestore.collection('inventory').add(item);
      }
    }
  }
}

final inventoryRepoProvider = Provider((ref) => InventoryRepository());

final inventoryStreamProvider = StreamProvider<List<InventoryItem>>((ref) {
  return ref.watch(inventoryRepoProvider).watchInventory();
});
