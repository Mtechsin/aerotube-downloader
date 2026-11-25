package com.aerotube.youtube_downloader

import android.content.Context
import android.util.Log
import com.yausername.ffmpeg.FFmpeg
import com.yausername.youtubedl_android.YoutubeDL
import com.yausername.youtubedl_android.YoutubeDLRequest
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import org.json.JSONObject
import java.io.File
import java.net.HttpURLConnection
import java.net.URL
import java.security.MessageDigest
import java.util.concurrent.ConcurrentHashMap

/**
 * Singleton owner of YoutubeDL/FFmpeg init and all yt-dlp work.
 * Short queries (version/info/update) run on the caller's dispatcher;
 * downloads are launched on the engine scope and return immediately.
 * Terminal events go only through [DownloadEventBus] — never via method return.
 */
object YtDlpEngine {
    private const val TAG = "YtDlpEngine"

    /** Library build that ships the bundled ffmpeg payload — not an upstream ffmpeg version. */
    private const val FFMPEG_BUNDLED_LABEL = "bundled-0.18.1"

    /**
     * Default when Dart/MainActivity omit concurrent_fragments.
     * Must match YtdlpServiceAndroid.defaultConcurrentFragments (Dart).
     * 16 matches Windows broadband path so dual-stream DASH can saturate
     * the link; yt-dlp's own default (1) is far too slow for YouTube.
     */
    private const val DEFAULT_CONCURRENT_FRAGMENTS = 16

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private val activeJobs = ConcurrentHashMap<String, Job>()
    private val cancelledIds = ConcurrentHashMap.newKeySet<String>()
    private val runTokens = ConcurrentHashMap<String, Int>()
    private val jobLock = Any()

    @Volatile
    private var appContext: Context? = null

    @Volatile
    private var youtubeDLInitialized = false

    @Volatile
    private var ffmpegReady = false

    @Synchronized
    fun ensureInit(context: Context) {
        val app = context.applicationContext
        appContext = app
        if (!youtubeDLInitialized) {
            YoutubeDL.getInstance().init(app)
            youtubeDLInitialized = true
            Log.d(TAG, "YoutubeDL initialized successfully")
        }
        ensureFfmpeg()
    }

    /**
     * FFmpeg is only needed for post-processing (stream merge, thumbnail and
     * metadata embedding). Retried on demand so a transient failure at app
     * start doesn't silently disable embedding for the whole session.
     */
    @Synchronized
    fun ensureFfmpeg(): Boolean {
        if (ffmpegReady) return true
        val ctx = appContext ?: return false
        ffmpegReady = try {
            FFmpeg.getInstance().init(ctx)
            Log.d(TAG, "FFmpeg initialized successfully")
            true
        } catch (e: Throwable) {
            Log.e(TAG, "FFmpeg unavailable — merge/thumbnail/metadata embedding will be skipped", e)
            false
        }
        return ffmpegReady
    }

    /**
     * Truthful FFmpeg availability label, or null when the bundled payload
     * is missing / init failed. Never invents an upstream ffmpeg version —
     * the AAR does not expose one, and a fake "6.x" string is worse than null.
     * Returns the youtubedl-android library build tag when payload is present.
     */
    fun ffmpegVersion(): String? {
        return try {
            val ctx = appContext ?: return null
            // ensureFfmpeg is the availability gate: init must not have thrown.
            if (!ensureFfmpeg()) return null
            if (!hasFfmpegPayload(ctx)) {
                Log.w(TAG, "FFmpeg init reported ready but payload dir is empty/missing")
                return null
            }
            // Label reflects the bundled library build, not upstream ffmpeg.
            FFMPEG_BUNDLED_LABEL
        } catch (e: Throwable) {
            Log.w(TAG, "Failed to determine FFmpeg availability", e)
            null
        }
    }

    /**
     * youtubedl-android extracts ffmpeg under noBackupFilesDir/youtubedl-android/packages/.
     * Accept either an explicit "ffmpeg" package dir or any non-empty dir whose name
     * mentions ffmpeg (layout has varied slightly across AAR versions).
     */
    private fun hasFfmpegPayload(ctx: Context): Boolean {
        val packagesDir = File(ctx.noBackupFilesDir, "youtubedl-android/packages")
        if (!packagesDir.isDirectory) return false
        val candidates = packagesDir.listFiles() ?: return false
        return candidates.any { dir ->
            dir.isDirectory &&
                dir.name.contains("ffmpeg", ignoreCase = true) &&
                dir.walkTopDown().any { it.isFile }
        }
    }

