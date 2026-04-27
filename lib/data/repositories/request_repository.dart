import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../domain/entities/rescue_request.dart';
import '../../domain/logic/priority_calculator.dart';
import '../../domain/logic/radius_expansion_service.dart';

class RequestRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference get _col => _firestore.collection('requests');

  Stream<List<RescueRequest>> watchNearbyRequests({
    required double lat,
    required double lng,
    double radiusKm = 10,
  }) {
    return _col
        .snapshots()
        .map((snap) {
          return snap.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final gp = data['location'] as GeoPoint;
            final dynamicRadius = (data['searchRadiusKm'] as num?)?.toDouble() ?? radiusKm;
            
            final dist = PriorityCalculator.getDistance(
                lat, lng, gp.latitude, gp.longitude);
            if (dist > dynamicRadius) return null;
            return _docToRequest(doc);
          }).whereType<RescueRequest>()
            .where((r) => r.status == RequestStatus.pending || r.status == RequestStatus.inProgress)
            .toList()
            ..sort((a, b) => b.priorityScore.compareTo(a.priorityScore));
        });
  }

  Stream<List<RescueRequest>> watchAllRequests() {
    return _col
        .snapshots()
        .map((snap) => snap.docs.map(_docToRequest).toList()
          ..sort((a, b) => b.priorityScore.compareTo(a.priorityScore)));
  }

  Stream<List<RescueRequest>> watchUserRequests(String uid) {
    return _col
        .where('creatorId', isEqualTo: uid)
        .snapshots()
        .map((snap) => snap.docs.map(_docToRequest).toList()
          ..sort((a, b) => b.timestamp.compareTo(a.timestamp)));
  }

  Future<void> createRequest(RescueRequest request) async {
    await _col.doc(request.id).set({
      'creatorId': request.creatorId,
      'type': request.type.name,
      'description': request.description,
      'urgency': request.urgency,
      'location':
          GeoPoint(request.location.latitude, request.location.longitude),
      'photoUrl': request.photoUrl,
      'voiceUrl': request.voiceUrl,
      'status': request.status.name,
      'priorityScore': request.priorityScore,
      'searchRadiusKm': 2.0, // Initial radius
      'timestamp': FieldValue.serverTimestamp(),
      'responderId': request.responderId,
    });
    
    // Start dynamic radius expansion
    RadiusExpansionService().startRadiusExpansion(request.id);
  }

  Future<void> updateStatus(String id, RequestStatus status, {String? responderId}) async {
    final Map<String, dynamic> data = {'status': status.name};
    if (responderId != null) {
      data['responderId'] = responderId;
    }
    await _col.doc(id).update(data);
  }

  Future<void> deleteRequest(String id) async {
    await _col.doc(id).delete();
  }

  RescueRequest _docToRequest(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    final gp = d['location'] as GeoPoint;
    return RescueRequest(
      id: doc.id,
      creatorId: d['creatorId'] ?? '',
      type: RequestType.values.byName(d['type'] ?? 'rescue'),
      description: d['description'] ?? '',
      urgency: (d['urgency'] as num?)?.toDouble() ?? 5.0,
      location: LatLng(gp.latitude, gp.longitude),
      photoUrl: d['photoUrl'],
      voiceUrl: d['voiceUrl'],
      status: RequestStatus.values.byName(d['status'] ?? 'pending'),
      priorityScore: (d['priorityScore'] as num?)?.toDouble() ?? 0.0,
      timestamp:
          (d['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      responderId: d['responderId'],
    );
  }
}
