import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/request_model.dart';

class SyncService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late Box<RequestModel> _requestBox;

  Future<void> init() async {
    _requestBox = await Hive.openBox<RequestModel>('offline_requests');

    // Listen for connectivity changes
    Connectivity().onConnectivityChanged.listen(
      (List<ConnectivityResult> results) {
        if (results.any((r) => r != ConnectivityResult.none)) {
          syncPendingRequests();
        }
      },
    );
  }

  Future<void> saveRequestLocally(RequestModel request) async {
    await _requestBox.put(request.id, request);
    syncPendingRequests(); // attempt immediate sync
  }

  Future<void> syncPendingRequests() async {
    final results = await Connectivity().checkConnectivity();
    if (results.every((r) => r == ConnectivityResult.none)) return;

    final pendingRequests = _requestBox.values.toList();
    if (pendingRequests.isEmpty) return;

    for (final request in pendingRequests) {
      try {
        await _firestore.collection('requests').doc(request.id).set({
          'creatorId': request.creatorId,
          'type': request.type,
          'description': request.description,
          'urgency': request.urgency,
          'location': GeoPoint(request.latitude, request.longitude),
          'photoUrl': request.photoUrl,
          'voiceUrl': request.voiceUrl,
          'status': request.status,
          'priorityScore': request.priorityScore,
          'timestamp': FieldValue.serverTimestamp(),
        });
        await _requestBox.delete(request.id);
      } catch (e) {
        // Leave in local box — retry next connectivity event
      }
    }
  }
}