    fun getVersion(context: Context): String? {
        return try {
            ensureInit(context)
            YoutubeDL.getInstance().version(context.applicationContext)
        } catch (e: Throwable) {
            Log.e(TAG, "Failed to get version", e)
            null
        }
    }

    fun getVideoInfo(context: Context, url: String, cookiesPath: String?, userAgent: String?): String {
        return try {
            ensureInit(context)
            var response = try {
                executeInfo(url, cookiesPath, userAgent, fallback = false, dumpFlag = "-j", extra = listOf("--no-playlist"))
            } catch (execError: Exception) {
                val msg = execError.message ?: ""
                if (isAuthOrBotFailure(msg)) {
                    Log.w(TAG, "Primary yt-dlp client failed, retrying with web/tv clients: $msg")
                    executeInfo(url, cookiesPath, userAgent, fallback = true, dumpFlag = "-j", extra = listOf("--no-playlist"))
                } else {
                    throw execError
                }
            }

            // Parse stdout ONCE (previous code double-parsed).
            val stdout = response.out
            val infoJson = JSONObject(stdout.trim())
            logFormatSummary(infoJson)

            val json = JSONObject()
            json.put("success", true)
            json.put("info", infoJson)
            json.toString()
        } catch (e: Throwable) {
            // Catch Throwable (not Exception): R8-stripped classes surface as
            // Error subclasses (NoClassDefFoundError, UnsatisfiedLinkError, …)
            // which Exception would miss, bubbling up as a bare PlatformException.
            errorJson(e, "Failed to get video info")
        }
    }

    fun getPlaylistInfo(
        context: Context,
        url: String,
        cookiesPath: String?,
        userAgent: String?,
        playlistItems: String? = null,
    ): String {
        return try {
            ensureInit(context)
            val extra = buildList {
                add("--flat-playlist")
                // yt-dlp --playlist-items is nargs=1: two argv tokens.
                if (!playlistItems.isNullOrBlank()) {
                    add("--playlist-items")
                    add(playlistItems.trim())
                }
            }
            val response = try {
                executeInfo(url, cookiesPath, userAgent, fallback = false, dumpFlag = "-J", extra = extra)
            } catch (execError: Exception) {
                val msg = execError.message ?: ""
                if (isAuthOrBotFailure(msg)) {
                    Log.w(TAG, "Primary yt-dlp playlist client failed, retrying with web/tv clients: $msg")
                    executeInfo(url, cookiesPath, userAgent, fallback = true, dumpFlag = "-J", extra = extra)
                } else {
                    throw execError
                }
            }
            val json = JSONObject()
            json.put("success", true)
            json.put("playlist", JSONObject(response.out.trim()))
            json.toString()
        } catch (e: Throwable) {
            errorJson(e, "Failed to get playlist info")
        }
    }

    /**
     * yt-dlp `ytsearchN:query` flat playlist search. Used as a fallback when
     * youtube_explode search fails (bot check / extractor breakage).
     */
    fun searchVideos(
        context: Context,
        query: String,
        limit: Int,
        cookiesPath: String?,
        userAgent: String?,
    ): String {
        return try {
            ensureInit(context)
            val n = limit.coerceIn(1, 25)
            val searchUrl = "ytsearch$n:$query"
            // --flat-playlist only. Do NOT pass --no-playlist: ytsearchN: is a
            // synthetic playlist and --no-playlist would collapse it to 1 video.
            val response = try {
                executeInfo(
                    searchUrl, cookiesPath, userAgent,
                    fallback = false, dumpFlag = "-J", extra = listOf("--flat-playlist")
                )
            } catch (execError: Exception) {
                val msg = execError.message ?: ""
                if (isAuthOrBotFailure(msg)) {
                    Log.w(TAG, "Primary yt-dlp search client failed, retrying with web/tv clients: $msg")
                    executeInfo(
                        searchUrl, cookiesPath, userAgent,
                        fallback = true, dumpFlag = "-J", extra = listOf("--flat-playlist")
                    )
                } else {
                    throw execError
                }
            }
            val json = JSONObject()
            json.put("success", true)
            json.put("results", JSONObject(response.out.trim()))
            json.toString()
        } catch (e: Throwable) {
            errorJson(e, "Failed to search videos")
        }
    }

