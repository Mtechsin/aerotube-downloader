package com.aerotube.youtube_downloader

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.util.Log
import androidx.core.app.NotificationCompat
import java.util.concurrent.ConcurrentHashMap
import kotlin.math.abs

/**
 * Pure notification-throttle decision (no Android types) so JVM unit tests
 * can cover the 1 Hz / 1-percentage-point policy without loading [DownloadService].
 *
 * Emit when:
 * - this is the first sample for the download,
 * - at least [minIntervalMs] has elapsed since the last emit (~1 Hz),
 * - progress jumped by at least [minDelta] (1 percentage point), or
 * - the download is complete (progress >= 1).
 */
internal fun shouldEmitProgressNotification(
    lastProgress: Float?,
    lastTimeMs: Long?,
    progress: Float,
    nowMs: Long,
    minIntervalMs: Long = 1000L,
    minDelta: Float = 0.01f,
): Boolean {
    if (lastProgress == null || lastTimeMs == null) return true
    if (progress >= 1f) return true
    if (nowMs - lastTimeMs >= minIntervalMs) return true
    return abs(progress - lastProgress) >= minDelta
}

/**
 * Foreground service owning notification ID 1000 and channel
 * "download_service_channel". Registers download metadata for the
 * notification; actual yt-dlp execution is owned by [YtDlpEngine].
 */
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
    // Per-download last emitted progress (0..1) + timestamp (ms) used to
    // throttle updateNotification() to ~1 Hz or 1 percentage-point jumps.
    private val lastNotify = ConcurrentHashMap<String, Pair<Float, Long>>()
    private var isForegroundStarted = false

    companion object {
        private const val TAG = "DownloadService"

        // Live reference so MainActivity / YtDlpEngine can forward high-frequency
        // progress without spawning an Intent per tick (background-start of
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

        when (intent?.action) {
            "START_DOWNLOAD" -> {
                val downloadId = intent.getStringExtra("downloadId")
                val url = intent.getStringExtra("url")
                val outputPath = intent.getStringExtra("outputPath")
                val format = intent.getStringExtra("format")
                val cookiesPath = intent.getStringExtra("cookiesPath")
                val userAgent = intent.getStringExtra("userAgent")
                val title = intent.getStringExtra("title") ?: "Downloading..."

                // Register metadata only. Execution is owned by YtDlpEngine,
                // kicked from MainActivity's downloadVideo handler after this
                // service is ensured running (FGS contract).
                if (downloadId != null && url != null && outputPath != null) {
                    registerDownload(downloadId, url, outputPath, format, cookiesPath, userAgent, title)
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
        return null // Started service; companion [instance] is the access path
    }

    override fun onDestroy() {
        super.onDestroy()
        Log.d(TAG, "DownloadService destroyed")
        instance = null

        // Cancel any engine jobs still registered for tracked downloads so
        // yt-dlp processes don't outlive the notification/tracking.
        for (downloadId in activeDownloads.keys.toList()) {
            try {
                YtDlpEngine.cancel(downloadId)
                Log.d(TAG, "Cancelled yt-dlp process $downloadId on service destroy")
            } catch (e: Exception) {
                Log.w(TAG, "Failed to cancel yt-dlp process $downloadId", e)
            }
        }
        activeDownloads.clear()
        lastNotify.clear()

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

    private fun registerDownload(
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

    /**
     * Engine (and Dart compatibility path) push real progress here so the
     * foreground notification reflects percentage without a Dart round-trip.
     *
     * yt-dlp stdout can tick far faster than the notification needs; throttle
     * [updateNotification] to ~1 Hz or a 1-percentage-point jump per download.
     * Completion is always emitted.
     */
    fun reportProgress(downloadId: String, progress: Float, statusText: String?) {
        val task = activeDownloads[downloadId]
        if (task == null) {
            Log.d(TAG, "reportProgress: unknown downloadId $downloadId, ignoring")
            return
        }
        val clamped = progress.coerceIn(0f, 1f)
        task.updateProgress(clamped, statusText)

        val now = System.currentTimeMillis()
        val last = lastNotify[downloadId]
        if (shouldEmitProgressNotification(
                lastProgress = last?.first,
                lastTimeMs = last?.second,
                progress = clamped,
                nowMs = now,
            )
        ) {
            lastNotify[downloadId] = clamped to now
            updateNotification()
        }
    }

    private fun cancelDownload(downloadId: String) {
        try {
            YtDlpEngine.cancel(downloadId)
        } catch (_: Exception) {
        }
        activeDownloads.remove(downloadId)
        lastNotify.remove(downloadId)
        // Force-refresh: cancel must tear the notification down even if a
        // progress tick was just suppressed by the throttle.
        updateNotification()
    }

    /**
     * Drop one task when its download finished (success, error, or cancel).
     * When the map empties, updateNotification() stops foreground + self.
     */
    fun completeDownload(downloadId: String) {
        activeDownloads.remove(downloadId)
        lastNotify.remove(downloadId)
        // Force-refresh on terminal transition regardless of throttle state.
        updateNotification()
    }

    private fun updateNotification() {
        if (activeDownloads.isEmpty()) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                stopForeground(STOP_FOREGROUND_REMOVE)
            } else {
                stopForeground(true)
            }
            isForegroundStarted = false
            stopSelf()
            return
        }

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

    /** Download metadata for the foreground notification. */
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
