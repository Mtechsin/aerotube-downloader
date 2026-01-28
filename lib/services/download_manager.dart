import '../services/ytdlp_service.dart';
import '../services/storage_service.dart';

class DownloadManager {
  final YtdlpService ytdlpService;
  final StorageService storageService;

  DownloadManager({
    required this.ytdlpService,
    required this.storageService,
  });
}