    /**
     * Launches the download on the engine IO scope and returns immediately.
     * Terminal events (started/progress/completed/error/cancelled) are emitted
     * via [DownloadEventBus] only.
     *
     * Owns a per-process path-oracle file in cacheDir. yt-dlp writes the final
     * absolute path there via `--print-to-file after_move:filepath`; the engine
     * reads it after a successful run so Dart does not have to race mtime scans
     * under concurrent downloads.
     */
    fun startDownload(context: Context, job: DownloadJob, processId: String) {
        ensureInit(context)
        val ffmpegOk = ensureFfmpeg()
        // Resume and retry reuse this process id. A previous cancel left the id
        // in cancelledIds, which would swallow this run's completed/error event.
        // The token stops the previous coroutine from emitting after we clear it.
        val token: Int
        val previous = synchronized(jobLock) {
            val prev = activeJobs.remove(processId)
            cancelledIds.remove(processId)
            val next = (runTokens[processId] ?: 0) + 1
            runTokens[processId] = next
            token = next
            prev
        }
        previous?.cancel()
        if (previous != null) {
            try {
                YoutubeDL.getInstance().destroyProcessById(processId)
            } catch (_: Exception) {
            }
        }

        val pathFile = File(context.cacheDir, "ytdlp_path_${processId}_$token.txt")
        val effectiveJob = (if (ffmpegOk) job else job.copy(ffmpegAvailable = false))
            .withEngineDefaults(context, pathFile)

        fun isCurrentRun(): Boolean = synchronized(jobLock) { runTokens[processId] == token }

        var launched: Job? = null
        val work = scope.launch {
            try {
                if (!isCurrentRun()) return@launch
                val outDir = File(effectiveJob.outputPath)
                if (!outDir.exists()) {
                    outDir.mkdirs()
                }

                DownloadEventBus.emit(
                    mapOf(
                        "event" to "started",
                        "process_id" to processId,
                        "output_path" to effectiveJob.outputPath
                    )
                )

                executeDownload(effectiveJob, processId, PlayerClient.Default)

                if (!isCurrentRun() || cancelledIds.remove(processId)) {
                    Log.d(TAG, "Download $processId finished after cancel — suppressing completed")
                    pathFile.delete()
                    return@launch
                }

                val exactPath = readPathOracle(pathFile)
                val completed = mutableMapOf<String, Any?>(
                    "event" to "completed",
                    "process_id" to processId,
                    "output_path" to effectiveJob.outputPath,
                    // Surface post-processing degradation instead of silently
                    // shipping an unembedded/unmerged file.
                    "ffmpeg_skipped" to !ffmpegOk
                )
                if (exactPath != null) {
                    completed["filepath"] = exactPath
                }
                DownloadEventBus.emit(completed)
                DownloadService.instance?.completeDownload(processId)
            } catch (e: Throwable) {
                // Best-effort oracle: a partial download may still have printed a path.
                val partialPath = readPathOracle(pathFile)
                if (!isCurrentRun() || cancelledIds.remove(processId) || !isActive) {
                    Log.d(TAG, "Download $processId cancelled — suppressing error event")
                    return@launch
                }
                val fullError = buildErrorDetail(e)
                Log.e(TAG, "Failed to download video", e)
                val err = mutableMapOf<String, Any?>(
                    "event" to "error",
                    "process_id" to processId,
                    "output_path" to effectiveJob.outputPath,
                    "error" to fullError
                )
                if (partialPath != null) {
                    err["filepath"] = partialPath
                }
                DownloadEventBus.emit(err)
                DownloadService.instance?.completeDownload(processId)
            } finally {
                pathFile.delete()
                synchronized(jobLock) {
                    if (activeJobs[processId] === launched) {
                        activeJobs.remove(processId)
                    }
                }
            }
        }
        launched = work
        synchronized(jobLock) {
            if (cancelledIds.contains(processId)) {
                work.cancel()
            } else {
                activeJobs[processId] = work
            }
        }
    }

    /**
     * Fill engine-owned defaults when callers omit them.
     * printToFile is set here so the factory emits the correct 3-token
     * `--print-to-file after_move:filepath <file>` form.
     */
    private fun DownloadJob.withEngineDefaults(context: Context, pathFile: File): DownloadJob {
        return copy(
            concurrentFragments = concurrentFragments ?: DEFAULT_CONCURRENT_FRAGMENTS,
            tempDir = tempDir ?: File(context.cacheDir, "aerotube_temp").absolutePath,
            printToFile = printToFile ?: pathFile.absolutePath
        )
    }

