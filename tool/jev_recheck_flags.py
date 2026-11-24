import os, sys, json
sys.path.insert(0, r"C:\Users\mtech\.local\share\mimocode\typesafe-harness")
from verify import check_claims

evidence = {
  "cancel": (
    "Code path for both fast and patient attempts in ytdlp_service_windows.dart:\n"
    "runTracked() first checks if (myGen != _videoFetchGen) throw YtdlpException('Cancelled'); "
    "then calls _runWithTimeoutTracked(args, timeout, myGen: myGen).\n"
    "_runWithTimeoutTracked uses Process.start, awaits process.exitCode.timeout(timeout), "
    "and on TimeoutException kills the process with ProcessSignal.sigkill and process.kill() "
    "before rethrowing YtdlpException.\n"
    "cancelFetch() increments _videoFetchGen, sets _activeVideoProcess=null, and kills "
    "_activeVideoProcess with sigkill+kill.\n"
    "Between attempt 1 and attempt 2 the code re-enters runTracked which re-checks myGen, "
    "so a cancel during attempt 1 prevents attempt 2.\n"
    "VideoProvider on TimeoutException calls _ytdlpService.cancelFetch() before rethrowing."
  ),
  "ui": (
    "VideoProvider.fetchVideoInfo still does unawaited(_tryExplodePreview(url, myGen)); "
    "BEFORE awaiting yt-dlp. _tryExplodePreview uses youtube_explode with a 4 second "
    "timeout, sets _videoInfo with empty formats and _isPreviewOnly=true, then notifyListeners(). "
    "YtdlpService.getVideoInfo still returns cached VideoInfo within 10 minutes TTL "
    "(30-entry LRU) before any process spawn. Neither of these paths was modified by the "
    "fast/patient flag change in _buildVideoInfoArgs."
  ),
}

claims = [
  "Cancellation still works for both fast and patient attempts: cancelFetch bumps the generation so the next runTracked aborts, and _runWithTimeoutTracked kills the yt-dlp process on timeout; VideoProvider also cancelFetch()es on provider timeout.",
  "Perceived UI speed is unchanged/improved: explode preview (up to 4s) and the 10-minute metadata cache still short-circuit the user wait independently of the yt-dlp fast/patient flag change.",
]

checks = check_claims(evidence, claims)
for claim, check in zip(claims, checks):
    print(f"[{check.action}] support={check.support} conf={check.support_confidence:.2f}")
    for r in check.reasons:
        print(f"  {r}")
