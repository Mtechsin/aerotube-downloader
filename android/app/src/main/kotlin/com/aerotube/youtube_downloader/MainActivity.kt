package com.aerotube.youtube_downloader

import android.app.DownloadManager
import android.content.ActivityNotFoundException
import android.content.ClipData
import android.content.ComponentName
import android.content.ContentValues
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import android.util.Log
import android.webkit.MimeTypeMap
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
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
    
    @Volatile
    private var youtubeDLInitialized = false
    @Volatile
    private var ffmpegReady = false

    // Battery-optimization request: holds the pending MethodChannel.Result
    // until the user responds to the system dialog.
    @Volatile
    private var pendingBatteryResult: MethodChannel.Result? = null

    // Install-unknown-apps request: holds the pending result until the user
    // returns from Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES.
    @Volatile
    private var pendingInstallPermissionResult: MethodChannel.Result? = null

    // Storage permission request: holds the pending result until the user
    // responds to a system dialog or returns from All-files-access settings.
    @Volatile
    private var pendingStorageResult: MethodChannel.Result? = null

    // True while the in-app rationale dialog is showing (or a runtime dialog
    // is pending). Prevents onResume from completing the request too early.
    @Volatile
    private var storageRequestUiActive = false

    companion object {
        private const val TAG = "MainActivity"
        private const val REQUEST_CODE_BATTERY_OPT = 7101
        private const val REQUEST_CODE_INSTALL_UNKNOWN = 7102
        private const val REQUEST_CODE_STORAGE = 7103
    }

    private fun isInstallPermissionGranted(): Boolean {
        return if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            true
        } else {
            try {
                packageManager.canRequestPackageInstalls()
            } catch (_: Throwable) {
                false
            }
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == REQUEST_CODE_BATTERY_OPT) {
            val pm = getSystemService(android.content.Context.POWER_SERVICE) as android.os.PowerManager
            val granted = pm.isIgnoringBatteryOptimizations(packageName)
            Log.d(TAG, "Battery optimization dialog returned, granted=$granted")
            pendingBatteryResult?.success(granted)
            pendingBatteryResult = null
        } else if (requestCode == REQUEST_CODE_INSTALL_UNKNOWN) {
            val granted = isInstallPermissionGranted()
            Log.d(TAG, "Install-unknown-apps settings returned, granted=$granted")
            try {
                pendingInstallPermissionResult?.success(granted)
            } catch (e: Throwable) {
                Log.w(TAG, "Failed to deliver install permission result", e)
            }
            pendingInstallPermissionResult = null
        } else if (requestCode == REQUEST_CODE_STORAGE) {
            // Some OEMs return via onActivityResult for All-files-access settings.
            storageRequestUiActive = false
            deliverPendingStorageResult()
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != REQUEST_CODE_STORAGE) return
        storageRequestUiActive = false
        val granted = grantResults.isNotEmpty() &&
            grantResults.all { it == PackageManager.PERMISSION_GRANTED }
        Log.d(TAG, "Runtime storage permissions result: granted=$granted")

        val canWrite = canWritePublicDownloads()
        if (granted && canWrite) {
            try {
                pendingStorageResult?.success(true)
            } catch (e: Throwable) {
                Log.w(TAG, "Failed to deliver storage permission result", e)
            }
            pendingStorageResult = null
            return
        }

        if (granted && Build.VERSION.SDK_INT >= Build.VERSION_CODES.R && pendingStorageResult != null) {
            // Media permissions granted but public Downloads still blocked.
            // Escalate to All-files-access for raw yt-dlp path writes.
            Log.d(TAG, "Media granted but public Downloads blocked; opening All files access")
            openAllFilesAccessSettings()
            return
        }

        try {
            pendingStorageResult?.success(granted || canWrite)
        } catch (e: Throwable) {
            Log.w(TAG, "Failed to deliver storage permission result", e)
        }
        pendingStorageResult = null
    }

    private fun isExternalStorageManagerGranted(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            try {
                android.os.Environment.isExternalStorageManager()
            } catch (_: Throwable) {
                false
            }
        } else {
            true
        }
    }

    private fun hasLegacyStoragePermission(): Boolean {
        return ContextCompat.checkSelfPermission(
            this,
            android.Manifest.permission.WRITE_EXTERNAL_STORAGE
        ) == PackageManager.PERMISSION_GRANTED
    }

    private fun hasMediaPermissions(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return true
        val video = ContextCompat.checkSelfPermission(
            this,
            android.Manifest.permission.READ_MEDIA_VIDEO
        ) == PackageManager.PERMISSION_GRANTED
        val audio = ContextCompat.checkSelfPermission(
            this,
            android.Manifest.permission.READ_MEDIA_AUDIO
        ) == PackageManager.PERMISSION_GRANTED
        val images = ContextCompat.checkSelfPermission(
            this,
            android.Manifest.permission.READ_MEDIA_IMAGES
        ) == PackageManager.PERMISSION_GRANTED
        return video || audio || images
    }

    private fun canWritePublicDownloads(): Boolean {
        return try {
            val publicDir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
            val aeroTubeDir = File(publicDir, "AeroTube")
            if (!aeroTubeDir.exists()) {
                aeroTubeDir.mkdirs()
            }
            if (!aeroTubeDir.exists()) return false
            val probe = File(aeroTubeDir, ".probe_${System.currentTimeMillis()}")
            val created = try {
                probe.createNewFile()
            } catch (_: Throwable) {
                false
            }
            if (created) {
                probe.delete()
                true
            } else {
                aeroTubeDir.canWrite()
            }
        } catch (_: Throwable) {
            false
        }
    }

    private fun resolveStorageAccessNow(): Boolean {
        if (canWritePublicDownloads()) return true
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            return isExternalStorageManagerGranted() || hasMediaPermissions()
        }
        return hasLegacyStoragePermission()
    }

    private fun deliverPendingStorageResult() {
        val result = pendingStorageResult ?: return
        val granted = resolveStorageAccessNow()
        Log.d(TAG, "Storage settings returned, granted=$granted")
        try {
            result.success(granted)
        } catch (e: Throwable) {
            Log.w(TAG, "Failed to deliver storage permission result", e)
        }
        pendingStorageResult = null
    }

    private fun openAllFilesAccessSettings() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            try {
                val uri = Uri.parse("package:$packageName")
                val intent = Intent(
                    android.provider.Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION,
                    uri
                ).apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                startActivity(intent)
                return
            } catch (e: Exception) {
                Log.w(TAG, "Per-app all-files-access page unavailable", e)
            }
            try {
                val intent = Intent(
                    android.provider.Settings.ACTION_MANAGE_ALL_FILES_ACCESS_PERMISSION
                ).apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                startActivity(intent)
                return
            } catch (e: Exception) {
                Log.w(TAG, "All-files-access list page unavailable", e)
            }
        }
        try {
            val uri = Uri.parse("package:$packageName")
            val intent = Intent(
                android.provider.Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                uri
            ).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            startActivity(intent)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to open any storage settings page", e)
        }
    }

    private fun requestRuntimePermissions(permissions: Array<String>) {
        ActivityCompat.requestPermissions(this, permissions, REQUEST_CODE_STORAGE)
    }

    private fun showStorageRationaleThen(onContinue: () -> Unit, onSkip: () -> Unit) {
        try {
            val builder = android.app.AlertDialog.Builder(this)
                .setTitle("Storage access")
                .setMessage(
                    "AeroTube needs access to save downloads to the public Downloads/AeroTube folder.\n\n" +
                        "• Android 13+: allow Photos and videos / Music and audio\n" +
                        "• Android 11–12: enable “All files access” for AeroTube\n" +
                        "• Older Android: allow file storage\n\n" +
                        "You can change this later in Settings."
                )
                .setCancelable(false)
                .setPositiveButton("Continue") { dialog, _ ->
                    dialog.dismiss()
                    onContinue()
                }
                .setNegativeButton("Not now") { dialog, _ ->
                    dialog.dismiss()
                    onSkip()
                }
            if (!isFinishing && !isDestroyed) {
                builder.show()
                return
            }
        } catch (e: Exception) {
            Log.w(TAG, "Storage rationale dialog failed, proceeding directly", e)
        }
        onContinue()
    }

    private fun startStoragePermissionFlow(result: MethodChannel.Result) {
        if (pendingStorageResult != null) {
            try {
                result.error("STORAGE_REQUEST_IN_PROGRESS", "A storage permission request is already running", null)
            } catch (_: Throwable) {}
            return
        }

        if (canWritePublicDownloads()) {
            result.success(true)
            return
        }

        pendingStorageResult = result
        storageRequestUiActive = true

        showStorageRationaleThen(
            onContinue = {
                try {
                    when {
                        Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU -> {
                            // Android 13+: real system permission dialogs for media access.
                            // If media is already granted but Downloads still blocked,
                            // escalate to All-files-access for raw yt-dlp path writes.
                            val needed = mutableListOf<String>()
                            if (ContextCompat.checkSelfPermission(this, android.Manifest.permission.READ_MEDIA_VIDEO)
                                != PackageManager.PERMISSION_GRANTED
                            ) {
                                needed.add(android.Manifest.permission.READ_MEDIA_VIDEO)
                            }
                            if (ContextCompat.checkSelfPermission(this, android.Manifest.permission.READ_MEDIA_AUDIO)
                                != PackageManager.PERMISSION_GRANTED
                            ) {
                                needed.add(android.Manifest.permission.READ_MEDIA_AUDIO)
                            }
                            if (needed.isEmpty()) {
                                storageRequestUiActive = false
                                openAllFilesAccessSettings()
                            } else {
                                requestRuntimePermissions(needed.toTypedArray())
                            }
                        }
                        Build.VERSION.SDK_INT >= Build.VERSION_CODES.R -> {
                            // Android 11/12: All files access (Settings page, not a dialog).
                            storageRequestUiActive = false
                            openAllFilesAccessSettings()
                        }
                        else -> {
                            // Android 10 and below: classic WRITE/READ_EXTERNAL_STORAGE dialogs.
                            val needed = mutableListOf<String>()
                            if (ContextCompat.checkSelfPermission(this, android.Manifest.permission.WRITE_EXTERNAL_STORAGE)
                                != PackageManager.PERMISSION_GRANTED
                            ) {
                                needed.add(android.Manifest.permission.WRITE_EXTERNAL_STORAGE)
                            }
                            if (ContextCompat.checkSelfPermission(this, android.Manifest.permission.READ_EXTERNAL_STORAGE)
                                != PackageManager.PERMISSION_GRANTED
                            ) {
                                needed.add(android.Manifest.permission.READ_EXTERNAL_STORAGE)
                            }
                            if (needed.isEmpty()) {
                                storageRequestUiActive = false
                                deliverPendingStorageResult()
                            } else {
                                requestRuntimePermissions(needed.toTypedArray())
                            }
                        }
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "startStoragePermissionFlow failed", e)
                    storageRequestUiActive = false
                    pendingStorageResult = null
                    try {
                        result.error("STORAGE_PERMISSION_ERROR", e.message, null)
                    } catch (_: Throwable) {}
                }
            },
            onSkip = {
                storageRequestUiActive = false
                try {
                    result.success(canWritePublicDownloads())
                } catch (e: Throwable) {
                    Log.w(TAG, "Failed to deliver skipped storage result", e)
                }
                pendingStorageResult = null
            }
        )
    }

    private fun getShareableContentUri(file: File): Uri {
        val authority = "${applicationContext.packageName}.fileprovider"
        try {
            return FileProvider.getUriForFile(applicationContext, authority, file)
        } catch (e: Exception) {
            Log.w(TAG, "FileProvider failed for ${file.absolutePath}, trying MediaStore", e)
        }

        // Public Downloads files: resolve via MediaStore DATA column.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            try {
                val collection = MediaStore.Files.getContentUri("external")
                val projection = arrayOf(MediaStore.Files.FileColumns._ID)
                val selection = "${MediaStore.Files.FileColumns.DATA}=?"
                val args = arrayOf(file.absolutePath)
                contentResolver.query(collection, projection, selection, args, null)?.use { cursor ->
                    if (cursor.moveToFirst()) {
                        val id = cursor.getLong(0)
                        return android.content.ContentUris.withAppendedId(collection, id)
                    }
                }
            } catch (e: Exception) {
                Log.w(TAG, "MediaStore lookup failed for ${file.absolutePath}", e)
            }
        }

        // Last resort: copy into cache and share from FileProvider cache.
        val cacheCopy = File(cacheDir, "share_${System.currentTimeMillis()}_${file.name}")
        file.copyTo(cacheCopy, overwrite = true)
        return FileProvider.getUriForFile(applicationContext, authority, cacheCopy)
    }

    private fun publishFileToMediaStoreDownloads(sourcePath: String, displayName: String, mimeType: String?): Boolean {
        val source = File(sourcePath)
        if (!source.exists() || !source.isFile) return false

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            return try {
                val resolver = contentResolver
                val relativePath = Environment.DIRECTORY_DOWNLOADS + "/AeroTube"
                val values = ContentValues().apply {
                    put(MediaStore.Downloads.DISPLAY_NAME, displayName)
                    put(MediaStore.Downloads.MIME_TYPE, mimeType ?: MimeTypeMap.getSingleton()
                        .getMimeTypeFromExtension(displayName.substringAfterLast('.', "").lowercase())
                        ?: "application/octet-stream")
                    put(MediaStore.Downloads.RELATIVE_PATH, relativePath)
                    put(MediaStore.Downloads.IS_PENDING, 1)
                }
                val collection = MediaStore.Downloads.EXTERNAL_CONTENT_URI
                val uri = resolver.insert(collection, values) ?: return false
                resolver.openOutputStream(uri)?.use { out ->
                    source.inputStream().use { input ->
                        input.copyTo(out)
                    }
                } ?: return false
                values.clear()
                values.put(MediaStore.Downloads.IS_PENDING, 0)
                resolver.update(uri, values, null, null)
                Log.d(TAG, "Published $displayName to MediaStore Downloads: $uri")
                true
            } catch (e: Exception) {
                Log.e(TAG, "MediaStore publish failed for $sourcePath", e)
                false
            }
        }

        return try {
            val publicDir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
            val aeroTubeDir = File(publicDir, "AeroTube")
            if (!aeroTubeDir.exists()) aeroTubeDir.mkdirs()
            val dest = File(aeroTubeDir, displayName)
            source.copyTo(dest, overwrite = true)
            android.media.MediaScannerConnection.scanFile(
                this,
                arrayOf(dest.absolutePath),
                null,
                null
            )
            true
        } catch (e: Exception) {
            Log.e(TAG, "Legacy copy-to-Downloads failed for $sourcePath", e)
            false
        }
    }

    override fun onResume() {
        super.onResume()
        // Fallback flow: the user was sent to the battery-optimization list
        // page via a plain startActivity, so onActivityResult never fires.
        // Resolve the pending request here when they come back. For the
        // direct-dialog flow the result is already cleared in
        // onActivityResult before onResume runs, so this is a no-op there.
        pendingBatteryResult?.let { result ->
            val pm = getSystemService(android.content.Context.POWER_SERVICE) as android.os.PowerManager
            val granted = pm.isIgnoringBatteryOptimizations(packageName)
            Log.d(TAG, "Battery settings page closed, granted=$granted")
            try {
                result.success(granted)
            } catch (e: Throwable) {
                Log.w(TAG, "Failed to deliver battery result", e)
            }
            pendingBatteryResult = null
        }
        // Same fallback for install-unknown-apps: the settings page is a
        // plain startActivity on many OEMs, so deliver the current state here.
        pendingInstallPermissionResult?.let { result ->
            val granted = isInstallPermissionGranted()
            Log.d(TAG, "Install settings page closed, granted=$granted")
            try {
                result.success(granted)
            } catch (e: Throwable) {
                Log.w(TAG, "Failed to deliver install permission result", e)
            }
            pendingInstallPermissionResult = null
        }
        // All-files-access / storage settings: deliver when the user returns.
        // Skip while a dialog / runtime permission UI is still in flight.
        if (pendingStorageResult != null && !storageRequestUiActive) {
            deliverPendingStorageResult()
        }
    }

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
                "isExternalStorageManager" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                        result.success(android.os.Environment.isExternalStorageManager())
                    } else {
                        result.success(true)
                    }
                }
                "openManageStorageSettings" -> {
                    try {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                            val uri = Uri.parse("package:${applicationContext.packageName}")
                            val intent = Intent(android.provider.Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION, uri).apply {
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            context.startActivity(intent)
                            result.success(true)
                        } else {
                            val uri = Uri.parse("package:${applicationContext.packageName}")
                            val intent = Intent(android.provider.Settings.ACTION_APPLICATION_DETAILS_SETTINGS, uri).apply {
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            context.startActivity(intent)
                            result.success(true)
                        }
                    } catch (e: Exception) {
                        try {
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                                val intent = Intent(android.provider.Settings.ACTION_MANAGE_ALL_FILES_ACCESS_PERMISSION).apply {
                                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                }
                                context.startActivity(intent)
                                result.success(true)
                            } else {
                                result.success(false)
                            }
                        } catch (e2: Exception) {
                            Log.e(TAG, "Failed to open storage settings", e2)
                            result.success(false)
                        }
                    }
                }
                "requestStoragePermission" -> {
                    startStoragePermissionFlow(result)
                }
                "canWritePublicDownloads" -> {
                    result.success(canWritePublicDownloads())
                }
                "hasStorageAccess" -> {
                    result.success(resolveStorageAccessNow())
                }
                "getAppSpecificDownloadDir" -> {
                    try {
                        val dir = context.getExternalFilesDir(Environment.DIRECTORY_DOWNLOADS)
                            ?: context.filesDir
                        result.success(dir.absolutePath)
                    } catch (e: Exception) {
                        Log.e(TAG, "getAppSpecificDownloadDir failed", e)
                        result.success(context.filesDir.absolutePath)
                    }
                }
                "publishToMediaStoreDownloads" -> {
                    val sourcePath = call.argument<String>("sourcePath")
                    val displayName = call.argument<String>("displayName")
                    if (sourcePath.isNullOrEmpty() || displayName.isNullOrEmpty()) {
                        result.error("INVALID_ARGUMENT", "sourcePath and displayName are required", null)
                        return@setMethodCallHandler
                    }
                    val mimeType = call.argument<String>("mimeType")
                    Thread {
                        val ok = publishFileToMediaStoreDownloads(sourcePath, displayName, mimeType)
                        runOnUiThread {
                            try {
                                result.success(ok)
                            } catch (e: Throwable) {
                                Log.w(TAG, "Failed to deliver MediaStore publish result", e)
                            }
                        }
                    }.start()
                }
                "getExternalDownloadDir" -> {
                    try {
                        val publicDir = android.os.Environment.getExternalStoragePublicDirectory(
                            android.os.Environment.DIRECTORY_DOWNLOADS
                        )
                        val aeroTubeDir = File(publicDir, "AeroTube")
                        var canWrite = false
                        try {
                            if (!aeroTubeDir.exists()) {
                                aeroTubeDir.mkdirs()
                            }
                            val testFile = File(aeroTubeDir, ".probe_${System.currentTimeMillis()}")
                            if (testFile.createNewFile()) {
                                testFile.delete()
                                canWrite = true
                            }
                        } catch (_: Throwable) {
                            canWrite = false
                        }

                        val targetDir = if (canWrite) {
                            aeroTubeDir
                        } else {
                            val fallback = context.getExternalFilesDir(android.os.Environment.DIRECTORY_DOWNLOADS)
                            fallback ?: aeroTubeDir
                        }
                        result.success(targetDir.absolutePath)
                    } catch (e: Exception) {
                        Log.e(TAG, "getExternalDownloadDir failed", e)
                        val fallback = context.getExternalFilesDir(android.os.Environment.DIRECTORY_DOWNLOADS)
                        result.success(fallback?.absolutePath)
                    }
                }
                "getApiLevel" -> {
                    result.success(Build.VERSION.SDK_INT)
                }
                "getFreeSpace" -> {
                    val path = call.argument<String>("path")
                    try {
                        val target = if (!path.isNullOrEmpty()) {
                            File(path)
                        } else {
                            val publicDir = android.os.Environment.getExternalStoragePublicDirectory(
                                android.os.Environment.DIRECTORY_DOWNLOADS
                            )
                            val aeroTubeDir = File(publicDir, "AeroTube")
                            if (aeroTubeDir.exists() && aeroTubeDir.canWrite()) {
                                aeroTubeDir
                            } else if (publicDir != null && publicDir.exists()) {
                                publicDir
                            } else {
                                context.getExternalFilesDir(android.os.Environment.DIRECTORY_DOWNLOADS) ?: File("/")
                            }
                        }
                        // Walk up to nearest existing directory
                        var dir: File? = target
                        while (dir != null && !dir.exists()) {
                            dir = dir.parentFile
                        }
                        val free = dir?.freeSpace ?: target.freeSpace
                        // Also try usableSpace (accounts for quota)
                        val usable = dir?.usableSpace ?: target.usableSpace
                        // Return the smaller (more conservative)
                        val available = minOf(free, usable)
                        result.success(available)
                    } catch (e: Exception) {
                        Log.e(TAG, "getFreeSpace failed for $path", e)
                        result.error("FREE_SPACE_ERROR", e.message, null)
                    }
                }
                "scanMediaFile" -> {
                    val filePath = call.argument<String>("filePath") ?: call.argument<String>("path")
                    if (filePath.isNullOrEmpty()) {
                        result.error("INVALID_ARGUMENT", "filePath is required", null)
                        return@setMethodCallHandler
                    }
                    try {
                        android.media.MediaScannerConnection.scanFile(
                            context,
                            arrayOf(filePath),
                            null
                        ) { path, uri ->
                            Log.d(TAG, "MediaScannerConnection scanned: $path -> $uri")
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        Log.e(TAG, "MediaScannerConnection failed for $filePath", e)
                        result.error("SCAN_ERROR", e.message, null)
                    }
                }
                "isIgnoringBatteryOptimizations" -> {
                    try {
                        val pm = getSystemService(android.content.Context.POWER_SERVICE) as android.os.PowerManager
                        result.success(pm.isIgnoringBatteryOptimizations(packageName))
                    } catch (e: Exception) {
                        Log.e(TAG, "isIgnoringBatteryOptimizations failed", e)
                        result.success(false)
                    }
                }
                "requestIgnoreBatteryOptimizations" -> {
                    try {
                        val pm = getSystemService(android.content.Context.POWER_SERVICE) as android.os.PowerManager
                        if (pm.isIgnoringBatteryOptimizations(packageName)) {
                            result.success(true)
                            return@setMethodCallHandler
                        }
                        // Deliver the result only after the user responds.
                        // Either onActivityResult (direct dialog) or onResume
                        // (fallback list page) completes it.
                        pendingBatteryResult = result
                        try {
                            val intent = Intent(android.provider.Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                                data = Uri.parse("package:$packageName")
                            }
                            @Suppress("DEPRECATION")
                            startActivityForResult(intent, REQUEST_CODE_BATTERY_OPT)
                        } catch (e: Exception) {
                            // OEM skins (Samsung, Xiaomi, ...) may reject the
                            // direct-request dialog. Fall back to the list
                            // page where the user can find the app manually;
                            // the result is delivered from onResume.
                            Log.w(TAG, "Direct battery dialog unavailable, opening settings list", e)
                            startActivity(Intent(android.provider.Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS))
                        }
                    } catch (e: Exception) {
                        Log.e(TAG, "requestIgnoreBatteryOptimizations failed", e)
                        pendingBatteryResult = null
                        result.error("BATTERY_OPT_ERROR", e.message, null)
                    }
                }
                "openBatteryOptimizationSettings" -> {
                    result.success(try {
                        startActivity(Intent(android.provider.Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS))
                        true
                    } catch (e: Exception) {
                        Log.e(TAG, "openBatteryOptimizationSettings failed", e)
                        false
                    })
                }
                "getDeviceManufacturer" -> {
                    result.success(Build.MANUFACTURER)
                }
                "openOemAutostartSettings" -> {
                    val manufacturer = Build.MANUFACTURER.lowercase()
                    val intent = when {
                        manufacturer.contains("xiaomi") || manufacturer.contains("redmi") || manufacturer.contains("poco") -> {
                            Intent().apply {
                                component = ComponentName(
                                    "com.miui.securitycenter",
                                    "com.miui.permcenter.autostart.AutoStartManagementActivity"
                                )
                            }
                        }
                        manufacturer.contains("oppo") || manufacturer.contains("realme") || manufacturer.contains("oneplus") -> {
                            Intent().apply {
                                component = ComponentName(
                                    "com.coloros.safecenter",
                                    "com.coloros.safecenter.permission.startup.StartupAppListActivity"
                                )
                            }
                        }
                        manufacturer.contains("vivo") || manufacturer.contains("iqoo") -> {
                            Intent().apply {
                                component = ComponentName(
                                    "com.vivo.permissionmanager",
                                    "com.vivo.permissionmanager.activity.BgStartUpManagerActivity"
                                )
                            }
                        }
                        manufacturer.contains("huawei") || manufacturer.contains("honor") -> {
                            Intent().apply {
                                component = ComponentName(
                                    "com.huawei.systemmanager",
                                    "com.huawei.systemmanager.optimize.process.ProtectActivity"
                                )
                            }
                        }
                        else -> null
                    }
                    var launched = false
                    if (intent != null) {
                        try {
                            if (intent.resolveActivity(packageManager) != null) {
                                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                startActivity(intent)
                                launched = true
                            }
                        } catch (e: Exception) {
                            Log.w(TAG, "Failed to launch OEM autostart activity: ${e.message}")
                        }
                    }
                    if (!launched) {
                        // Fallback: Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS or ACTION_APPLICATION_DETAILS_SETTINGS
                        try {
                            val appDetails = Intent(android.provider.Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                                data = Uri.parse("package:$packageName")
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            startActivity(appDetails)
                            launched = true
                        } catch (e: Exception) {
                            try {
                                val battOpt = Intent(android.provider.Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS).apply {
                                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                }
                                startActivity(battOpt)
                                launched = true
                            } catch (e2: Exception) {
                                Log.e(TAG, "Failed to launch fallback settings: ${e2.message}")
                            }
                        }
                    }
                    result.success(launched)
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
                "updateNotificationProgress" -> {
                    // R4: Dart-side real progress -> native foreground notification.
                    val downloadId = call.argument<String>("downloadId")
                    val progress = call.argument<Double>("progress")
                    val statusText = call.argument<String>("statusText")
                    if (downloadId == null || progress == null) {
                        result.error("INVALID_ARGUMENT", "downloadId and progress are required", null)
                        return@setMethodCallHandler
                    }
                    DownloadService.instance?.reportProgress(downloadId, progress.toFloat(), statusText)
                        ?: Log.w(TAG, "updateNotificationProgress: DownloadService not running")
                    result.success(true)
                }
                "completeDownloadInService" -> {
                    val downloadId = call.argument<String>("downloadId")
                    if (downloadId == null) {
                        result.error("INVALID_ARGUMENT", "downloadId is required", null)
                        return@setMethodCallHandler
                    }
                    DownloadService.instance?.completeDownload(downloadId)
                        ?: Log.w(TAG, "completeDownloadInService: DownloadService not running")
                    result.success(true)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }

        // youtubedl-android channel
        // B24 fix: ensure MethodChannel result is always delivered even if Activity is
        // destroyed before the background Thread finishes. Use main looper + safe wrappers
        // so Dart Futures don't hang forever (which previously left UI stuck on "Preparing...").
        // Dart side also adds .timeout() as defense-in-depth.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, YTDLP_CHANNEL).setMethodCallHandler { call, result ->
            Thread {
                val mainHandler = android.os.Handler(android.os.Looper.getMainLooper())
                fun safeSuccess(value: Any?) {
                    mainHandler.post {
                        try { result.success(value) } catch (e: Throwable) {
                            Log.w(TAG, "safeSuccess failed (activity detached or reply already submitted)", e)
                        }
                    }
                }
                fun safeError(code: String, msg: String?, details: Any?) {
                    mainHandler.post {
                        try { result.error(code, msg, details) } catch (e: Throwable) {
                            Log.w(TAG, "safeError failed (activity detached or reply already submitted)", e)
                        }
                    }
                }
                fun safeNotImplemented() {
                    mainHandler.post {
                        try { result.notImplemented() } catch (e: Throwable) {
                            Log.w(TAG, "safeNotImplemented failed", e)
                        }
                    }
                }
                try {
                    when (call.method) {
                        "getVersion" -> {
                            val version = getVersion()
                            safeSuccess(version)
                        }
                        "getVideoInfo" -> {
                            val url = call.argument<String>("url")
                            val cookiesPath = call.argument<String>("cookies_path")
                            val userAgent = call.argument<String>("user_agent")

                            if (url == null) {
                                safeError("INVALID_ARGUMENT", "URL is required", null)
                                return@Thread
                            }

                            val infoJson = getVideoInfo(url, cookiesPath, userAgent)
                            safeSuccess(infoJson)
                        }
                        "getPlaylistInfo" -> {
                            val url = call.argument<String>("url")
                            val cookiesPath = call.argument<String>("cookies_path")
                            val userAgent = call.argument<String>("user_agent")

                            if (url == null) {
                                safeError("INVALID_ARGUMENT", "URL is required", null)
                                return@Thread
                            }

                            val playlistJson = getPlaylistInfo(url, cookiesPath, userAgent)
                            safeSuccess(playlistJson)
                        }
                        "downloadVideo" -> {
                            val url = call.argument<String>("url")
                            val outputPath = call.argument<String>("output_path")
                            val format = call.argument<String>("format")
                            val cookiesPath = call.argument<String>("cookies_path")
                            val userAgent = call.argument<String>("user_agent")
                            val processId = call.argument<String>("process_id")
                            val archivePath = call.argument<String>("archive_path")
                            val subtitleLanguages = call.argument<List<String>>("subtitle_languages")
                            val embedSubtitles = call.argument<Boolean>("embed_subtitles") ?: false
                            val sponsorBlock = call.argument<Boolean>("sponsor_block") ?: false
                            val embedThumbnail = call.argument<Boolean>("embed_thumbnail") ?: true
                            val embedMetadata = call.argument<Boolean>("embed_metadata") ?: true

                            if (url == null || outputPath == null) {
                                safeError("INVALID_ARGUMENT", "URL and output_path are required", null)
                                return@Thread
                            }

                            val id = processId ?: "download_${System.currentTimeMillis()}"
                            val downloadResult = downloadVideo(
                                url,
                                outputPath,
                                format,
                                cookiesPath,
                                userAgent,
                                id,
                                archivePath,
                                subtitleLanguages,
                                embedSubtitles,
                                sponsorBlock,
                                embedThumbnail,
                                embedMetadata
                            )
                            safeSuccess(downloadResult)
                        }
                        "cancelDownload" -> {
                            val processId = call.argument<String>("process_id")
                            if (processId == null) {
                                safeError("INVALID_ARGUMENT", "process_id is required", null)
                                return@Thread
                            }
                            val success = cancelDownload(processId)
                            safeSuccess(success)
                        }
                        "updateYoutubeDL" -> {
                            val updateChannel = call.argument<String>("update_channel") ?: "stable"
                            val updateResult = updateYoutubeDL(updateChannel)
                            safeSuccess(updateResult)
                        }
                        else -> {
                            safeNotImplemented()
                        }
                    }
                } catch (e: Throwable) {
                    Log.e(TAG, "Error handling method call", e)
                    safeError("YTDLP_ERROR", e.message, e.stackTraceToString())
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
                        val contentUri = getShareableContentUri(file)
                        Log.d(TAG, "Shareable URI: $contentUri")
                        result.success(contentUri.toString())
                    } catch (e: Exception) {
                        Log.e(TAG, "getShareableContentUri failed", e)
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
                        // Pre-flight: on Android 8+ the system silently drops the
                        // install intent when "Install unknown apps" is off for
                        // this package. Fail fast so Dart can route to Settings.
                        if (!isInstallPermissionGranted()) {
                            Log.w(TAG, "installApk blocked: unknown-apps permission not granted")
                            result.error(
                                "INSTALL_PERMISSION_DENIED",
                                "Enable \"Install unknown apps\" for AeroTube in system settings, then retry.",
                                null
                            )
                            return@setMethodCallHandler
                        }
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
                            addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
                        }
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        Log.e(TAG, "installApk failed", e)
                        result.error("INSTALL_ERROR", e.message, e.stackTraceToString())
                    }
                }
                "canRequestPackageInstalls" -> {
                    try {
                        result.success(isInstallPermissionGranted())
                    } catch (e: Exception) {
                        Log.e(TAG, "canRequestPackageInstalls failed", e)
                        result.error("INSTALL_CHECK_ERROR", e.message, null)
                    }
                }
                "requestInstallPermission" -> {
                    try {
                        if (isInstallPermissionGranted()) {
                            result.success(true)
                            return@setMethodCallHandler
                        }
                        // Deliver asynchronously via onActivityResult/onResume.
                        pendingInstallPermissionResult = result
                        try {
                            val intent = Intent(
                                android.provider.Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES
                            ).apply {
                                data = Uri.parse("package:$packageName")
                            }
                            @Suppress("DEPRECATION")
                            startActivityForResult(intent, REQUEST_CODE_INSTALL_UNKNOWN)
                        } catch (e: Exception) {
                            Log.w(TAG, "Direct unknown-apps settings unavailable, opening generic page", e)
                            try {
                                startActivity(
                                    Intent(android.provider.Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES)
                                )
                            } catch (e2: Exception) {
                                Log.e(TAG, "openInstallSettings failed", e2)
                                pendingInstallPermissionResult = null
                                result.error("INSTALL_SETTINGS_ERROR", e2.message, null)
                            }
                        }
                    } catch (e: Exception) {
                        Log.e(TAG, "requestInstallPermission failed", e)
                        pendingInstallPermissionResult = null
                        result.error("INSTALL_SETTINGS_ERROR", e.message, null)
                    }
                }
                "openInstallSettings" -> {
                    try {
                        try {
                            val intent = Intent(
                                android.provider.Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES
                            ).apply {
                                data = Uri.parse("package:$packageName")
                            }
                            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            startActivity(intent)
                        } catch (_: Exception) {
                            val fallback = Intent(
                                android.provider.Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES
                            )
                            fallback.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            startActivity(fallback)
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        Log.e(TAG, "openInstallSettings failed", e)
                        result.error("INSTALL_SETTINGS_ERROR", e.message, null)
                    }
                }
                "getDeviceAbi" -> {
                    val primaryAbi = Build.SUPPORTED_ABIS.firstOrNull() ?: ""
                    result.success(primaryAbi)
                }
                "openFile" -> {
                    val filePath = if (call.arguments is Map<*, *>) call.argument<String>("filePath") else call.arguments as? String
                    val useChooser = if (call.arguments is Map<*, *>) (call.argument<Boolean>("useChooser") ?: false) else false

                    if (filePath.isNullOrEmpty()) {
                        result.error("INVALID_ARGUMENT", "filePath is required", null)
                        return@setMethodCallHandler
                    }

                    try {
                        val file = File(filePath)
                        if (!file.exists()) {
                            result.error("FILE_NOT_FOUND", "File does not exist: $filePath", null)
                            return@setMethodCallHandler
                        }

                        val mimeType = resolveMimeType(file)
                        val contentUri = getShareableContentUri(file)

                        val intent = Intent(Intent.ACTION_VIEW).apply {
                            setDataAndType(contentUri, mimeType)
                            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            clipData = ClipData.newRawUri(file.name, contentUri)
                        }

                        val launchIntent = if (useChooser) {
                            Intent.createChooser(intent, "Open with").apply {
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                        } else {
                            intent
                        }

                        startActivity(launchIntent)
                        result.success(true)
                    } catch (e: ActivityNotFoundException) {
                        Log.e(TAG, "No activity found to handle openFile: $filePath", e)
                        result.error("NO_APP_FOUND", "No application found to open this file", null)
                    } catch (e: Exception) {
                        Log.e(TAG, "openFile failed: $filePath", e)
                        result.error("OPEN_ERROR", e.message, e.stackTraceToString())
                    }
                }
                "shareFile" -> {
                    val filePath = if (call.arguments is Map<*, *>) call.argument<String>("filePath") else call.arguments as? String
                    val title = if (call.arguments is Map<*, *>) call.argument<String>("title") else null

                    if (filePath.isNullOrEmpty()) {
                        result.error("INVALID_ARGUMENT", "filePath is required", null)
                        return@setMethodCallHandler
                    }

                    try {
                        val file = File(filePath)
                        if (!file.exists()) {
                            result.error("FILE_NOT_FOUND", "File does not exist: $filePath", null)
                            return@setMethodCallHandler
                        }

                        val mimeType = resolveMimeType(file)
                        val contentUri = getShareableContentUri(file)

                        val shareIntent = Intent(Intent.ACTION_SEND).apply {
                            type = mimeType
                            putExtra(Intent.EXTRA_STREAM, contentUri)
                            clipData = ClipData.newRawUri(file.name, contentUri)
                            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                        }

                        val chooser = Intent.createChooser(shareIntent, title ?: "Share").apply {
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }

                        startActivity(chooser)
                        result.success(true)
                    } catch (e: ActivityNotFoundException) {
                        Log.e(TAG, "No activity found to handle shareFile: $filePath", e)
                        result.error("NO_APP_FOUND", "No application found to share this file", null)
                    } catch (e: Exception) {
                        Log.e(TAG, "shareFile failed: $filePath", e)
                        result.error("SHARE_ERROR", e.message, e.stackTraceToString())
                    }
                }
                "openFolder" -> {
                    val folderPath = if (call.arguments is Map<*, *>) call.argument<String>("folderPath") else call.arguments as? String

                    if (folderPath.isNullOrEmpty()) {
                        result.error("INVALID_ARGUMENT", "folderPath is required", null)
                        return@setMethodCallHandler
                    }

                    try {
                        val folder = File(folderPath)
                        if (!folder.exists()) {
                            folder.mkdirs()
                        }
                        if (!folder.exists()) {
                            result.error("FOLDER_NOT_FOUND", "Folder does not exist: $folderPath", null)
                            return@setMethodCallHandler
                        }

                        var launched = false
                        // 1. Try launching the system Downloads UI
                        try {
                            val downloadIntent = Intent(DownloadManager.ACTION_VIEW_DOWNLOADS).apply {
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            startActivity(downloadIntent)
                            launched = true
                        } catch (_: Exception) {
                            // Downloads app not available, fall through
                        }

                        // 2. Try ACTION_VIEW with DocumentsUI / FileProvider / directory uri
                        if (!launched) {
                            try {
                                val authority = "${applicationContext.packageName}.fileprovider"
                                val folderUri = try {
                                    FileProvider.getUriForFile(applicationContext, authority, folder)
                                } catch (_: Exception) {
                                    Uri.parse(folder.absolutePath)
                                }
                                val viewIntent = Intent(Intent.ACTION_VIEW).apply {
                                    setDataAndType(folderUri, "resource/folder")
                                    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                }
                                startActivity(viewIntent)
                                launched = true
                            } catch (_: Exception) {
                                // Folder intent not supported, try generic
                            }
                        }

                        // 3. Fallback: try generic file manager intent
                        if (!launched) {
                            try {
                                val genericIntent = Intent(Intent.ACTION_VIEW).apply {
                                    setDataAndType(Uri.parse(folder.absolutePath), "*/*")
                                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                }
                                startActivity(genericIntent)
                                launched = true
                            } catch (e: ActivityNotFoundException) {
                                Log.e(TAG, "No activity found to open folder: $folderPath", e)
                                result.error("NO_APP_FOUND", "No file manager found to open folder", null)
                                return@setMethodCallHandler
                            }
                        }

                        result.success(true)
                    } catch (e: ActivityNotFoundException) {
                        Log.e(TAG, "No activity found to open folder: $folderPath", e)
                        result.error("NO_APP_FOUND", "No file manager found to open folder", null)
                    } catch (e: Exception) {
                        Log.e(TAG, "openFolder failed: $folderPath", e)
                        result.error("FOLDER_ERROR", e.message, e.stackTraceToString())
                    }
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
        ensureFfmpegReady()

        youtubeDLInitialized = true
        Log.d(TAG, "YoutubeDL initialized successfully")
    }

    // FFmpeg is only needed for post-processing (stream merge, thumbnail and
    // metadata embedding). Retried on demand so a transient failure at app
    // start doesn't silently disable embedding for the whole session; callers
    // skip ffmpeg-dependent options when this returns false.
    @Synchronized
    private fun ensureFfmpegReady(): Boolean {
        if (ffmpegReady) return true
        ffmpegReady = try {
            FFmpeg.getInstance().init(applicationContext)
            Log.d(TAG, "FFmpeg initialized successfully")
            true
        } catch (e: Throwable) {
            Log.e(TAG, "FFmpeg unavailable — merge/thumbnail/metadata embedding will be skipped", e)
            false
        }
        return ffmpegReady
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
            request.addOption("--no-warnings")

            // player_client=media is NOT a valid yt-dlp client (it is not in
            // INNERTUBE_CLIENTS). Forcing it makes extraction fail. Use the
            // battle-tested default multi-client set instead.
            request.addOption("--extractor-args", "youtube:player_client=tv,web,android,ios")
            
            // Get video info as JSON
            request.addOption("-j") // --dump-json
            request.addOption("--no-playlist")

            val response = YoutubeDL.getInstance().execute(request)

            // The JSON output is in out
            val stdout = response.out
            val json = JSONObject()
            json.put("success", true)
            json.put("info", JSONObject(stdout.trim()))
            
            // Log format count for debugging
            val infoJson = JSONObject(stdout.trim())
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
            request.addOption("-J") // --dump-single-json
            request.addOption("--flat-playlist")
            
            val response = YoutubeDL.getInstance().execute(request)
            val stdout = response.out
            val json = JSONObject()
            json.put("success", true)
            json.put("playlist", JSONObject(stdout.trim()))
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
        processId: String,
        archivePath: String? = null,
        subtitleLanguages: List<String>? = null,
        embedSubtitles: Boolean = false,
        sponsorBlock: Boolean = false,
        embedThumbnail: Boolean = true,
        embedMetadata: Boolean = true
    ): String {
        // B23 fix: ensure activeDownloads entry always removed via finally (leaked on success before)
        activeDownloads[processId] = true
        return try {
            ensureYoutubeDLInitialized()
            val outDir = File(outputPath)
            if (!outDir.exists()) {
                outDir.mkdirs()
            }
            emitDownloadEvent(
                mapOf(
                    "event" to "started",
                    "process_id" to processId,
                    "output_path" to outputPath
                )
            )

            val request = YoutubeDLRequest(url)
            
            // Set output template (200B cap avoids ENAMETOOLONG on long titles)
            request.addOption("-o", "$outputPath/%(title).200B.%(ext)s")
            
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
            // Pause/resume relies on yt-dlp continuing partial (.part) files
            // after pause kills the process. Pass --continue explicitly so the
            // resume contract is documented, not implicit.
            request.addOption("--continue")
            
            // Post-processing (stream merge, thumbnail/metadata/subtitle
            // embedding) requires FFmpeg. Skip those options when unavailable
            // so the download itself completes instead of dying in
            // post-processing or silently producing an unembedded file.
            val ffmpegAvailable = ensureFfmpegReady()

            // Valid multi-client set (media is not a real yt-dlp client).
            request.addOption("--extractor-args", "youtube:player_client=tv,web,android,ios")

            // Ensure merging to MP4 container (required for bestvideo+bestaudio)
            if (ffmpegAvailable) {
                request.addOption("--merge-output-format", "mp4")
            } else {
                Log.w(TAG, "FFmpeg unavailable for download $processId — merge and embedding skipped")
            }

            // Download options
            if (archivePath != null && archivePath.isNotEmpty()) {
                request.addOption("--download-archive", archivePath)
            }
            if (subtitleLanguages != null && subtitleLanguages.isNotEmpty()) {
                request.addOption("--sub-langs", subtitleLanguages.joinToString(","))
                request.addOption("--write-subs")
                if (embedSubtitles && ffmpegAvailable) {
                    request.addOption("--embed-subs")
                }
            }
            if (sponsorBlock) {
                request.addOption("--sponsorblock-remove", "all")
            }
            if (embedThumbnail && ffmpegAvailable) {
                request.addOption("--write-thumbnail")
                request.addOption("--embed-thumbnail")
            }
            if (embedMetadata && ffmpegAvailable) {
                request.addOption("--embed-metadata")
            }

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
                    "output_path" to outputPath,
                    // Surface post-processing degradation instead of silently
                    // shipping an unembedded/unmerged file.
                    "ffmpeg_skipped" to !ffmpegAvailable
                )
            )

            val json = JSONObject()
            json.put("success", true)
            json.put("process_id", processId)
            json.put(
                "message",
                if (ffmpegAvailable) "Download started"
                else "Download completed without merge/embedding (FFmpeg unavailable)"
            )
            json.toString()
        } catch (e: Exception) {
            val errorMsg = e.message ?: "Unknown error"
            val fullError = "${errorMsg}\nStack: ${Log.getStackTraceString(e)}"
            Log.e(TAG, "Failed to download video", e)
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
        } finally {
            // B23 fix: always clean map entry (success, error, or cancellation)
            activeDownloads.remove(processId)
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
        val json = JSONObject()
        var lastNativeError: String? = null

        try {
            ensureYoutubeDLInitialized()
            
            val status = if (updateChannel == "nightly") {
                YoutubeDL.getInstance().updateYoutubeDL(applicationContext, YoutubeDL.UpdateChannel.NIGHTLY)
            } else {
                YoutubeDL.getInstance().updateYoutubeDL(applicationContext, YoutubeDL.UpdateChannel.STABLE)
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
            val fallbackResult = downloadAndInstallYtdlpFallback()
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
                json.put("suggestion", if (is403) "Wait 15 minutes for the rate limit to reset, or switch internet connection/VPN." else "Check internet connectivity and try again.")
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

    private fun downloadAndInstallYtdlpFallback(): Pair<Boolean, String?> {
        val downloadUrls = listOf(
            "https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp",
            "https://ghproxy.net/https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp"
        )

        val tempFile = File.createTempFile("ytdlp_dl", ".tmp", applicationContext.cacheDir)
        var lastErr = ""

        try {
            var downloadSuccess = false
            for (urlString in downloadUrls) {
                try {
                    Log.d(TAG, "Attempting yt-dlp download from: $urlString")
                    var currentUrl = urlString
                    var conn: java.net.HttpURLConnection? = null
                    var redirects = 0
                    val maxRedirects = 6

                    while (redirects < maxRedirects) {
                        val url = java.net.URL(currentUrl)
                        conn = (url.openConnection() as java.net.HttpURLConnection).apply {
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

                    if (conn != null && conn.responseCode == java.net.HttpURLConnection.HTTP_OK) {
                        conn.inputStream.use { input ->
                            tempFile.outputStream().use { output ->
                                input.copyTo(output)
                            }
                        }
                        conn.disconnect()

                        // Verify that we downloaded a valid file (> 1 MB)
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

            // Extract version from zipapp if possible
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

            // Install into youtubedl-android directory
            val baseDir = File(applicationContext.noBackupFilesDir, "youtubedl-android")
            val ytdlpDir = File(baseDir, "yt-dlp")
            if (ytdlpDir.exists()) {
                ytdlpDir.deleteRecursively()
            }
            ytdlpDir.mkdirs()

            val targetFile = File(ytdlpDir, "yt-dlp")
            tempFile.copyTo(targetFile, overwrite = true)
            tempFile.delete()

            // Initialize yt-dlp in library
            YoutubeDL.getInstance().init_ytdlp(applicationContext, ytdlpDir)

            // Update shared preferences with version
            try {
                val prefs = applicationContext.getSharedPreferences("youtubedl-android", android.content.Context.MODE_PRIVATE)
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
    private fun setFileExecutable(path: String): Boolean {
        return try {
            val file = File(path)
            if (!file.exists()) return false

            // Try chmod via Runtime.exec
            try {
                val chmodProcess = Runtime.getRuntime().exec(arrayOf("chmod", "755", path))
                chmodProcess.inputStream.bufferedReader().use { it.readText() }
                chmodProcess.errorStream.bufferedReader().use { it.readText() }
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

        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                startForegroundService(intent)
            } else {
                startService(intent)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start DownloadService", e)
        }
    }

    private fun stopDownloadService() {
        try {
            val intent = Intent(this, DownloadService::class.java).apply {
                action = "STOP_SERVICE"
            }
            stopService(intent)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to stop DownloadService", e)
        }
    }

    private fun cancelDownloadInService(downloadId: String) {
        val intent = Intent(this, DownloadService::class.java).apply {
            action = "CANCEL_DOWNLOAD"
            putExtra("downloadId", downloadId)
        }
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                startForegroundService(intent)
            } else {
                startService(intent)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to send cancel to DownloadService", e)
        }
    }

    private fun resolveMimeType(file: File): String {
        val ext = file.extension.lowercase()
        val fromMap = MimeTypeMap.getSingleton().getMimeTypeFromExtension(ext)
        if (!fromMap.isNullOrEmpty()) return fromMap

        return when (ext) {
            "mp4" -> "video/mp4"
            "mkv" -> "video/x-matroska"
            "webm" -> "video/webm"
            "m4a" -> "audio/mp4"
            "mp3" -> "audio/mpeg"
            "opus" -> "audio/opus"
            "aac" -> "audio/aac"
            "ogg" -> "audio/ogg"
            "wav" -> "audio/wav"
            "flac" -> "audio/flac"
            "ts" -> "video/mp2t"
            "mov" -> "video/quicktime"
            "avi" -> "video/x-msvideo"
            "3gp" -> "video/3gpp"
            "apk" -> "application/vnd.android.package-archive"
            else -> "*/*"
        }
    }
}
