"""Second Jev fact-check batch: OAuth placeholder, mobile history gap, card clipping."""

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
        "oauth_placeholder": (
            "Code excerpt from lib/services/core/auth_service.dart lines 21-24:\n"
            "```dart\n"
            "static const String _clientId =\n"
            "    'YOUR_CLIENT_ID.apps.googleusercontent.com'; // TODO: Replace with your actual Google OAuth client ID\n"
            "static const String _redirectUri =\n"
            "    'myapp://oauth2callback'; // TODO: Configure custom scheme in AndroidManifest.xml\n"
            "```\n"
            "_clientId is used directly in the Google OAuth authorize URL (line 265) "
            "and in the token-exchange POST body (line 296). Google rejects authorize "
            "requests whose client_id is not a real registered client id; the placeholder "
            "string is not a valid client id. The same file has a TODO comment admitting "
            "the value must be replaced. There is no alternate real client id anywhere in "
            "the login path."
        ),
        "mobile_cancelled_invisible": (
            "Code excerpt from MobileDownloadProvider (lib/providers/mobile_download_provider.dart):\n"
            "```dart\n"
            "List<DownloadItem> get completedDownloads {\n"
            "  ... _downloads.where((d) => d.status == DownloadStatus.completed) ...\n"
            "}\n"
            "List<DownloadItem> get failedDownloads {\n"
            "  ... _downloads.where((d) => d.status == DownloadStatus.failed) ...\n"
            "}\n"
            "```\n"
            "Code excerpt from HistoryDownloadsTab (lib/ui/widgets/downloads/history_downloads_tab.dart) lines 17-23:\n"
            "```dart\n"
            "final List<DownloadItem> downloads = PlatformUtils.isMobile\n"
            "    ? context.select<MobileDownloadProvider, List<DownloadItem>>(\n"
            "        (p) => [...p.completedDownloads, ...p.failedDownloads],\n"
            "      )\n"
            "    : context.select<DownloadProvider, List<DownloadItem>>(\n"
            "        (p) => p.historyDownloads,\n"
            "      );\n"
            "```\n"
            "cancelDownload sets status to DownloadStatus.cancelled and persists the item "
            "via _persistHistoryItem. Cancelled is a terminal status that is neither "
            "completed nor failed. The mobile History tab therefore omits every cancelled "
            "download from the list, even though Desktop History (which reads the full "
            "historyDownloads list) shows them. A dedicated clearCancelled() method exists "
            "in MobileDownloadProvider, proving cancelled items are expected to be visible "
            "somewhere."
        ),
        "fixed_card_height": (
            "Code excerpt from lib/ui/widgets/download_item_card.dart lines 69-72 and 197-209:\n"
            "```dart\n"
            "return Container(\n"
            "  height:\n"
            "      136, // Slightly increased height to prevent clipping when title, error, and progress are visible\n"
            "  ...\n"
            "  if (isFailed && widget.item.error != null)\n"
            "    Padding(\n"
            "      padding: const EdgeInsets.only(top: 4),\n"
            "      child: Text(\n"
            "        widget.item.error!,\n"
            "        maxLines: 1,\n"
            "        overflow: TextOverflow.ellipsis,\n"
            "```\n"
            "The card has a hard-coded height of 136 logical pixels. Inside that fixed "
            "height it must fit: a 2-line title, a status badge row with speed/eta tags, "
            "a 6px progress bar, AND (on failure) an error line. The error string is "
            "already ellipsized to 1 line, and yt-dlp error messages are often long "
            "(multi-sentence). When title takes 2 lines and error is present, the column "
            "can overflow the fixed 136px box; Flutter will paint overflow yellow/black "
            "stripes in debug and clip in release. The comment itself acknowledges the "
            "height was already increased once to prevent clipping."
        ),
        "auth_dialog_resurface": (
            "Code excerpt from lib/ui/screens/home_screen.dart lines 51-91:\n"
            "```dart\n"
            "void _onVideoProviderChange() {\n"
            "  if (!mounted || _videoProvider == null) return;\n"
            "  ...\n"
            "  if (_videoProvider!.hasError) {\n"
            "    final parsed = ErrorHelper.parse(_videoProvider!.errorMessage!);\n"
            "    if (parsed.category == ErrorCategory.authentication) {\n"
            "      _showAuthErrorDialog(parsed.suggestion ?? _videoProvider!.errorMessage!);\n"
            "    }\n"
            "  }\n"
            "}\n"
            "void _showAuthErrorDialog(String message) {\n"
            "  if (!mounted || _isShowingAuthDialog) return;\n"
            "  _isShowingAuthDialog = true;\n"
            "  showDialog(...).then((_) {\n"
            "    if (mounted) _isShowingAuthDialog = false;\n"
            "  });\n"
            "}\n"
            "```\n"
            "_onVideoProviderChange is registered as a listener on VideoProvider. Every "
            "notifyListeners while hasError remains true re-enters this path. The "
            "_isShowingAuthDialog flag only prevents stacking dialogs that are already "
            "open; after the user dismisses the dialog the flag is cleared while "
            "VideoProvider.hasError is still true. Any subsequent notify (loading status "
            "update, a second fetch attempt that fails the same way, theme/settings "
            "rebuild that also notifies, etc.) will re-open the dialog. There is no "
            "one-shot guard keyed to the specific error message or fetch generation."
        ),
    }

    claims = [
        (
            "oauth_placeholder",
            "Google OAuth login is broken because the client id is the literal placeholder "
            "'YOUR_CLIENT_ID.apps.googleusercontent.com'; authorize and token-exchange requests "
            "will be rejected by Google. There is no working client id in the login path.",
        ),
        (
            "mobile_cancelled_invisible",
            "On mobile, cancelled downloads become invisible: they are removed from active "
            "lists as terminal, persisted to history, but HistoryDownloadsTab only renders "
            "completedDownloads + failedDownloads, so cancelled items never appear. Desktop "
            "history shows them.",
        ),
        (
            "fixed_card_height",
            "DownloadItemCard's fixed 136px height can clip or overflow when a failed item "
            "shows a long title (2 lines) plus an error line, because the layout must fit "
            "title + badge row + progress + error inside a hard-coded height.",
        ),
        (
            "auth_dialog_resurface",
            "After the user dismisses the authentication dialog, any later VideoProvider "
            "notify while the same error is still set re-opens the dialog, because the guard "
            "only tracks whether a dialog is currently open, not whether this error was "
            "already acknowledged.",
        ),
    ]

    claim_texts = [c[1] for c in claims]
    print(f"Fact-checking {len(claim_texts)} findings with Jev...\n")
    checks = check_claims(evidence, claim_texts)

    results = []
    for (key, claim), check in zip(claims, checks):
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

    out_path = Path(__file__).with_name("jev_factcheck_results_batch2.json")
    out_path.write_text(json.dumps(results, indent=2), encoding="utf-8")
    print(f"\nWrote {out_path}")


if __name__ == "__main__":
    main()
