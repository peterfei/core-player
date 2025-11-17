// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'subtitle_config.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SubtitleConfigAdapter extends TypeAdapter<SubtitleConfig> {
  @override
  final int typeId = 10;

  @override
  SubtitleConfig read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SubtitleConfig(
      enabled: fields[0] as bool,
      fontSize: fields[1] as double,
      fontFamily: fields[2] as String,
      fontColor: fields[3] as int,
      backgroundColor: fields[4] as int,
      backgroundOpacity: fields[5] as double,
      outlineColor: fields[6] as int,
      outlineWidth: fields[7] as double,
      position: fields[8] as SubtitlePosition,
      delayMs: fields[9] as int,
      autoLoad: fields[10] as bool,
      preferredLanguages: (fields[11] as List).cast<String>(),
      preferredEncoding: fields[12] as String,
    );
  }

  @override
  void write(BinaryWriter writer, SubtitleConfig obj) {
    writer
      ..writeByte(13)
      ..writeByte(0)
      ..write(obj.enabled)
      ..writeByte(1)
      ..write(obj.fontSize)
      ..writeByte(2)
      ..write(obj.fontFamily)
      ..writeByte(3)
      ..write(obj.fontColor)
      ..writeByte(4)
      ..write(obj.backgroundColor)
      ..writeByte(5)
      ..write(obj.backgroundOpacity)
      ..writeByte(6)
      ..write(obj.outlineColor)
      ..writeByte(7)
      ..write(obj.outlineWidth)
      ..writeByte(8)
      ..write(obj.position)
      ..writeByte(9)
      ..write(obj.delayMs)
      ..writeByte(10)
      ..write(obj.autoLoad)
      ..writeByte(11)
      ..write(obj.preferredLanguages)
      ..writeByte(12)
      ..write(obj.preferredEncoding);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SubtitleConfigAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class SubtitlePositionAdapter extends TypeAdapter<SubtitlePosition> {
  @override
  final int typeId = 11;

  @override
  SubtitlePosition read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return SubtitlePosition.top;
      case 1:
        return SubtitlePosition.center;
      case 2:
        return SubtitlePosition.bottom;
      default:
        return SubtitlePosition.top;
    }
  }

  @override
  void write(BinaryWriter writer, SubtitlePosition obj) {
    switch (obj) {
      case SubtitlePosition.top:
        writer.writeByte(0);
        break;
      case SubtitlePosition.center:
        writer.writeByte(1);
        break;
      case SubtitlePosition.bottom:
        writer.writeByte(2);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SubtitlePositionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
