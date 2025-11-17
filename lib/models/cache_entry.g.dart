// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cache_entry.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class CacheEntryAdapter extends TypeAdapter<CacheEntry> {
  @override
  final int typeId = 0;

  @override
  CacheEntry read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CacheEntry(
      id: fields[0] as String,
      url: fields[1] as String,
      localPath: fields[2] as String,
      fileSize: fields[3] as int,
      createdAt: fields[4] as DateTime,
      lastAccessedAt: fields[5] as DateTime,
      accessCount: fields[6] as int,
      isComplete: fields[7] as bool,
      downloadedBytes: fields[8] as int,
      title: fields[9] as String?,
      thumbnail: fields[10] as String?,
      duration: fields[11] as Duration?,
    );
  }

  @override
  void write(BinaryWriter writer, CacheEntry obj) {
    writer
      ..writeByte(12)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.url)
      ..writeByte(2)
      ..write(obj.localPath)
      ..writeByte(3)
      ..write(obj.fileSize)
      ..writeByte(4)
      ..write(obj.createdAt)
      ..writeByte(5)
      ..write(obj.lastAccessedAt)
      ..writeByte(6)
      ..write(obj.accessCount)
      ..writeByte(7)
      ..write(obj.isComplete)
      ..writeByte(8)
      ..write(obj.downloadedBytes)
      ..writeByte(9)
      ..write(obj.title)
      ..writeByte(10)
      ..write(obj.thumbnail)
      ..writeByte(11)
      ..write(obj.duration);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CacheEntryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class CacheStatsAdapter extends TypeAdapter<CacheStats> {
  @override
  final int typeId = 2;

  @override
  CacheStats read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CacheStats(
      totalEntries: fields[0] as int,
      totalSize: fields[1] as int,
      completedEntries: fields[2] as int,
      partialEntries: fields[3] as int,
      hitRate: fields[4] as double,
    );
  }

  @override
  void write(BinaryWriter writer, CacheStats obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.totalEntries)
      ..writeByte(1)
      ..write(obj.totalSize)
      ..writeByte(2)
      ..write(obj.completedEntries)
      ..writeByte(3)
      ..write(obj.partialEntries)
      ..writeByte(4)
      ..write(obj.hitRate);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CacheStatsAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class CacheStrategyAdapter extends TypeAdapter<CacheStrategy> {
  @override
  final int typeId = 1;

  @override
  CacheStrategy read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return CacheStrategy.aggressive;
      case 1:
        return CacheStrategy.balanced;
      case 2:
        return CacheStrategy.conservative;
      default:
        return CacheStrategy.aggressive;
    }
  }

  @override
  void write(BinaryWriter writer, CacheStrategy obj) {
    switch (obj) {
      case CacheStrategy.aggressive:
        writer.writeByte(0);
        break;
      case CacheStrategy.balanced:
        writer.writeByte(1);
        break;
      case CacheStrategy.conservative:
        writer.writeByte(2);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CacheStrategyAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
