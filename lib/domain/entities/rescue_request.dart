import 'package:google_maps_flutter/google_maps_flutter.dart';

enum RequestStatus { pending, inProgress, resolved, cancelled }

enum RequestType { food, blood, medicine, rescue, mentalHealth, transport, labour }

class RescueRequest {
  final String id;
  final String creatorId;
  final RequestType type;
  final String description;
  final double urgency; // 1-10
  final LatLng location;
  final String? photoUrl;
  final String? voiceUrl;
  final RequestStatus status;
  final double priorityScore;
  final DateTime timestamp;
  final String? responderId;

  RescueRequest({
    required this.id,
    required this.creatorId,
    required this.type,
    required this.description,
    required this.urgency,
    required this.location,
    this.photoUrl,
    this.voiceUrl,
    required this.status,
    this.priorityScore = 0.0,
    required this.timestamp,
    this.responderId,
  });

  RescueRequest copyWith({
    RequestStatus? status,
    double? priorityScore,
    String? responderId,
  }) {
    return RescueRequest(
      id: id,
      creatorId: creatorId,
      type: type,
      description: description,
      urgency: urgency,
      location: location,
      photoUrl: photoUrl,
      voiceUrl: voiceUrl,
      status: status ?? this.status,
      priorityScore: priorityScore ?? this.priorityScore,
      timestamp: timestamp,
      responderId: responderId ?? this.responderId,
    );
  }
}
