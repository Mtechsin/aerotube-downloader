package com.aerotube.youtube_downloader

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.util.Log
import androidx.core.app.NotificationCompat
import com.yausername.youtubedl_android.YoutubeDL
import com.yausername.youtubedl_android.YoutubeDLRequest
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import java.io.File
import java.util.concurrent.ConcurrentHashMap

class DownloadService : Service() {
    private val CHANNEL_ID = "download_service_channel"
    private val NOTIFICATION_ID = 1000

    private lateinit var notificationManager: NotificationManager
    private val activeDownloads = ConcurrentHashMap<String, DownloadTask>()
    private val mainHandler = Handler(Looper.getMainLooper())
    private var isForegroundStarted = false

    companion object {
        private const val TAG = "DownloadService"
    }

    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "DownloadService created")

        notificationManager = getSystemService(NotificationManager::class.java)
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d(TAG, "DownloadService started")

        // Handle the command from the Intent
        when (intent?.action) {
            "START_DOWNLOAD" -> {
                val downloadId = intent.getStringExtra("downloadId")
                val url = intent.getStringExtra("url")
                val outputPath = intent.getStringExtra("outputPath")
                val format = intent.getStringExtra("format")
                val cookiesPath = intent.getStringExtra("cookiesPath")
                val userAgent = intent.getStringExtra("userAgent")
                val title = intent.getStringExtra("title") ?: "Downloading..."

                if (downloadId != null && url != null && outputPath != null) {
                    startDownload(downloadId, url, outputPath, format, cookiesPath, userAgent, title)
                }
            }
            "CANCEL_DOWNLOAD" -> {
                val downloadId = intent.getStringExtra("downloadId")
                if (downloadId != null) {
                    cancelDownload(downloadId)
                }
            }
            "STOP_SERVICE" -> {
                stopSelf()
            }
        }

        // Create and start foreground notification if not already started
        if (!isForegroundStarted) {
            val notification = createForegroundNotification("Download service active", 0)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC)
            } else {
                startForeground(NOTIFICATION_ID, notification)
            }
            isForegroundStarted = true
        }

        return START_NOT_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? {
        return null // Not a bound service
    }

    override fun onDestroy() {
        super.onDestroy()
        Log.d(TAG, "DownloadService destroyed")

        // Cancel all active downloads
        activeDownloads.values.forEach { it.cancel() }
        activeDownloads.clear()

        // Cancel notification
        notificationManager.cancel(NOTIFICATION_ID)
        isForegroundStarted = false
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Download Service",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Shows download progress"
                setShowBadge(false)
                enableVibration(false)
                enableLights(false)
            }
            notificationManager.createNotificationChannel(channel)
        }
    }

    private fun createForegroundNotification(contentText: String, progress: Int): Notification {
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Active Downloads")
            .setContentText(contentText)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setProgress(100, progress, progress == 0 && activeDownloads.isNotEmpty())
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setShowWhen(false)
            .build()
    }



    private fun startDownload(
        downloadId: String,
        url: String,
        outputPath: String,
        format: String?,
        cookiesPath: String?,
        userAgent: String?,
        title: String
    ) {
        val task = DownloadTask(downloadId, url, outputPath, format, cookiesPath, userAgent, title)
        activeDownloads[downloadId] = task

        CoroutineScope(Dispatchers.IO).launch {
            task.execute { progress, status ->
                mainHandler.post {
                    updateDownloadProgress(downloadId, progress, status)
                    if (status == "Completed" || status.startsWith("Failed:")) {
                        completeDownload(downloadId)
                    }
                }
            }
        }

        updateNotification()
    }

    private fun cancelDownload(downloadId: String) {
        activeDownloads[downloadId]?.cancel()
        activeDownloads.remove(downloadId)
        updateNotification()
    }

    private fun updateDownloadProgress(downloadId: String, progress: Float, statusText: String?) {
        activeDownloads[downloadId]?.updateProgress(progress, statusText)
        updateNotification()
    }

    private fun completeDownload(downloadId: String) {
        activeDownloads.remove(downloadId)
        updateNotification()
    }

    private fun updateNotification() {
        if (activeDownloads.isEmpty()) {
            // Stop foreground if no active downloads
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                stopForeground(STOP_FOREGROUND_REMOVE)
            } else {
                stopForeground(true)
            }
            isForegroundStarted = false
            stopSelf()
            return
        }

        // Calculate overall progress
        val totalProgress = activeDownloads.values.map { it.progress }.average().toFloat()
        val activeCount = activeDownloads.size
        val contentText = if (activeCount == 1) {
            activeDownloads.values.first().statusText ?: "Downloading..."
        } else {
            "$activeCount downloads active"
        }

        val notification = createForegroundNotification(contentText, (totalProgress * 100).toInt())
        notificationManager.notify(NOTIFICATION_ID, notification)
    }

    // Inner class for handling individual download tasks
    inner class DownloadTask(
        val downloadId: String,
        val url: String,
        val outputPath: String,
        val format: String?,
        val cookiesPath: String?,
        val userAgent: String?,
        val title: String
    ) {
        var progress: Float = 0.0f
        var statusText: String = "Starting download..."
        var isCancelled = false

        fun execute(onProgress: (Float, String) -> Unit) {
            try {
                val request = YoutubeDLRequest(url)

                // Set output template
                request.addOption("-o", "$outputPath/%(title)s.%(ext)s")

                // Set format if provided
                if (!format.isNullOrEmpty()) {
                    request.addOption("-f", format)
                } else {
                    request.addOption("-f", "best")
                }

                // Add cookies if provided
                if (!cookiesPath.isNullOrEmpty()) {
                    val cookieFile = File(cookiesPath)
                    if (cookieFile.exists()) {
                        request.addOption("--cookies", cookiesPath)
                    }
                }

                // Add custom user agent if provided
                if (!userAgent.isNullOrEmpty()) {
                    request.addOption("--user-agent", userAgent)
                }

                // Reliability fixes
                request.addOption("--force-ipv4")
                request.addOption("--socket-timeout", "15")
                request.addOption("--retries", "3")

                // Use media endpoint for consistent format access
                request.addOption("--extractor-args", "youtube:player_client=media")

                // Ensure merging to MP4 container (required for bestvideo+bestaudio)
                request.addOption("--merge-output-format", "mp4")

// Execute download with progress callback
            YoutubeDL.getInstance().execute(request, downloadId) { progressValue, eta, line ->
                if (isCancelled) {
                    YoutubeDL.getInstance().destroyProcessById(downloadId)
                    return@execute
                }

                progress = progressValue / 100.0f // Convert to 0.0-1.0 range
                statusText = if (eta > 0) {
                    // Use the raw line as the status text, which contains progress info
                    line
                } else {
                    "Downloading..."
                }

                onProgress(progress, statusText)
            }

                if (!isCancelled) {
                    progress = 1.0f
                    statusText = "Completed"
                    onProgress(progress, statusText)
                }

            } catch (e: Exception) {
                Log.e(TAG, "Download failed for $downloadId", e)
                statusText = "Failed: ${e.message}"
                onProgress(progress, statusText)
            }
        }

        fun cancel() {
            isCancelled = true
            try {
                YoutubeDL.getInstance().destroyProcessById(downloadId)
            } catch (e: Exception) {
                Log.e(TAG, "Failed to cancel download $downloadId", e)
            }
        }

        fun updateProgress(newProgress: Float, newStatusText: String?) {
            progress = newProgress
            if (newStatusText != null) {
                statusText = newStatusText
            }
        }
    }
}