    /**
     * Read the first non-empty line written by yt-dlp `--print-to-file`.
     * Always deletes the oracle file. Returns null when missing/empty.
     */
    private fun readPathOracle(pathFile: File): String? {
        return try {
            if (!pathFile.exists()) return null
            pathFile.readLines()
                .firstOrNull { it.isNotBlank() }
                ?.trim()
                ?.takeIf { it.isNotEmpty() }
        } catch (e: Throwable) {
            Log.w(TAG, "Failed to read path oracle ${pathFile.name}", e)
            null
        } finally {
            pathFile.delete()
        }
    }

    fun cancel(processId: String): Boolean {
        val job = synchronized(jobLock) {
            val existing = activeJobs.remove(processId)
            if (existing == null) {
                // Already stopped (or cancel already ran). Remember the id so a
                // late completed event is dropped, but do not emit again —
                // Dart treats every "cancelled" event as a new cancelDownload().
                cancelledIds.add(processId)
                null
            } else {
                cancelledIds.add(processId)
                existing
            }
        } ?: return false
        return try {
            YoutubeDL.getInstance().destroyProcessById(processId)
            job.cancel()
            DownloadEventBus.emit(
                mapOf(
                    "event" to "cancelled",
                    "process_id" to processId
                )
            )
            DownloadService.instance?.completeDownload(processId)
            true
        } catch (e: Exception) {
            Log.e(TAG, "Failed to cancel download", e)
            false
        }
    }

    fun cancelAll() {
        val ids = activeJobs.keys.toList()
        for (id in ids) {
            cancel(id)
        }
    }

    fun activeProcessIds(): Set<String> = activeJobs.keys.toSet()

    fun updateYoutubeDL(context: Context, updateChannel: String): String {
        val app = context.applicationContext
        val json = JSONObject()
        var lastNativeError: String? = null

        try {
            ensureInit(app)

            val status = if (updateChannel == "nightly") {
                YoutubeDL.getInstance().updateYoutubeDL(app, YoutubeDL.UpdateChannel.NIGHTLY)
            } else {
                YoutubeDL.getInstance().updateYoutubeDL(app, YoutubeDL.UpdateChannel.STABLE)
            }

            when (status?.name) {
                "DONE", "SUCCESS" -> {
                    json.put("success", true)
                    json.put("message", "Update successful")
                    json.put("status", "updated")
                    Log.d(TAG, "yt-dlp update successful via native updater")
                    return json.toString()
                }
                "ALREADY_UP_TO_DATE" -> {
                    json.put("success", true)
                    json.put("message", "Already up to date")
                    json.put("status", "up_to_date")
                    Log.d(TAG, "yt-dlp already up to date")
                    return json.toString()
                }
                else -> {
                    lastNativeError = "Native updater status: ${status?.name}"
                    Log.w(TAG, "Native yt-dlp update returned status: $status, attempting fallback")
                }
            }
        } catch (e: Throwable) {
            lastNativeError = e.message ?: e.toString()
            Log.w(TAG, "Native yt-dlp update threw exception, attempting fallback: $lastNativeError")
        }

        // Fallback: Direct download from release endpoints with user-agent and redirect support
        return try {
            val fallbackResult = downloadAndInstallYtdlpFallback(app)
            if (fallbackResult.first) {
                val installedVersion = fallbackResult.second ?: "latest"
                json.put("success", true)
                json.put("message", "Update successful via fallback")
                json.put("status", "updated")
                json.put("version", installedVersion)
                Log.d(TAG, "yt-dlp fallback update succeeded with version $installedVersion")
            } else {
                val failureReason = fallbackResult.second ?: "Direct download failed"
                json.put("success", false)
                json.put("status", "update_failed")

                val is403 = lastNativeError?.contains("403") == true || failureReason.contains("403")
                val isTimeout = lastNativeError?.contains("timeout", ignoreCase = true) == true ||
                    failureReason.contains("timeout", ignoreCase = true) ||
                    lastNativeError?.contains("ConnectException") == true

                val category = when {
                    is403 -> "rateLimit"
                    isTimeout -> "network"
                    else -> "unknown"
                }

                val friendlyMsg = when {
                    is403 -> "GitHub rate limit exceeded. Direct fallback also failed."
                    isTimeout -> "Network connection to GitHub timed out. Check internet or VPN."
                    else -> "Failed to update yt-dlp: $failureReason"
                }

                json.put("error", friendlyMsg)
                json.put("category", category)
                json.put("details", "Native error: $lastNativeError\nFallback error: $failureReason")
                json.put(
                    "suggestion",
                    if (is403) "Wait 15 minutes for the rate limit to reset, or switch internet connection/VPN."
                    else "Check internet connectivity and try again."
                )
            }
            json.toString()
        } catch (fallbackEx: Throwable) {
            Log.e(TAG, "Fallback yt-dlp update crashed", fallbackEx)
            json.put("success", false)
            json.put("status", "update_failed")
            json.put("error", fallbackEx.message ?: "Update failed")
            json.put("details", "Native: $lastNativeError\nFallback: ${fallbackEx.message}")
            json.put("stacktrace", fallbackEx.stackTraceToString())
            json.toString()
        }
    }

