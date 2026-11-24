"""Jev fact-check for AeroTube audit findings.

Evidence = code excerpts + short Dart/yt-dlp behavioral notes that are
straightforward enough to be judged from the excerpt itself. Each claim is
about a specific defect; Jev judges whether the evidence supports it.
"""

from __future__ import annotations

import json
import os
import sys
from pathlib import Path

sys.path.insert(0, r"C:\Users\mtech\.local\share\mimocode\typesafe-harness")

from verify import check_claims  # noqa: E402


def main() -> None:
    if not os.environ.get("TYPESAFE_API_KEY"):
        raise SystemExit("Set TYPESAFE_API_KEY first.")

    evidence = {
        "dart_null_comparison": (
            "Dart language: the expression `x != 'none'` is true when x is null, "
            "because null is not equal to the string 'none'. "
            "Code excerpt from lib/services/ytdlp/ytdlp_service_windows.dart lines 124-128:\n"
            "```dart\n"
            "String? get activeCookieSource => _cookiePath != null\n"
            "    ? 'file'\n"
            "    : (_cookieBrowser != 'none'\n"
            "          ? 'browser'\n"
            "          : (_webViewPath != null ? 'webview' : null));\n"
            "```\n"
            "_cookieBrowser is declared as String? and defaults to null. "
            "The initial constructor sets _cookieBrowser = cookieBrowser which may be null."
        ),
        "path_extension_template": (
            "path package's p.extension('/dir/%(title)s.%(ext)s') returns '.%(ext)s' "
            "because the extension is the substring from the last '.' in the last path segment. "
            "Code excerpt from lib/services/ytdlp/ytdlp_service_windows.dart lines 1354-1363:\n"
            "```dart\n"
            "} else if (formatId != null && audioFormatId != null) {\n"
            "  args.addAll(['-f', '$formatId+$audioFormatId']);\n"
            "  final ext = p.extension(outputPath).replaceAll('.', '').toLowerCase();\n"
            "  if (ext.isNotEmpty &&\n"
            "      ['mp4', 'mkv', 'ogg', 'webm', 'flv'].contains(ext)) {\n"
            "    args.addAll(['--merge-output-format', ext]);\n"
            "  }\n"
            "}\n"
            "```\n"
            "Call site in lib/providers/download_provider.dart line 619:\n"
            "```dart\n"
            "final templatePath = '${item.outputPath}\\\\%(title)s.%(ext)s';\n"
            "```\n"
            "The outputPath passed to downloadVideo is always this yt-dlp output TEMPLATE, "
            "not a concrete filename. Therefore ext becomes '%(ext)s' which is never in "
            "['mp4','mkv','ogg','webm','flv'], so --merge-output-format is never added."
        ),
        "playlist_heuristic": (
            "Code excerpt from lib/core/utils/url_validator.dart lines 74-78:\n"
            "```dart\n"
            "static bool looksLikePlaylist(String url) {\n"
            "  final lower = url.trim().toLowerCase();\n"
            "  if (lower.isEmpty) return false;\n"
            "  return lower.contains('list=') || lower.contains('/playlist');\n"
            "}\n"
            "```\n"
            "The function uses raw substring matching. A URL like "
            "https://example.com/products?checklist=1 contains the substring 'list=' "
            "and would return true. A URL like https://example.com/watch?v=x&list= "
            "(empty list param) also returns true. A video URL that merely carries a "
            "watch-later or related playlist id also returns true even when the user "
            "intends to download only the single video."
        ),
        "error_helper_outdated": (
            "Code excerpt from lib/core/utils/error_helper.dart lines 73-86 "
            "(isBrokenExtractorError) and 270-287 (parse outdatedTool branch):\n"
            "```dart\n"
            "static bool isBrokenExtractorError(String error) {\n"
            "  final lower = error.toLowerCase();\n"
            "  return lower.contains('signature extraction failed') ||\n"
            "      ... ||\n"
            "      lower.contains('outdated');\n"
            "}\n"
            "```\n"
            "and in parse():\n"
            "```dart\n"
            "if (lower.contains('update yt-dlp') ||\n"
            "    lower.contains('outdated') ||\n"
            "    lower.contains('unable to extract') ||\n"
            "    lower.contains('decipher') ||\n"
            "    lower.contains('signature') ||\n"
            "    ... ) {\n"
            "  return ErrorHelper(... title: 'Extractor Update Required' ...);\n"
            "}\n"
            "```\n"
            "Any error message containing the bare word 'outdated' or 'signature' "
            "(for example a TLS 'certificate signature failure', a Windows "
            "'signature verification failed', or a user title containing 'signature') "
            "is classified as an outdated yt-dlp extractor, even when the real cause "
            "is unrelated to the extractor."
        ),
        "throttled_notify_trailing": (
            "Code excerpt from lib/providers/download_provider.dart lines 63-83:\n"
            "```dart\n"
            "DateTime _lastNotify = DateTime.fromMillisecondsSinceEpoch(0);\n"
            "static const int _throttleMs = 100;\n"
            "void _throttledNotify() {\n"
            "  final now = DateTime.now();\n"
            "  if (now.difference(_lastNotify).inMilliseconds >= _throttleMs) {\n"
            "    _lastNotify = now;\n"
            "    _markActiveDirty();\n"
            "    notifyListeners();\n"
            "  }\n"
            "}\n"
            "```\n"
            "This is a leading-edge-only throttle with no trailing timer. "
            "If a burst of progress updates arrives and then stops, any update "
            "that fell inside a throttle window is silently dropped and never "
            "notified. By contrast, MobileDownloadProvider (lines 74-87) schedules "
            "a Timer for the remaining throttle window (_pendingProgressNotify) "
            "so the final update is always delivered. The desktop provider can "
            "leave the progress bar short of its true value until the next event."
        ),
        "file_finder_id_match": (
            "Code excerpt from lib/core/utils/downloaded_file_finder.dart lines 36-39:\n"
            "```dart\n"
            "final idMatches = candidates.where((file) {\n"
            "  final filename = file.uri.pathSegments.isNotEmpty ? file.uri.pathSegments.last : '';\n"
            "  return filename.contains(item.id);\n"
            "}).toList();\n"
            "```\n"
            "item.id is constructed in DownloadProvider.startDownload as "
            "'${video.id}_${microsecondsSinceEpoch}_${_idCounter++}' — for example "
            "'dQw4w9WgXcQ_1730000000000000_3'. yt-dlp's -o template is "
            "'dir/%(title)s.%(ext)s', so the output filename is the video TITLE "
            "(sanitized), not the composite id. Therefore filename.contains(item.id) "
            "almost never matches. The finder then falls through to a title-word match "
            "that uses only the first 4 words of the title and can attach the wrong "
            "file when two videos share those words."
        ),
        "silent_duplicate_queue": (
            "Code excerpt from lib/providers/download_provider.dart lines 383-397:\n"
            "```dart\n"
            "final existing = _activeDownloads.where(\n"
            "  (d) =>\n"
            "      d.url == video.url &&\n"
            "      d.status != DownloadStatus.completed &&\n"
            "      d.status != DownloadStatus.failed &&\n"
            "      d.status != DownloadStatus.cancelled,\n"
            ");\n"
            "if (existing.isNotEmpty) {\n"
            "  LoggingService().info(\n"
            "    'Download already in queue: ${video.title}',\n"
            "    component: 'DownloadProvider',\n"
            "  );\n"
            "  return;\n"
            "}\n"
            "```\n"
            "When the user taps Download for a URL that is already queued, the method "
            "logs and returns with no notifyListeners, no user-visible snackbar/dialog, "
            "and no feedback object. From the UI the button press appears to do nothing. "
            "A user who taps again will keep getting the same silent no-op."
        ),
    }

    claims = {
        "activeCookieSource": (
            "When both _cookiePath and _cookieBrowser are null (no cookies configured), "
            "activeCookieSource incorrectly returns the string 'browser' instead of null, "
            "because null != 'none' is true in Dart."
        ),
        "merge_output_format_dead": (
            "The --merge-output-format argument is never applied for dual-stream downloads "
            "because the code reads the extension from an yt-dlp output TEMPLATE path "
            "('%(title)s.%(ext)s'), producing the literal string '%(ext)s' which never "
            "matches the allowed container list."
        ),
        "playlist_false_positive": (
            "looksLikePlaylist returns true for ordinary URLs that merely contain the "
            "substring 'list=' (for example a checklist query parameter or an empty list= "
            "parameter), causing single-video pages to be treated as playlists."
        ),
        "outdated_overmatch": (
            "Any error text containing the bare substrings 'outdated' or 'signature' is "
            "classified as an outdated yt-dlp extractor and surfaces an "
            "'Extractor Update Required' message, even when the real cause is unrelated."
        ),
        "desktop_progress_drop": (
            "The desktop DownloadProvider's _throttledNotify is leading-edge-only with no "
            "trailing flush, so the last progress update in a burst can be dropped and the "
            "UI progress bar can freeze until the next yt-dlp event arrives."
        ),
        "file_finder_wrong_id": (
            "findDownloadedFile's idMatches branch can never succeed under the default "
            "-o template because the on-disk filename is the video title, not the composite "
            "DownloadItem.id, so the finder falls back to a 4-word title match that can "
            "select the wrong file in a crowded download folder."
        ),
        "silent_duplicate": (
            "startDownload silently no-ops when the same URL is already active, with no "
            "user-visible feedback, so a second tap appears broken."
        ),
    }

    # Build ordered lists
    order = [
        ("evidence_key", "claim_key"),
        ("dart_null_comparison", "activeCookieSource"),
        ("path_extension_template", "merge_output_format_dead"),
        ("playlist_heuristic", "playlist_false_positive"),
        ("error_helper_outdated", "outdated_overmatch"),
        ("throttled_notify_trailing", "desktop_progress_drop"),
        ("file_finder_id_match", "file_finder_wrong_id"),
        ("silent_duplicate_queue", "silent_duplicate"),
    ][1:]

    ev_bundle = {k: evidence[ek] for ek, ck in order for k in []}  # placeholder
    # Single combined evidence state: each finding's evidence under its own key
    state_evidence = {ek: evidence[ek] for ek, _ in order}
    claim_list = [claims[ck] for _, ck in order]
    claim_keys = [ck for _, ck in order]

    print(f"Fact-checking {len(claim_list)} audit findings with Jev...\n")
    checks = check_claims(state_evidence, claim_list)

    results = []
    for key, claim, check in zip(claim_keys, claim_list, checks):
        results.append(
            {
                "finding": key,
                "claim": claim,
                "action": check.action,
                "support": check.support,
                "confidence": round(check.support_confidence, 3),
                "probabilities": {k: round(v, 3) for k, v in check.support_probabilities.items()},
                "reasons": check.reasons,
            }
        )
        mark = {"keep": "+", "flag": "?", "drop": "-", "rewrite": "r"}.get(check.action, "?")
        print(f"[{mark}] {key}: {check.action} (support={check.support}, conf={check.support_confidence:.2f})")
        for r in check.reasons:
            print(f"      {r}")

    out_path = Path(__file__).with_name("jev_factcheck_results.json")
    out_path.write_text(json.dumps(results, indent=2), encoding="utf-8")
    print(f"\nWrote {out_path}")


if __name__ == "__main__":
    main()
