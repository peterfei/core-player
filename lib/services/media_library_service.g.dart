// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'media_library_service.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ScannedVideoAdapter extends TypeAdapter<ScannedVideo> {
  @override
  final int typeId = 11;

  @override
  ScannedVideo read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ScannedVideo(
      path: fields[0] as String,
      name: fields[1] as String,
      sourceId: fields[2] as String?,
      size: fields[3] as int,
      addedAt: fields[4] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, ScannedVideo obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.path)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.sourceId)
      ..writeByte(3)
      ..write(obj.size)
      ..writeByte(4)
      ..write(obj.addedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ScannedVideoAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