    // --- internals ---

    private fun isAuthOrBotFailure(msg: String): Boolean {
        return msg.contains("Sign in to confirm", ignoreCase = true) ||
            msg.contains("bot", ignoreCase = true) ||
            msg.contains("403")
    }

    private fun isDownloadRetryable(msg: String): Boolean {
        return isAuthOrBotFailure(msg) ||
            msg.contains("Requested format is not available")
    }

    /**
     * Convert factory [BuiltRequest] into a [YoutubeDLRequest].
     * Typed pairing — no startsWith("-") heuristic (that mis-paired
     * negative-looking values and bare flags).
     */
    private fun buildRequest(built: BuiltRequest): YoutubeDLRequest {
        val request = YoutubeDLRequest(built.url)
        for (opt in built.options) {
            when (opt) {
                is YtDlpArg.Flag -> request.addOption(opt.name)
                is YtDlpArg.Opt -> request.addOption(opt.name, opt.value)
                // nargs>1: each value is its own argv token (not key=value).
                is YtDlpArg.OptN -> {
                    request.addOption(opt.name)
                    for (value in opt.values) {
                        request.addOption(value)
                    }
                }
            }
        }
        return request
    }

    private fun executeInfo(
        url: String,
        cookiesPath: String?,
        userAgent: String?,
        fallback: Boolean,
        dumpFlag: String,
        extra: List<String>,
    ): com.yausername.youtubedl_android.YoutubeDLResponse {
        val cookies = cookiesPath?.takeIf { it.isNotEmpty() && File(it).exists() }
        if (cookiesPath != null && cookiesPath.isNotEmpty() && cookies == null) {
            Log.e(TAG, "Cookie file not found at: $cookiesPath")
        }
        val built = YtDlpRequestFactory.infoArgs(url, cookies, userAgent, fallback)
        val request = buildRequest(built)
        request.addOption(dumpFlag)
        for (flag in extra) {
            request.addOption(flag)
        }
        return YoutubeDL.getInstance().execute(request)
    }

    private fun logFormatSummary(infoJson: JSONObject) {
        if (!infoJson.has("formats")) {
            Log.w(TAG, "No 'formats' array in yt-dlp output!")
            return
        }
        val formats = infoJson.getJSONArray("formats")
        Log.d(TAG, "Received ${formats.length()} formats from yt-dlp")
        var videoOnly = 0
        var audioOnly = 0
        var combined = 0
        for (i in 0 until formats.length()) {
            val format = formats.getJSONObject(i)
            val vcodec = format.optString("vcodec", "none")
            val acodec = format.optString("acodec", "none")
            val hasVideo = vcodec.isNotEmpty() && vcodec != "none"
            val hasAudio = acodec.isNotEmpty() && acodec != "none"
            when {
                hasVideo && !hasAudio -> videoOnly++
                !hasVideo && hasAudio -> audioOnly++
                hasVideo && hasAudio -> combined++
            }
        }
        Log.d(TAG, "Video-only: $videoOnly, Audio-only: $audioOnly, Combined: $combined")
    }

