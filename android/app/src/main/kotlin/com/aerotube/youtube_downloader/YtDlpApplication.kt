package com.aerotube.youtube_downloader

import android.app.Application
import android.util.Log
import com.yausername.ffmpeg.FFmpeg
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
        initializeFFmpeg()
    }

    private fun initializeYoutubeDL() {
        try {
            Log.d(TAG, "Initializing youtubedl-android library...")
            YoutubeDL.getInstance().init(applicationContext)
            Log.d(TAG, "YoutubeDL initialized successfully")
            Log.d(TAG, "yt-dlp version: ${YoutubeDL.getInstance().version(applicationContext)}")
            
            // Auto-update disabled - now handled manually from Settings
            // The manual update from Settings works more reliably
            Log.d(TAG, "Auto-update disabled - use Settings to update yt-dlp")
        } catch (e: Throwable) {
            Log.e(TAG, "Failed to initialize youtubedl-android", e)
        }
    }

    private fun initializeFFmpeg() {
        try {
            Log.d(TAG, "Initializing FFmpeg (bundled with youtubedl-android)...")
            FFmpeg.getInstance().init(applicationContext)
            Log.d(TAG, "FFmpeg initialized successfully")
        } catch (e: Throwable) {
            Log.e(TAG, "Failed to initialize FFmpeg - merging will not work", e)
        }
    }
    
    private fun updateYtDlpInBackground() {
        // Disabled - manual update from Settings now handles this
        Log.d(TAG, "Background update disabled")
    }
}
