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
import java.util.concurrent.ConcurrentHashMap

class DownloadService : Service() {
    // B26: Sole owner of foreground notification ID 1000 and channel
    // "download_service_channel" via startForeground(). Dart
    // DownloadForegroundService uses distinct ID 1001 and delegates to
    // this service on Android to avoid ID collision and the system
    // "running in background" placeholder caused by cancel(1000).
    private val CHANNEL_ID = "download_service_channel"
    private val NOTIFICATION_ID = 1000

    private lateinit var notificationManager: NotificationManager
    private val activeDownloads = ConcurrentHashMap<String, DownloadTask>()
    private val mainHandler = Handler(Looper.getMainLooper())
    private var isForegroundStarted = false

    companion object {
        private const val TAG = "DownloadService"

        // Live reference so MainActivity can forward high-frequency Dart progress
        // events without spawning an Intent per tick (background-start of
        // startForegroundService would also be restricted while app is backgrounded).
        @Volatile
        var instance: DownloadService? = null
            private set
    }

    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "DownloadService created")
        instance = this

        notificationManager = getSystemService(NotificationManager::class.java)
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d(TAG, "DownloadService started")

        // Create and start foreground notification FIRST (required within 5 seconds)
        if (!isForegroundStarted) {
            val notification = createForegroundNotification("Download service active", 0)
            when {
                // API 35+: declare both types so FFmpeg post-processing
                // (merge/thumbnail embed) is covered by mediaProcessing and a
                // long playlist session is not bound solely by the dataSync
                // 6-hour cap.
                Build.VERSION.SDK_INT >= Build.VERSION_CODES.VANILLA_ICE_CREAM -> {
                    startForeground(
                        NOTIFICATION_ID,
                        notification,
                        ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC or
                            ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROCESSING
                    )
                }
                Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q -> {
                    startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC)
                }
                else -> startForeground(NOTIFICATION_ID, notification)
            }
            isForegroundStarted = true
        }

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

        // B17 fix: START_NOT_STICKY — do not redeliver last intent on process death.
        // Previously START_REDELIVER_INTENT re-added a DownloadTask that never completes
        // (progress path is Dart-side), leaving notification stuck at "Starting download…" forever.
        return START_NOT_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? {
        return null // Not a bound service
    }

    override fun onDestroy() {
        super.onDestroy()
        Log.d(TAG, "DownloadService destroyed")
        instance = null

        // B28 fix: cancel native yt-dlp work that lived in MainActivity threads.
        // Previously we only cleared the map -> downloads kept running with no notification/tracking.
        for ((downloadId, _) in activeDownloads) {
            try {
                YoutubeDL.getInstance().destroyProcessById(downloadId)
                Log.d(TAG, "Cancelled yt-dlp process $downloadId on service destroy")
            } catch (e: Exception) {
                Log.w(TAG, "Failed to cancel yt-dlp process $downloadId", e)
            }
        }
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
        activeDownloads[downloadId] = DownloadTask(downloadId, url, outputPath, format, cookiesPath, userAgent, title)
        updateNotification()
    }

    // R4: Real progress now flows from Dart (NativeYtdlpAndroid EventChannel ->
    // MobileDownloadProvider -> DownloadForegroundService) via MainActivity's
    // updateNotificationProgress method handler, which calls reportProgress()
    // on the live instance. Updates the tracked task and re-posts the
    // foreground notification with accurate percentage progress.
    fun reportProgress(downloadId: String, progress: Float, statusText: String?) {
        val task = activeDownloads[downloadId]
        if (task == null) {
            Log.d(TAG, "reportProgress: unknown downloadId $downloadId, ignoring")
            return
        }
        task.updateProgress(progress.coerceIn(0f, 1f), statusText)
        updateNotification()
    }

    private fun cancelDownload(downloadId: String) {
        // Also attempt to kill underlying yt-dlp native process (B28 defense)
        try { YoutubeDL.getInstance().destroyProcessById(downloadId) } catch (_: Exception) {}
        activeDownloads.remove(downloadId)
        updateNotification()
    }

    // R4: Dart signals a single download finished while others remain active —
    // drop just this task so the notification reflects the remaining ones.
    // When the map empties, updateNotification() stops foreground + self.
    fun completeDownload(downloadId: String) {
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
            val task = activeDownloads.values.first()
            "${task.statusText} • ${(task.progress * 100).toInt()}%"
        } else {
            "$activeCount downloads active"
        }

        val notification = createForegroundNotification(contentText, (totalProgress * 100).toInt())
        notificationManager.notify(NOTIFICATION_ID, notification)
    }

    // Inner class for tracking download metadata (execution handled by MainActivity via method channel)
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

        fun updateProgress(newProgress: Float, newStatusText: String?) {
            progress = newProgress
            if (newStatusText != null) {
                statusText = newStatusText
            }
        }
    }
}
