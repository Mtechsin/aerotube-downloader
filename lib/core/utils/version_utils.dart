class VersionUtils {
  /// Strips leading 'v' or 'V' and trims whitespace from a version string.
  static String cleanVersion(String version) {
    return version.trim().replaceFirst(RegExp(r'^[vV]'), '');
  }

  /// Returns true if [latest] is strictly newer than [current].
  static bool isNewerVersion(String? current, String? latest) {
    if (latest == null || latest.trim().isEmpty) return false;
    if (current == null ||
        current.trim().isEmpty ||
        current.trim().toLowerCase() == 'unknown') {
      return true;
    }

    final normCurrent = current.trim().startsWith(RegExp(r'^[vV]'))
        ? current.trim().substring(1)
        : current.trim();
    final normLatest = latest.trim().startsWith(RegExp(r'^[vV]'))
        ? latest.trim().substring(1)
        : latest.trim();

    if (normCurrent == normLatest) return false;

    // Split on dots or hyphens for component-wise comparison
    final currentParts = normCurrent.split(RegExp(r'[.\-]'));
    final latestParts = normLatest.split(RegExp(r'[.\-]'));

    final maxLen = latestParts.length > currentParts.length
        ? latestParts.length
        : currentParts.length;

    for (int i = 0; i < maxLen; i++) {
      if (i >= currentParts.length) {
        // Latest has more parts (e.g. 1.2 vs 1.2.1)
        final lNum = _parseLeadingInt(latestParts[i]);
        if (lNum != null && lNum > 0) return true;
        continue;
      }
      if (i >= latestParts.length) {
        // Current has more parts (e.g. 1.2.1 vs 1.2)
        final cNum = _parseLeadingInt(currentParts[i]);
        if (cNum != null && cNum > 0) return false;
        continue;
      }

      final cStr = currentParts[i];
      final lStr = latestParts[i];

      if (cStr == lStr) continue;

      final cNum = _parseLeadingInt(cStr);
      final lNum = _parseLeadingInt(lStr);

      if (cNum != null && lNum != null) {
        if (lNum > cNum) return true;
        if (lNum < cNum) return false;
      } else if (lNum != null && cNum == null) {
        return true;
      } else if (cNum != null && lNum == null) {
        return false;
      } else {
        final comp = lStr.compareTo(cStr);
        if (comp > 0) return true;
        if (comp < 0) return false;
      }
    }

    return false;
  }

  static int? _parseLeadingInt(String str) {
    final match = RegExp(r'^\d+').firstMatch(str);
    if (match != null) {
      return int.tryParse(match.group(0)!);
    }
    return null;
  }
}

/// Backwards-compatible top-level function.
bool isNewerVersion(String current, String latest) =>
    VersionUtils.isNewerVersion(current, latest);

