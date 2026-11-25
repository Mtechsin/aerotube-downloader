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
import androidx.lifecycle.lifecycleScope
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import org.json.JSONObject
import java.io.File
import java.lang.reflect.Method

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.aerotube.youtube_downloader/permissions"
    private val YTDLP_CHANNEL = "com.aerotube.youtube_downloader/ytdlp_android"
    private val YTDLP_EVENTS_CHANNEL = "com.aerotube.youtube_downloader/ytdlp_android/events"
    private val SERVICE_CHANNEL = "com.aerotube.youtube_downloader/download_service"
    private val FILE_PROVIDER_CHANNEL = "com.aerotube.youtube_downloader/file_provider"
    private val DEEP_LINK_CHANNEL = "com.aerotube.youtube_downloader/deep_links"
    private val DEEP_LINK_EVENTS_CHANNEL = "com.aerotube.youtube_downloader/deep_links/events"

    @Volatile
    private var deepLinkEventSink: EventChannel.EventSink? = null
    @Volatile
    private var pendingDeepLink: String? = null

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

        // Warm the engine off the main thread; method handlers re-check via ensureInit.
        lifecycleScope.launch(Dispatchers.IO) {
            try {
                YtDlpEngine.ensureInit(applicationContext)
            } catch (e: Throwable) {
                Log.e(TAG, "YoutubeDL init failed", e)
            }
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
        // destroyed before the background work finishes. Use main looper + safe wrappers
        // so Dart Futures don't hang forever. Dart side also adds .timeout() as defense-in-depth.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, YTDLP_CHANNEL).setMethodCallHandler { call, result ->
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

            lifecycleScope.launch(Dispatchers.IO) {
                try {
                    when (call.method) {
                        "getVersion" -> {
                            val version = YtDlpEngine.getVersion(applicationContext)
                            safeSuccess(version)
                        }
                        "getFfmpegVersion" -> {
                            YtDlpEngine.ensureInit(applicationContext)
                            safeSuccess(YtDlpEngine.ffmpegVersion())
                        }
                        "getVideoInfo" -> {
                            val url = call.argument<String>("url")
                            val cookiesPath = call.argument<String>("cookies_path")
                            val userAgent = call.argument<String>("user_agent")

                            if (url == null) {
                                safeError("INVALID_ARGUMENT", "URL is required", null)
                                return@launch
                            }

                            val infoJson = YtDlpEngine.getVideoInfo(applicationContext, url, cookiesPath, userAgent)
                            safeSuccess(infoJson)
                        }
                        "getPlaylistInfo" -> {
                            val url = call.argument<String>("url")
                            val cookiesPath = call.argument<String>("cookies_path")
                            val userAgent = call.argument<String>("user_agent")
                            val playlistItems = call.argument<String>("playlist_items")

                            if (url == null) {
                                safeError("INVALID_ARGUMENT", "URL is required", null)
                                return@launch
                            }

                            val playlistJson = YtDlpEngine.getPlaylistInfo(
                                applicationContext, url, cookiesPath, userAgent, playlistItems
                            )
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
                            // Optional progressive/audio controls (Dart may omit).
                            val audioOnly = call.argument<Boolean>("audio_only") ?: false
                            val targetHeight = call.argument<Int>("target_height")
                            val audioQuality = call.argument<String>("audio_quality")
                            val concurrentFragments = call.argument<Int>("concurrent_fragments")

                            if (url == null || outputPath == null) {
                                safeError("INVALID_ARGUMENT", "URL and output_path are required", null)
                                return@launch
                            }

                            val id = processId ?: "download_${System.currentTimeMillis()}"
                            YtDlpEngine.ensureInit(applicationContext)
                            val ffmpegAvailable = YtDlpEngine.ensureFfmpeg()
                            val job = DownloadJob(
                                url = url,
                                outputPath = outputPath,
                                format = format,
                                cookiesPath = cookiesPath,
                                userAgent = userAgent,
                                archivePath = archivePath,
                                subtitleLanguages = subtitleLanguages,
                                embedSubs = embedSubtitles,
                                sponsorBlock = sponsorBlock,
                                embedThumbnail = embedThumbnail,
                                embedMetadata = embedMetadata,
                                ffmpegAvailable = ffmpegAvailable,
                                audioOnly = audioOnly,
                                targetHeight = targetHeight,
                                audioQuality = audioQuality,
                                // null → engine defaults to 4 (cellular-safe).
                                concurrentFragments = concurrentFragments,
                                // Isolate .part files from public Gallery.
                                tempDir = File(cacheDir, "aerotube_temp").absolutePath,
                                // printToFile owned by YtDlpEngine.startDownload
                                // (per-process path oracle in cacheDir).
                                printToFile = null
                            )

                            // Ensure FGS is running so the download has a notification
                            // and is not killed in the background. Then hand execution
                            // to the engine — do NOT wait for the download to finish.
                            startDownloadService(id, url, outputPath, format, cookiesPath, userAgent, null)
                            YtDlpEngine.startDownload(applicationContext, job, id)

                            val json = JSONObject()
                            json.put("success", true)
                            json.put("process_id", id)
                            safeSuccess(json.toString())
                        }
                        "cancelDownload" -> {
                            val processId = call.argument<String>("process_id")
                            if (processId == null) {
                                safeError("INVALID_ARGUMENT", "process_id is required", null)
                                return@launch
                            }
                            val success = YtDlpEngine.cancel(processId)
                            safeSuccess(success)
                        }
                        "cancelAll" -> {
                            YtDlpEngine.cancelAll()
                            safeSuccess(true)
                        }
                        "searchVideos" -> {
                            val query = call.argument<String>("query")
                            val limit = call.argument<Int>("limit") ?: 10
                            val cookiesPath = call.argument<String>("cookies_path")
                            val userAgent = call.argument<String>("user_agent")
                            if (query.isNullOrBlank()) {
                                safeError("INVALID_ARGUMENT", "query is required", null)
                                return@launch
                            }
                            val searchJson = YtDlpEngine.searchVideos(
                                applicationContext, query, limit, cookiesPath, userAgent
                            )
                            safeSuccess(searchJson)
                        }
                        "updateYoutubeDL" -> {
                            val updateChannel = call.argument<String>("update_channel") ?: "stable"
                            val updateResult = YtDlpEngine.updateYoutubeDL(applicationContext, updateChannel)
                            safeSuccess(updateResult)
                        }
                        else -> {
                            safeNotImplemented()
                        }
                    }
                } catch (e: Throwable) {
                    Log.e(TAG, "Error handling method call", e)
                    // Include the exception class name: after R8 minification,
                    // e.message is often just an obfuscated name like "I4.f"
                    // (NoClassDefFoundError), which is useless for diagnosis.
                    val detail = buildString {
                        append(e.javaClass.name)
                        val msg = e.message
                        if (!msg.isNullOrBlank()) append(": ").append(msg)
                        // Unwrap one cause level for ClassNotFoundException chains.
                        val cause = e.cause
                        if (cause != null && cause !== e) {
                            append("\nCaused by ").append(cause.javaClass.name)
                            val causeMsg = cause.message
                            if (!causeMsg.isNullOrBlank()) append(": ").append(causeMsg)
                        }
                    }
                    safeError("YTDLP_ERROR", detail, e.stackTraceToString())
                }
            }
        }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, YTDLP_EVENTS_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    DownloadEventBus.setSink(events)
                }

                override fun onCancel(arguments: Any?) {
                    DownloadEventBus.setSink(null)
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

        val running = DownloadService.instance
        if (running != null && running.ensureRegistered(
                downloadId,
                url,
                outputPath,
                format,
                cookiesPath,
                userAgent,
                title ?: "Downloading..."
            )
        ) {
            return
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
        val running = DownloadService.instance
        if (running != null) {
            running.requestCancel(downloadId)
            return
        }
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