    private fun executeDownload(job: DownloadJob, processId: String, client: PlayerClient) {
        val built = YtDlpRequestFactory.downloadArgs(job, client)
        val request = buildRequest(built)
        try {
            YoutubeDL.getInstance().execute(request, processId) { progress, eta, line ->
                DownloadEventBus.emit(
                    mapOf(
                        "event" to "progress",
                        "process_id" to processId,
                        "progress" to progress,
                        "eta" to eta,
                        "line" to line,
                        "output_path" to job.outputPath
                    )
                )
                // youtubedl-android reports 0..100. DownloadService expects 0..1;
                // passing the raw value clamps to 100% at the first percent.
                val fraction = (progress / 100f).coerceIn(0f, 1f)
                DownloadService.instance?.reportProgress(processId, fraction, line)
            }
        } catch (execError: Exception) {
            val msg = execError.message ?: ""
            if (client == PlayerClient.Default && isDownloadRetryable(msg)) {
                Log.w(TAG, "Download client failed ($msg), retrying with web/tv/mweb")
                executeDownload(job, processId, PlayerClient.Fallback)
            } else {
                throw execError
            }
        }
    }

    private fun buildErrorDetail(e: Throwable): String {
        val errorMsg = "${e.javaClass.name}: ${e.message ?: "Unknown error"}"
        return "${errorMsg}\nStack: ${Log.getStackTraceString(e)}"
    }

    private fun errorJson(e: Throwable, logMessage: String): String {
        Log.e(TAG, logMessage, e)
        val json = JSONObject()
        json.put("success", false)
        json.put("error", buildErrorDetail(e))
        return json.toString()
    }

    private fun downloadAndInstallYtdlpFallback(context: Context): Pair<Boolean, String?> {
        // Primary: official GitHub release only.
        // Secondary: ghproxy.net mirror — THIRD-PARTY proxy, trust risk.
        // SHA-256 is verified against the official checksum before install,
        // so a tampered mirror payload is refused.
        val downloadUrls = listOf(
            "https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp",
            "https://ghproxy.net/https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp"
        )
        val checksumUrls = listOf(
            "https://github.com/yt-dlp/yt-dlp/releases/latest/download/SHA2-256SUMS"
        )

        val tempFile = File.createTempFile("ytdlp_dl", ".tmp", context.cacheDir)
        var lastErr = ""

        try {
            var downloadSuccess = false
            for (urlString in downloadUrls) {
                try {
                    val isMirror = !urlString.startsWith("https://github.com/")
                    if (isMirror) {
                        Log.w(
                            TAG,
                            "Falling back to third-party mirror $urlString — " +
                                "payload is SHA-256-verified against the official checksum before install"
                        )
                    }
                    Log.d(TAG, "Attempting yt-dlp download from: $urlString")
                    var currentUrl = urlString
                    var conn: HttpURLConnection? = null
                    var redirects = 0
                    val maxRedirects = 6

                    while (redirects < maxRedirects) {
                        val url = URL(currentUrl)
                        conn = (url.openConnection() as HttpURLConnection).apply {
                            instanceFollowRedirects = false
                            connectTimeout = 15000
                            readTimeout = 40000
                            setRequestProperty("User-Agent", "Mozilla/5.0 (Android; AeroTube-Downloader/1.0)")
                            setRequestProperty("Accept", "*/*")
                        }
                        val code = conn.responseCode
                        if (code in 301..308) {
                            val newLoc = conn.getHeaderField("Location")
                            conn.disconnect()
                            if (newLoc != null) {
                                currentUrl = newLoc
                                redirects++
                                continue
                            }
                        }
                        break
                    }

                    if (conn != null && conn.responseCode == HttpURLConnection.HTTP_OK) {
                        conn.inputStream.use { input ->
                            tempFile.outputStream().use { output ->
                                input.copyTo(output)
                            }
                        }
                        conn.disconnect()

                        // Cheap pre-filter only — not an integrity check.
                        if (tempFile.exists() && tempFile.length() > 1024 * 1024) {
                            downloadSuccess = true
                            Log.d(TAG, "yt-dlp download completed (${tempFile.length()} bytes)")
                            break
                        } else {
                            lastErr = "Downloaded file too small (${tempFile.length()} bytes)"
                        }
                    } else {
                        lastErr = "HTTP ${conn?.responseCode} from $urlString"
                        conn?.disconnect()
                    }
                } catch (e: Exception) {
                    lastErr = e.message ?: e.toString()
                    Log.w(TAG, "Download attempt failed from $urlString: $lastErr")
                }
            }

            if (!downloadSuccess) {
                tempFile.delete()
                return Pair(false, lastErr)
            }

            // Integrity: refuse to install unless SHA-256 matches the official release checksum.
            val expectedSha = fetchOfficialSha256(checksumUrls, "yt-dlp")
            if (expectedSha == null) {
                tempFile.delete()
                return Pair(false, "SHA-256 mismatch — refusing to install (official checksum unavailable)")
            }
            val actualSha = sha256Of(tempFile)
            if (!actualSha.equals(expectedSha, ignoreCase = true)) {
                Log.e(TAG, "yt-dlp SHA-256 mismatch: expected=$expectedSha actual=$actualSha")
                tempFile.delete()
                return Pair(false, "SHA-256 mismatch — refusing to install")
            }
            Log.d(TAG, "yt-dlp SHA-256 verified ($actualSha)")

            var extractedVersion: String? = null
            try {
                java.util.zip.ZipFile(tempFile).use { zip ->
                    val entry = zip.getEntry("yt_dlp/version.py")
                    if (entry != null) {
                        val content = zip.getInputStream(entry).bufferedReader().use { it.readText() }
                        val match = Regex("""__version__\s*=\s*['"]([^'"]+)['"]""").find(content)
                        extractedVersion = match?.groupValues?.get(1)
                    }
                }
            } catch (e: Exception) {
                Log.w(TAG, "Could not extract version from yt-dlp zipapp: ${e.message}")
            }

            if (extractedVersion == null) {
                val sdf = java.text.SimpleDateFormat("yyyy.MM.dd", java.util.Locale.US)
                extractedVersion = sdf.format(java.util.Date())
            }

            val baseDir = File(context.noBackupFilesDir, "youtubedl-android")
            val ytdlpDir = File(baseDir, "yt-dlp")
            if (ytdlpDir.exists()) {
                ytdlpDir.deleteRecursively()
            }
            ytdlpDir.mkdirs()

            val targetFile = File(ytdlpDir, "yt-dlp")
            tempFile.copyTo(targetFile, overwrite = true)
            tempFile.delete()

            YoutubeDL.getInstance().init_ytdlp(context, ytdlpDir)

            try {
                val prefs = context.getSharedPreferences("youtubedl-android", Context.MODE_PRIVATE)
                prefs.edit()
                    .putString("dlpVersion", extractedVersion)
                    .putString("dlpVersionName", extractedVersion)
                    .apply()
            } catch (pe: Exception) {
                Log.w(TAG, "Failed to save version to prefs: ${pe.message}")
            }

            return Pair(true, extractedVersion)
        } catch (e: Exception) {
            tempFile.delete()
            return Pair(false, e.message ?: e.toString())
        }
    }

