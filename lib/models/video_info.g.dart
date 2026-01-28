// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'video_info.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class AudioQualityAdapter extends TypeAdapter<AudioQuality> {
  @override
  final int typeId = 3;

  @override
  AudioQuality read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return AudioQuality.high;
      case 1:
        return AudioQuality.mid;
      case 2:
        return AudioQuality.low;
      default:
        return AudioQuality.high;
    }
  }

  @override
  void write(BinaryWriter writer, AudioQuality obj) {
    switch (obj) {
      case AudioQuality.high:
        writer.writeByte(0);
        break;
      case AudioQuality.mid:
        writer.writeByte(1);
        break;
      case AudioQuality.low:
        writer.writeByte(2);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AudioQualityAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
