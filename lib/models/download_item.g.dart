// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'download_item.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class DownloadItemAdapter extends TypeAdapter<DownloadItem> {
  @override
  final int typeId = 1;

  @override
  DownloadItem read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return DownloadItem(
      id: fields[0] as String,
      title: fields[1] as String,
      url: fields[3] as String,
      outputPath: fields[4] as String,
      thumbnailUrl: fields[2] as String?,
      progress: fields[5] as double,
      speed: fields[6] as double,
      eta: fields[7] as int,
      status: fields[8] as DownloadStatus,
      error: fields[9] as String?,
      formatId: fields[10] as String?,
      audioFormatId: fields[11] as String?,
      audioOnly: fields[12] as bool,
      completedDate: fields[13] as DateTime?,
      totalBytes: fields[14] as int?,
      videoQuality: fields[15] as String?,
      thumbnailPath: fields[16] as String?,
      savePath: fields[17] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, DownloadItem obj) {
    writer
      ..writeByte(18)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.thumbnailUrl)
      ..writeByte(3)
      ..write(obj.url)
      ..writeByte(4)
      ..write(obj.outputPath)
      ..writeByte(5)
      ..write(obj.progress)
      ..writeByte(6)
      ..write(obj.speed)
      ..writeByte(7)
      ..write(obj.eta)
      ..writeByte(8)
      ..write(obj.status)
      ..writeByte(9)
      ..write(obj.error)
      ..writeByte(10)
      ..write(obj.formatId)
      ..writeByte(11)
      ..write(obj.audioFormatId)
      ..writeByte(12)
      ..write(obj.audioOnly)
      ..writeByte(13)
      ..write(obj.completedDate)
      ..writeByte(14)
      ..write(obj.totalBytes)
      ..writeByte(15)
      ..write(obj.videoQuality)
      ..writeByte(16)
      ..write(obj.thumbnailPath)
      ..writeByte(17)
      ..write(obj.savePath);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DownloadItemAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class DownloadStatusAdapter extends TypeAdapter<DownloadStatus> {
  @override
  final int typeId = 0;

  @override
  DownloadStatus read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return DownloadStatus.pending;
      case 1:
        return DownloadStatus.downloadingVideo;
      case 2:
        return DownloadStatus.downloadingAudio;
      case 3:
        return DownloadStatus.merging;
      case 4:
        return DownloadStatus.completed;
      case 5:
        return DownloadStatus.failed;
      case 6:
        return DownloadStatus.cancelled;
      case 7:
        return DownloadStatus.queued;
      default:
        return DownloadStatus.pending;
    }
  }

  @override
  void write(BinaryWriter writer, DownloadStatus obj) {
    switch (obj) {
      case DownloadStatus.pending:
        writer.writeByte(0);
        break;
      case DownloadStatus.downloadingVideo:
        writer.writeByte(1);
        break;
      case DownloadStatus.downloadingAudio:
        writer.writeByte(2);
        break;
      case DownloadStatus.merging:
        writer.writeByte(3);
        break;
      case DownloadStatus.completed:
        writer.writeByte(4);
        break;
      case DownloadStatus.failed:
        writer.writeByte(5);
        break;
      case DownloadStatus.cancelled:
        writer.writeByte(6);
        break;
      case DownloadStatus.queued:
        writer.writeByte(7);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DownloadStatusAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
