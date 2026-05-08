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

        // Create and start foreground notification FIRST (required within 5 seconds)
        if (!isForegroundStarted) {
            val notification = createForegroundNotification("Download service active", 0)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC)
            } else {
                startForeground(NOTIFICATION_ID, notification)
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

        return START_NOT_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? {
        return null // Not a bound service
    }

    override fun onDestroy() {
        super.onDestroy()
        Log.d(TAG, "DownloadService destroyed")

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

    fun reportProgress(downloadId: String, progress: Float, statusText: String) {
        mainHandler.post {
            updateDownloadProgress(downloadId, progress, statusText)
            if (statusText == "Completed" || statusText.startsWith("Failed:")) {
                completeDownload(downloadId)
            }
        }
    }

    private fun cancelDownload(downloadId: String) {
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
