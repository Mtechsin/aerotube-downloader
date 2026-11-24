"""Jev QA for metadata-fetch speedup design (fast first attempt + patient retry)."""

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
        "design": (
            "AeroTube getVideoInfo (ytdlp_service_windows.dart) was changed to:\n"
            "1) Attempt 1 FAST: yt-dlp flags --retries 1 --extractor-retries 1 "
            "--socket-timeout 8, no --retry-sleep, Dart per-attempt timeout 18s.\n"
            "2) Attempt 2 PATIENT: only if attempt 1 failed with a network/timeout "
            "class error (not content errors like video unavailable/private/404). "
            "Uses the old VPN-friendly flags --retries 4 --extractor-retries 3 "
            "--socket-timeout 30 --retry-sleep linear=1:3, Dart timeout 45s.\n"
            "3) Existing auth/cookie/VPN/DPAPI fallback chain is UNCHANGED and still "
            "runs after attempt 2 when the error class matches.\n"
            "4) Overall budget remains 120s; provider timeout remains 130s and still "
            "calls cancelFetch on timeout.\n"
            "5) youtube_explode preview (VideoProvider._tryExplodePreview, 4s timeout) "
            "still runs in parallel so the UI shows title/thumbnail immediately while "
            "yt-dlp loads the format ladder.\n"
            "6) Cache (10 min TTL, 30 entries) is unchanged and still short-circuits "
            "repeat fetches of the same URL+cookie state.\n"
            "\n"
            "Prior code used the patient ladder for EVERY attempt including success "
            "path, so a healthy network still waited on 30s socket timeouts and "
            "could sleep between retries."
        ),
    }

    claims = [
        (
            "happy_path_faster",
            "On a healthy network with a normal public video, the happy path is "
            "strictly faster than before because attempt 1 no longer waits on "
            "30-second socket timeouts, 4 network retries, or retry-sleep delays, "
            "and success returns immediately without entering patient or fallback "
            "attempts.",
        ),
        (
            "slow_network_still_reliable",
            "Reliability for slow/flaky networks is preserved: a timeout or network "
            "error on the fast pass escalates to the previous patient retry ladder "
            "(4 retries, 30s socket timeout, retry-sleep), and the auth/cookie/VPN "
            "fallback chain is unchanged, all within the same 120s overall budget.",
        ),
        (
            "content_errors_not_slower",
            "Content-class failures (private, unavailable, removed, 404/410, "
            "members-only, age-restricted) fail faster than before because they no "
            "longer trigger a pointless patient network retry; they still surface "
            "the same user-facing error.",
        ),
        (
            "ui_still_instant",
            "Perceived UI speed is improved independently of yt-dlp: the explode "
            "preview still loads title/thumbnail/duration in about 250ms–4s while "
            "the format ladder loads, and the metadata cache still short-circuits "
            "repeat fetches of the same URL.",
        ),
        (
            "no_regression_cancel",
            "Cancellation still works: both fast and patient attempts go through "
            "runTracked → _runWithTimeoutTracked which kills the yt-dlp process on "
            "timeout/cancel, and the fetch generation check aborts between attempts.",
        ),
    ]

    print(f"Jev QA: fact-checking {len(claims)} design claims...\n")
    checks = check_claims(evidence, [c[1] for c in claims])

    results = []
    for (key, claim), check in zip(claims, checks):
        results.append(
            {
                "claim": key,
                "text": claim,
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

    out = Path(__file__).with_name("jev_metadata_speedup_qa.json")
    out.write_text(json.dumps(results, indent=2), encoding="utf-8")
    print(f"\nWrote {out}")

    dropped = [r for r in results if r["action"] in ("drop", "flag")]
    if dropped:
        print(f"\n{len(dropped)} claim(s) need review before shipping.")
        sys.exit(1)
    print("\nAll claims kept — design QA passed.")


if __name__ == "__main__":
    main()
