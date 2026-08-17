bool isNewerVersion(String current, String latest) {
  final normCurrent = current.startsWith('v') ? current.substring(1) : current;
  final normLatest = latest.startsWith('v') ? latest.substring(1) : latest;
  final currentParts = normCurrent.split('.');
  final latestParts = normLatest.split('.');
  for (int i = 0; i < latestParts.length; i++) {
    if (i >= currentParts.length) return true;
    final c = int.tryParse(currentParts[i]) ?? 0;
    final l = int.tryParse(latestParts[i]) ?? 0;
    if (l > c) return true;
    if (l < c) return false;
  }
  return false;
}
