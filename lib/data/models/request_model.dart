import 'package:hive/hive.dart';
import '../../domain/entities/rescue_request.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

part 'request_model.g.dart';

@HiveType(typeId: 0)
class RequestModel extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String creatorId;

  @HiveField(2)
  final String type;

  @HiveField(3)
  final String description;

  @HiveField(4)
  final double urgency;

  @HiveField(5)
  final double latitude;

  @HiveField(6)
  final double longitude;

  @HiveField(7)
  final String? photoUrl;

  @HiveField(8)
  final String? voiceUrl;

  @HiveField(9)
  final String status;

  @HiveField(10)
  final double priorityScore;

  @HiveField(11)
  final DateTime timestamp;

  @HiveField(12)
  final String? responderId;

  RequestModel({
    required this.id,
    required this.creatorId,
    required this.type,
    required this.description,
    required this.urgency,
    required this.latitude,
    required this.longitude,
    this.photoUrl,
    this.voiceUrl,
    required this.status,
    required this.priorityScore,
    required this.timestamp,
    this.responderId,
  });

  factory RequestModel.fromEntity(RescueRequest entity) {
    return RequestModel(
      id: entity.id,
      creatorId: entity.creatorId,
      type: entity.type.name,
      description: entity.description,
      urgency: entity.urgency,
      latitude: entity.location.latitude,
      longitude: entity.location.longitude,
      photoUrl: entity.photoUrl,
      voiceUrl: entity.voiceUrl,
      status: entity.status.name,
      priorityScore: entity.priorityScore,
      timestamp: entity.timestamp,
      responderId: entity.responderId,
    );
  }

  RescueRequest toEntity() {
    return RescueRequest(
      id: id,
      creatorId: creatorId,
      type: RequestType.values.byName(type),
      description: description,
      urgency: urgency,
      location: LatLng(latitude, longitude),
      photoUrl: photoUrl,
      voiceUrl: voiceUrl,
      status: RequestStatus.values.byName(status),
      priorityScore: priorityScore,
      timestamp: timestamp,
      responderId: responderId,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'creatorId': creatorId,
      'type': type,
      'description': description,
      'urgency': urgency,
      'latitude': latitude,
      'longitude': longitude,
      'photoUrl': photoUrl,
      'voiceUrl': voiceUrl,
      'status': status,
      'priorityScore': priorityScore,
      'timestamp': timestamp.toIso8601String(),
      'responderId': responderId,
    };
  }

  factory RequestModel.fromJson(Map<String, dynamic> json) {
    return RequestModel(
      id: json['id'],
      creatorId: json['creatorId'],
      type: json['type'],
      description: json['description'],
      urgency: (json['urgency'] as num).toDouble(),
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      photoUrl: json['photoUrl'],
      voiceUrl: json['voiceUrl'],
      status: json['status'],
      priorityScore: (json['priorityScore'] as num).toDouble(),
      timestamp: DateTime.parse(json['timestamp']),
      responderId: json['responderId'],
    );
  }
}
