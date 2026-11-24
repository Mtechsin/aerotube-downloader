package com.aerotube.youtube_downloader

import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.plugin.common.EventChannel

/**
 * Thread-safe pub/sub for yt-dlp download terminal/progress events.
 * DownloadService / YtDlpEngine emit without holding an EventChannel;
 * MainActivity registers the sink on EventChannel.onListen.
 */
object DownloadEventBus {
    private const val TAG = "DownloadEventBus"

    @Volatile
    private var sink: EventChannel.EventSink? = null

    private val mainHandler = Handler(Looper.getMainLooper())

    fun setSink(sink: EventChannel.EventSink?) {
        this.sink = sink
    }

    /** Posts to the main looper before delivering to the sink. */
    fun emit(event: Map<String, Any?>) {
        mainHandler.post {
            try {
                sink?.success(event)
            } catch (e: Exception) {
                Log.w(TAG, "Failed to emit download event", e)
            }
        }
    }
}
