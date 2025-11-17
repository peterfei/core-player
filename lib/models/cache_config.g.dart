// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cache_config.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class CacheConfigAdapter extends TypeAdapter<CacheConfig> {
  @override
  final int typeId = 3;

  @override
  CacheConfig read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CacheConfig(
      isEnabled: fields[0] as bool,
      maxSizeBytes: fields[1] as int,
      strategy: fields[2] as CacheStrategy,
      allowCellular: fields[3] as bool,
      autoCleanup: fields[4] as bool,
      maxAgeDays: fields[5] as int,
      concurrentDownloads: fields[6] as int,
      chunkSizeKB: fields[7] as int,
    );
  }

  @override
  void write(BinaryWriter writer, CacheConfig obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.isEnabled)
      ..writeByte(1)
      ..write(obj.maxSizeBytes)
      ..writeByte(2)
      ..write(obj.strategy)
      ..writeByte(3)
      ..write(obj.allowCellular)
      ..writeByte(4)
      ..write(obj.autoCleanup)
      ..writeByte(5)
      ..write(obj.maxAgeDays)
      ..writeByte(6)
      ..write(obj.concurrentDownloads)
      ..writeByte(7)
      ..write(obj.chunkSizeKB);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CacheConfigAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class DownloadProgressAdapter extends TypeAdapter<DownloadProgress> {
  @override
  final int typeId = 4;

  @override
  DownloadProgress read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return DownloadProgress(
      url: fields[0] as String,
      downloadedBytes: fields[1] as int,
      totalBytes: fields[2] as int,
      speed: fields[3] as double,
      timestamp: fields[4] as DateTime,
      error: fields[5] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, DownloadProgress obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.url)
      ..writeByte(1)
      ..write(obj.downloadedBytes)
      ..writeByte(2)
      ..write(obj.totalBytes)
      ..writeByte(3)
      ..write(obj.speed)
      ..writeByte(4)
      ..write(obj.timestamp)
      ..writeByte(5)
      ..write(obj.error);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DownloadProgressAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
