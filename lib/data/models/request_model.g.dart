// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'request_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class RequestModelAdapter extends TypeAdapter<RequestModel> {
  @override
  final int typeId = 0;

  @override
  RequestModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return RequestModel(
      id: fields[0] as String,
      creatorId: fields[1] as String,
      type: fields[2] as String,
      description: fields[3] as String,
      urgency: fields[4] as double,
      latitude: fields[5] as double,
      longitude: fields[6] as double,
      photoUrl: fields[7] as String?,
      voiceUrl: fields[8] as String?,
      status: fields[9] as String,
      priorityScore: fields[10] as double,
      timestamp: fields[11] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, RequestModel obj) {
    writer
      ..writeByte(12)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.creatorId)
      ..writeByte(2)
      ..write(obj.type)
      ..writeByte(3)
      ..write(obj.description)
      ..writeByte(4)
      ..write(obj.urgency)
      ..writeByte(5)
      ..write(obj.latitude)
      ..writeByte(6)
      ..write(obj.longitude)
      ..writeByte(7)
      ..write(obj.photoUrl)
      ..writeByte(8)
      ..write(obj.voiceUrl)
      ..writeByte(9)
      ..write(obj.status)
      ..writeByte(10)
      ..write(obj.priorityScore)
      ..writeByte(11)
      ..write(obj.timestamp);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RequestModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
