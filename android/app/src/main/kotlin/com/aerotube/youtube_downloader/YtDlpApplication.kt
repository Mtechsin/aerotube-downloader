package com.aerotube.youtube_downloader

import android.app.Application
import android.util.Log
import com.yausername.youtubedl_android.YoutubeDL
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

class YtDlpApplication : Application() {
    companion object {
        private const val TAG = "YtDlpApplication"
    }

    override fun onCreate() {
        super.onCreate()
        initializeYoutubeDL()
    }

    private fun initializeYoutubeDL() {
        try {
            Log.d(TAG, "Initializing youtubedl-android library...")
            YoutubeDL.getInstance().init(applicationContext)
            Log.d(TAG, "YoutubeDL initialized successfully")
            Log.d(TAG, "yt-dlp version: ${YoutubeDL.getInstance().version(applicationContext)}")
            
            // CRITICAL: Update yt-dlp to latest stable version on startup
            // This ensures we have the latest format extraction capabilities
            updateYtDlpInBackground()
        } catch (e: Throwable) {
            Log.e(TAG, "Failed to initialize youtubedl-android", e)
        }
    }
    
    private fun updateYtDlpInBackground() {
        CoroutineScope(Dispatchers.IO).launch {
            try {
                Log.d(TAG, "Checking for yt-dlp updates...")
                val status = YoutubeDL.getInstance().updateYoutubeDL(
                    applicationContext,
                    YoutubeDL.UpdateChannel.STABLE
                )
                when (status?.name) {
                    "DONE", "SUCCESS" -> {
                        Log.d(TAG, "yt-dlp updated successfully!")
                        Log.d(TAG, "New version: ${YoutubeDL.getInstance().version(applicationContext)}")
                    }
                    "ALREADY_UP_TO_DATE" -> {
                        Log.d(TAG, "yt-dlp is already up to date")
                    }
                    else -> {
                        Log.w(TAG, "yt-dlp update status: ${status?.name}")
                    }
                }
            } catch (e: Throwable) {
                Log.e(TAG, "Failed to update yt-dlp", e)
            }
        }
    }
}
