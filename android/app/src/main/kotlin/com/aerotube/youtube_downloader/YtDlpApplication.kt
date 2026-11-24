package com.aerotube.youtube_downloader

import android.app.Application
import android.util.Log
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch

class YtDlpApplication : Application() {
    companion object {
        private const val TAG = "YtDlpApplication"
    }

    private val appScope = CoroutineScope(SupervisorJob() + Dispatchers.IO)

    override fun onCreate() {
        super.onCreate()
        // Init off the main thread so first-frame jank is not blocked by
        // unpacking yt-dlp / FFmpeg payloads. YtDlpEngine is the single
        // owner of YoutubeDL/FFmpeg init flags — never call the libraries
        // directly here (dual source of truth caused ready-flag desync).
        // YtDlpEngine.ensureInit remains the synchronous gate for
        // method-channel work.
        appScope.launch {
            try {
                Log.d(TAG, "Initializing youtubedl-android via YtDlpEngine...")
                YtDlpEngine.ensureInit(applicationContext)
                Log.d(TAG, "YtDlpEngine init complete (yt-dlp + ffmpeg flags set)")
                Log.d(TAG, "Auto-update disabled - use Settings to update yt-dlp")
            } catch (e: Throwable) {
                Log.e(TAG, "Failed to initialize youtubedl-android", e)
            }
        }
    }
}