    /**
     * Fetch the official yt-dlp release SHA-256.
     * SHA2-256SUMS lines are `<hash>  filename` or `<hash> *filename`.
     * A one-line file of just `<hash>` is accepted when [assetName] is null.
     */
    private fun fetchOfficialSha256(checksumUrls: List<String>, assetName: String): String? {
        val hex = Regex("[0-9a-fA-F]{64}")
        for (urlString in checksumUrls) {
            try {
                val conn = (URL(urlString).openConnection() as HttpURLConnection).apply {
                    connectTimeout = 15000
                    readTimeout = 20000
                    setRequestProperty("User-Agent", "Mozilla/5.0 (Android; AeroTube-Downloader/1.0)")
                }
                if (conn.responseCode != HttpURLConnection.HTTP_OK) {
                    conn.disconnect()
                    continue
                }
                val text = conn.inputStream.bufferedReader().use { it.readText() }
                conn.disconnect()
                for (rawLine in text.lineSequence()) {
                    val line = rawLine.trim()
                    if (line.isEmpty() || line.startsWith("#")) continue
                    val parts = line.split(Regex("\\s+"))
                    val hash = parts.firstOrNull()?.lowercase() ?: continue
                    if (!hash.matches(hex)) continue
                    if (parts.size == 1) return hash
                    val name = parts.last().removePrefix("*").substringAfterLast('/')
                    if (name == assetName) return hash
                }
                Log.w(TAG, "Checksum file from $urlString had no entry for $assetName")
            } catch (e: Throwable) {
                Log.w(TAG, "Failed to fetch SHA-256 from $urlString: ${e.message}")
            }
        }
        return null
    }

    private fun sha256Of(file: File): String {
        val digest = MessageDigest.getInstance("SHA-256")
        file.inputStream().use { input ->
            val buf = ByteArray(8192)
            while (true) {
                val n = input.read(buf)
                if (n < 0) break
                digest.update(buf, 0, n)
            }
        }
        return digest.digest().joinToString("") { "%02x".format(it) }
    }
}
