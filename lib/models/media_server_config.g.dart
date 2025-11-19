// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'media_server_config.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class MediaServerConfigAdapter extends TypeAdapter<MediaServerConfig> {
  @override
  final int typeId = 10;

  @override
  MediaServerConfig read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return MediaServerConfig(
      id: fields[0] as String,
      type: fields[1] as String,
      name: fields[2] as String,
      url: fields[3] as String,
      username: fields[4] as String,
      token: fields[5] as String,
      domain: fields[6] as String?,
      port: fields[7] as int?,
    );
  }

  @override
  void write(BinaryWriter writer, MediaServerConfig obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.type)
      ..writeByte(2)
      ..write(obj.name)
      ..writeByte(3)
      ..write(obj.url)
      ..writeByte(4)
      ..write(obj.username)
      ..writeByte(5)
      ..write(obj.token)
      ..writeByte(6)
      ..write(obj.domain)
      ..writeByte(7)
      ..write(obj.port);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MediaServerConfigAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
