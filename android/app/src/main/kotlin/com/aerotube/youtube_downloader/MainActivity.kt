package com.aerotube.youtube_downloader

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.util.Log
import androidx.core.content.FileProvider
import com.yausername.ffmpeg.FFmpeg
import com.yausername.youtubedl_android.YoutubeDL
import com.yausername.youtubedl_android.YoutubeDLRequest
import com.yausername.youtubedl_android.YoutubeDLResponse
import com.yausername.youtubedl_android.YoutubeDL.UpdateStatus
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject
import java.io.File
import java.lang.reflect.Method
import java.util.concurrent.ConcurrentHashMap

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.aerotube.youtube_downloader/permissions"
    private val YTDLP_CHANNEL = "com.aerotube.youtube_downloader/ytdlp_android"
    private val YTDLP_EVENTS_CHANNEL = "com.aerotube.youtube_downloader/ytdlp_android/events"
    private val SERVICE_CHANNEL = "com.aerotube.youtube_downloader/download_service"
    private val FILE_PROVIDER_CHANNEL = "com.aerotube.youtube_downloader/file_provider"
    private val DEEP_LINK_CHANNEL = "com.aerotube.youtube_downloader/deep_links"
    private val DEEP_LINK_EVENTS_CHANNEL = "com.aerotube.youtube_downloader/deep_links/events"
    
    // Store active download processes by ID
    private val activeDownloads = ConcurrentHashMap<String, Boolean>()
    @Volatile
    private var downloadEventSink: EventChannel.EventSink? = null
    @Volatile
    private var deepLinkEventSink: EventChannel.EventSink? = null
    @Volatile
    private var pendingDeepLink: String? = null
    
    companion object {
        private const val TAG = "MainActivity"
    }

    @Volatile
    private var youtubeDLInitialized = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Initialize YoutubeDL and FFmpeg
        try {
            ensureYoutubeDLInitialized()
        } catch (e: Throwable) {
            Log.e(TAG, "YoutubeDL init failed", e)
        }

        pendingDeepLink = extractDeepLink(intent)

        // Original permissions channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "setExecutable" -> {
                    val path = call.argument<String>("path")
                    if (path == null) {
                        result.error("INVALID_ARGUMENT", "Path is required", null)
                        return@setMethodCallHandler
                    }
                    val success = setFileExecutable(path)
                    result.success(success)
                }
                "checkExecutable" -> {
                    val path = call.argument<String>("path")
                    if (path == null) {
                        result.error("INVALID_ARGUMENT", "Path is required", null)
                        return@setMethodCallHandler
                    }
                    val isExecutable = isFileExecutable(path)
                    result.success(isExecutable)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }

        // Download service channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SERVICE_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startDownloadService" -> {
                    val downloadId = call.argument<String>("downloadId")
                    val url = call.argument<String>("url")
                    val outputPath = call.argument<String>("outputPath")
                    val format = call.argument<String>("format")
                    val cookiesPath = call.argument<String>("cookiesPath")
                    val userAgent = call.argument<String>("userAgent")
                    val title = call.argument<String>("title")

                    if (downloadId == null || url == null || outputPath == null) {
                        result.error("INVALID_ARGUMENT", "downloadId, url, and outputPath are required", null)
                        return@setMethodCallHandler
                    }

                    startDownloadService(downloadId, url, outputPath, format, cookiesPath, userAgent, title)
                    result.success(true)
                }
                "stopDownloadService" -> {
                    stopDownloadService()
                    result.success(true)
                }
                "cancelDownload" -> {
                    val downloadId = call.argument<String>("downloadId")
                    if (downloadId == null) {
                        result.error("INVALID_ARGUMENT", "downloadId is required", null)
                        return@setMethodCallHandler
                    }
                    cancelDownloadInService(downloadId)
                    result.success(true)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }

        // youtubedl-android channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, YTDLP_CHANNEL).setMethodCallHandler { call, result ->
            Thread {
                try {
                    when (call.method) {
                        "getVersion" -> {
                            val version = getVersion()
                            android.os.Handler(android.os.Looper.getMainLooper()).post { result.success(version) }
                        }
                        "getVideoInfo" -> {
                            val url = call.argument<String>("url")
                            val cookiesPath = call.argument<String>("cookies_path")
                            val userAgent = call.argument<String>("user_agent")

                            if (url == null) {
                                android.os.Handler(android.os.Looper.getMainLooper()).post { result.error("INVALID_ARGUMENT", "URL is required", null) }
                                return@Thread
                            }

                            val infoJson = getVideoInfo(url, cookiesPath, userAgent)
                            android.os.Handler(android.os.Looper.getMainLooper()).post { result.success(infoJson) }
                        }
                        "getPlaylistInfo" -> {
                            val url = call.argument<String>("url")
                            val cookiesPath = call.argument<String>("cookies_path")
                            val userAgent = call.argument<String>("user_agent")

                            if (url == null) {
                                android.os.Handler(android.os.Looper.getMainLooper()).post { result.error("INVALID_ARGUMENT", "URL is required", null) }
                                return@Thread
                            }

                            val playlistJson = getPlaylistInfo(url, cookiesPath, userAgent)
                            android.os.Handler(android.os.Looper.getMainLooper()).post { result.success(playlistJson) }
                        }
                        "downloadVideo" -> {
                            val url = call.argument<String>("url")
                            val outputPath = call.argument<String>("output_path")
                            val format = call.argument<String>("format")
                            val cookiesPath = call.argument<String>("cookies_path")
                            val userAgent = call.argument<String>("user_agent")
                            val processId = call.argument<String>("process_id")

                            if (url == null || outputPath == null) {
                                android.os.Handler(android.os.Looper.getMainLooper()).post { result.error("INVALID_ARGUMENT", "URL and output_path are required", null) }
                                return@Thread
                            }

                            val id = processId ?: "download_${System.currentTimeMillis()}"
                            val downloadResult = downloadVideo(url, outputPath, format, cookiesPath, userAgent, id)
                            android.os.Handler(android.os.Looper.getMainLooper()).post { result.success(downloadResult) }
                        }
                        "cancelDownload" -> {
                            val processId = call.argument<String>("process_id")
                            if (processId == null) {
                                android.os.Handler(android.os.Looper.getMainLooper()).post { result.error("INVALID_ARGUMENT", "process_id is required", null) }
                                return@Thread
                            }
                            val success = cancelDownload(processId)
                            android.os.Handler(android.os.Looper.getMainLooper()).post { result.success(success) }
                        }
                        "updateYoutubeDL" -> {
                            val updateChannel = call.argument<String>("update_channel") ?: "stable"
                            val updateResult = updateYoutubeDL(updateChannel)
                            android.os.Handler(android.os.Looper.getMainLooper()).post { result.success(updateResult) }
                        }
                        else -> {
                            android.os.Handler(android.os.Looper.getMainLooper()).post { result.notImplemented() }
                        }
                    }
                } catch (e: Throwable) {
                    Log.e(TAG, "Error handling method call", e)
                    android.os.Handler(android.os.Looper.getMainLooper()).post {
                        result.error("YTDLP_ERROR", e.message, e.stackTraceToString())
                    }
                }
            }.start()
        }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, YTDLP_EVENTS_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    downloadEventSink = events
                }

                override fun onCancel(arguments: Any?) {
                    downloadEventSink = null
                }
            })

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, DEEP_LINK_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getInitialLink" -> {
                    result.success(pendingDeepLink)
                    pendingDeepLink = null
                }
                else -> result.notImplemented()
            }
        }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, DEEP_LINK_EVENTS_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    deepLinkEventSink = events
                    pendingDeepLink?.let {
                        events?.success(it)
                        pendingDeepLink = null
                    }
                }

                override fun onCancel(arguments: Any?) {
                    deepLinkEventSink = null
                }
            })

        // FileProvider channel — converts raw file paths to shareable content:// URIs
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, FILE_PROVIDER_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getContentUri" -> {
                    val filePath = call.argument<String>("filePath")
                    if (filePath == null) {
                        result.error("INVALID_ARGUMENT", "filePath is required", null)
                        return@setMethodCallHandler
                    }
                    try {
                        val file = File(filePath)
                        if (!file.exists()) {
                            result.error("FILE_NOT_FOUND", "File does not exist: $filePath", null)
                            return@setMethodCallHandler
                        }
                        val authority = "${applicationContext.packageName}.fileprovider"
                        val contentUri: Uri = FileProvider.getUriForFile(applicationContext, authority, file)
                        Log.d(TAG, "FileProvider URI: $contentUri")
                        result.success(contentUri.toString())
                    } catch (e: Exception) {
                        Log.e(TAG, "FileProvider.getUriForFile failed", e)
                        result.error("PROVIDER_ERROR", e.message, e.stackTraceToString())
                    }
                }
                "installApk" -> {
                    val filePath = call.argument<String>("filePath")
                    if (filePath == null) {
                        result.error("INVALID_ARGUMENT", "filePath is required", null)
                        return@setMethodCallHandler
                    }
                    try {
                        val file = File(filePath)
                        if (!file.exists()) {
                            result.error("FILE_NOT_FOUND", "APK not found: $filePath", null)
                            return@setMethodCallHandler
                        }
                        val authority = "${applicationContext.packageName}.fileprovider"
                        val contentUri: Uri = FileProvider.getUriForFile(applicationContext, authority, file)
                        val intent = Intent(Intent.ACTION_VIEW).apply {
                            setDataAndType(contentUri, "application/vnd.android.package-archive")
                            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        Log.e(TAG, "installApk failed", e)
                        result.error("INSTALL_ERROR", e.message, e.stackTraceToString())
                    }
                }
                "getDeviceAbi" -> {
                    val primaryAbi = Build.SUPPORTED_ABIS.firstOrNull() ?: ""
                    result.success(primaryAbi)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)

        val deepLink = extractDeepLink(intent) ?: return
        if (deepLinkEventSink != null) {
            deepLinkEventSink?.success(deepLink)
        } else {
            pendingDeepLink = deepLink
        }
    }

    private fun extractDeepLink(intent: Intent?): String? {
        if (intent?.action != Intent.ACTION_VIEW) return null

        val uri = intent.data?.toString()?.takeIf { it.isNotBlank() }
        if (uri != null) {
            Log.d(TAG, "Received deep link: $uri")
        }
        return uri
    }

    private fun getVersion(): String? {
        return try {
            YoutubeDL.getInstance().version(applicationContext)
        } catch (e: Throwable) {
            Log.e(TAG, "Failed to get version", e)
            null
        }
    }

    @Synchronized
    private fun ensureYoutubeDLInitialized() {
        if (youtubeDLInitialized) return

        YoutubeDL.getInstance().init(applicationContext)

        try {
            FFmpeg.getInstance().init(applicationContext)
            Log.d(TAG, "FFmpeg initialized successfully")
        } catch (e: Throwable) {
            Log.e(TAG, "Failed to initialize FFmpeg - merging will not work", e)
        }

        youtubeDLInitialized = true
        Log.d(TAG, "YoutubeDL initialized successfully")
    }

    private fun getVideoInfo(url: String, cookiesPath: String?, userAgent: String?): String {
        return try {
            ensureYoutubeDLInitialized()
            val request = YoutubeDLRequest(url)

            // Add cookies if provided
            if (cookiesPath != null && cookiesPath.isNotEmpty()) {
                Log.d(TAG, "Using cookies from file: $cookiesPath")
                val cookieFile = File(cookiesPath)
                if (cookieFile.exists()) {
                    Log.d(TAG, "Cookie file exists, size: ${cookieFile.length()} bytes")
                    request.addOption("--cookies", cookiesPath)
                } else {
                    Log.e(TAG, "Cookie file not found at: $cookiesPath")
                }
            }

            // Add custom user agent if provided
            if (userAgent != null && userAgent.isNotEmpty()) {
                request.addOption("--user-agent", userAgent)
            }

            // Reliability fixes
            request.addOption("--force-ipv4") 
            request.addOption("--socket-timeout", "15")
            request.addOption("--retries", "3")

            // CRITICAL: Use same extractor args as getVideoInfo to get all formats
            request.addOption("--extractor-args", "youtube:player_client=media")
            request.addOption("--no-warnings")

            // CRITICAL: Use extractor args to get ALL formats
            // player_client=media: This uses the media endpoint which returns ALL format streams
            // This is the key to getting separate video/audio streams at all qualities
            request.addOption("--extractor-args", "youtube:player_client=media")
            
            // Get video info as JSON
            request.addOption("-j") // --dump-json
            request.addOption("--no-playlist")

            val response = YoutubeDL.getInstance().execute(request)

            // The JSON output is in out
            val stdout = response.out
            val json = JSONObject()
            json.put("success", true)
            json.put("info", JSONObject(stdout))
            
            // Log format count for debugging
            val infoJson = JSONObject(stdout)
            if (infoJson.has("formats")) {
                val formats = infoJson.getJSONArray("formats")
                Log.d(TAG, "Received ${formats.length()} formats from yt-dlp")
                
                // Count format types
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
            } else {
                Log.w(TAG, "No 'formats' array in yt-dlp output!")
            }
            
            json.toString()
        } catch (e: Exception) {
            val errorMsg = e.message ?: "Unknown error"
            val fullError = "${errorMsg}\nStack: ${Log.getStackTraceString(e)}"
            Log.e(TAG, "Failed to get video info", e)
            val json = JSONObject()
            json.put("success", false)
            json.put("error", fullError)
            json.toString()
        }
    }

    private fun getPlaylistInfo(url: String, cookiesPath: String?, userAgent: String?): String {
        return try {
            ensureYoutubeDLInitialized()
            val request = YoutubeDLRequest(url)
            
            // Add cookies if provided
            if (cookiesPath != null && cookiesPath.isNotEmpty()) {
                request.addOption("--cookies", cookiesPath)
            }
            
            // Add custom user agent if provided
            if (userAgent != null && userAgent.isNotEmpty()) {
                request.addOption("--user-agent", userAgent)
            }
            
            // Reliability fixes
            request.addOption("--force-ipv4") 
            request.addOption("--socket-timeout", "15")
            request.addOption("--retries", "3")
            request.addOption("--no-warnings")
            


            // Get playlist info
            request.addOption("-j") // --dump-json
            request.addOption("--flat-playlist")
            
            val response = YoutubeDL.getInstance().execute(request)
            val stdout = response.out
            val json = JSONObject()
            json.put("success", true)
            json.put("playlist", JSONObject(stdout))
            json.toString()
        } catch (e: Exception) {
            val errorMsg = e.message ?: "Unknown error"
            val fullError = "${errorMsg}\nStack: ${Log.getStackTraceString(e)}"
            Log.e(TAG, "Failed to get playlist info", e)
            val json = JSONObject()
            json.put("success", false)
            json.put("error", fullError)
            json.toString()
        }
    }

    private fun downloadVideo(
        url: String,
        outputPath: String,
        format: String?,
        cookiesPath: String?,
        userAgent: String?,
        processId: String
    ): String {
        return try {
            ensureYoutubeDLInitialized()
            emitDownloadEvent(
                mapOf(
                    "event" to "started",
                    "process_id" to processId,
                    "output_path" to outputPath
                )
            )

            val request = YoutubeDLRequest(url)
            
            // Set output template
            request.addOption("-o", "$outputPath/%(title)s.%(ext)s")
            
            // Set format if provided
            if (format != null && format.isNotEmpty()) {
                request.addOption("-f", format)
            } else {
                request.addOption("-f", "best")
            }
            
            // Add cookies if provided
            if (cookiesPath != null && cookiesPath.isNotEmpty()) {
                request.addOption("--cookies", cookiesPath)
            }
            
            // Add custom user agent if provided
            if (userAgent != null && userAgent.isNotEmpty()) {
                request.addOption("--user-agent", userAgent)
            }
            
            // Reliability fixes
            request.addOption("--force-ipv4") 
            request.addOption("--socket-timeout", "15")
            request.addOption("--retries", "3")
            request.addOption("--no-playlist")
            request.addOption("--no-warnings")
            request.addOption("--newline")
            
            // Use media endpoint for consistent format access
            request.addOption("--extractor-args", "youtube:player_client=media")
            
            // Ensure merging to MP4 container (required for bestvideo+bestaudio)
            request.addOption("--merge-output-format", "mp4")
            request.addOption("--write-thumbnail")


            // Store process ID
            activeDownloads[processId] = true
            
            // Execute download with progress callback
            YoutubeDL.getInstance().execute(request, processId) { progress, eta, line ->
                Log.d(TAG, "Download progress: $progress% - ETA: ${eta}s - Speed: $line bytes/s")
                emitDownloadEvent(
                    mapOf(
                        "event" to "progress",
                        "process_id" to processId,
                        "progress" to progress,
                        "eta" to eta,
                        "line" to line,
                        "output_path" to outputPath
                    )
                )
            }

            emitDownloadEvent(
                mapOf(
                    "event" to "completed",
                    "process_id" to processId,
                    "output_path" to outputPath
                )
            )
            
            val json = JSONObject()
            json.put("success", true)
            json.put("process_id", processId)
            json.put("message", "Download started")
            json.toString()
        } catch (e: Exception) {
            val errorMsg = e.message ?: "Unknown error"
            val fullError = "${errorMsg}\nStack: ${Log.getStackTraceString(e)}"
            Log.e(TAG, "Failed to download video", e)
            activeDownloads.remove(processId)
            emitDownloadEvent(
                mapOf(
                    "event" to "error",
                    "process_id" to processId,
                    "output_path" to outputPath,
                    "error" to fullError
                )
            )
            val json = JSONObject()
            json.put("success", false)
            json.put("error", fullError)
            json.toString()
        }
    }

    private fun cancelDownload(processId: String): Boolean {
        return try {
            ensureYoutubeDLInitialized()
            YoutubeDL.getInstance().destroyProcessById(processId)
            activeDownloads.remove(processId)
            emitDownloadEvent(
                mapOf(
                    "event" to "cancelled",
                    "process_id" to processId
                )
            )
            true
        } catch (e: Exception) {
            Log.e(TAG, "Failed to cancel download", e)
            false
        }
    }

    private fun emitDownloadEvent(event: Map<String, Any?>) {
        runOnUiThread {
            try {
                downloadEventSink?.success(event)
            } catch (e: Exception) {
                Log.w(TAG, "Failed to emit download event", e)
            }
        }
    }

    private fun updateYoutubeDL(updateChannel: String): String {
        return try {
            ensureYoutubeDLInitialized()
            
            val status = if (updateChannel == "nightly") {
                YoutubeDL.getInstance().updateYoutubeDL(applicationContext, YoutubeDL.UpdateChannel.NIGHTLY)
            } else {
                YoutubeDL.getInstance().updateYoutubeDL(applicationContext, YoutubeDL.UpdateChannel.STABLE)
            }
            
            val json = JSONObject()
            when (status?.name) {
                "DONE", "SUCCESS" -> {
                    json.put("success", true)
                    json.put("message", "Update successful")
                    json.put("status", "updated")
                    Log.d(TAG, "yt-dlp update successful")
                }
                "ALREADY_UP_TO_DATE" -> {
                    json.put("success", true)
                    json.put("message", "Already up to date")
                    json.put("status", "up_to_date")
                    Log.d(TAG, "yt-dlp already up to date")
                }
                "ERROR", "FAILURE" -> {
                    json.put("success", false)
                    json.put("message", "Update failed")
                    json.put("status", "update_failed")
                    Log.e(TAG, "yt-dlp update failed with status: $status")
                }
                else -> {
                    json.put("success", false)
                    json.put("message", "Unknown update status: ${status?.name}")
                    json.put("status", "unknown")
                    Log.w(TAG, "yt-dlp update unknown status: ${status?.name}")
                }
            }
            json.toString()
        } catch (e: Throwable) {
            Log.e(TAG, "Failed to update yt-dlp", e)
            val json = JSONObject()
            json.put("success", false)
            json.put("error", e.message ?: "Unknown error")
            json.put("stacktrace", e.stackTraceToString())
            json.toString()
        }
    }
    private fun setFileExecutable(path: String): Boolean {
        return try {
            val file = File(path)
            if (!file.exists()) return false

            // Try chmod via Runtime.exec
            try {
                val chmodProcess = Runtime.getRuntime().exec(arrayOf("chmod", "755", path))
                val exitCode = chmodProcess.waitFor()
                if (exitCode == 0) return true
            } catch (e: Exception) {
                // chmod via exec failed, try reflection
            }

            // Try using File.setExecutable via reflection (API 21+)
            try {
                val method: Method = File::class.java.getMethod("setExecutable", Boolean::class.javaPrimitiveType, Boolean::class.java)
                return method.invoke(file, true, false) as Boolean
            } catch (e: Exception) {
                // Reflection also failed
            }

            false
        } catch (e: Exception) {
            false
        }
    }

    private fun isFileExecutable(path: String): Boolean {
        return try {
            val file = File(path)
            file.canExecute()
        } catch (e: Exception) {
            false
        }
    }

    private fun startDownloadService(
        downloadId: String,
        url: String,
        outputPath: String,
        format: String?,
        cookiesPath: String?,
        userAgent: String?,
        title: String?
    ) {
        val intent = Intent(this, DownloadService::class.java).apply {
            action = "START_DOWNLOAD"
            putExtra("downloadId", downloadId)
            putExtra("url", url)
            putExtra("outputPath", outputPath)
            putExtra("format", format)
            putExtra("cookiesPath", cookiesPath)
            putExtra("userAgent", userAgent)
            putExtra("title", title)
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
    }

    private fun stopDownloadService() {
        val intent = Intent(this, DownloadService::class.java).apply {
            action = "STOP_SERVICE"
        }
        stopService(intent)
    }

    private fun cancelDownloadInService(downloadId: String) {
        val intent = Intent(this, DownloadService::class.java).apply {
            action = "CANCEL_DOWNLOAD"
            putExtra("downloadId", downloadId)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
    }
}
