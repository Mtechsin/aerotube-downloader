package com.aerotube.youtube_downloader

import java.io.File

/**
 * Immutable download job description. Pure data — no Android types — so the
 * request factory can be unit-tested on the JVM.
 */
data class DownloadJob(
    val url: String,
    val outputPath: String,
    val format: String?,
    val cookiesPath: String?,
    val userAgent: String?,
    val archivePath: String?,
    val subtitleLanguages: List<String>?,
    val embedSubs: Boolean,
    val sponsorBlock: Boolean,
    val embedThumbnail: Boolean,
    val embedMetadata: Boolean,
    val ffmpegAvailable: Boolean,
    val audioOnly: Boolean = false,
    val targetHeight: Int? = null,
    /** yt-dlp --audio-quality scale, or '0' for best. */
    val audioQuality: String? = null,
    /** null → omit --concurrent-fragments. */
    val concurrentFragments: Int? = null,
    /** null → omit --paths. */
    val tempDir: String? = null,
    /** null → omit --print-to-file. */
    val printToFile: String? = null,
)

/**
 * Typed yt-dlp option. Replaces the old List<String> + startsWith("-")
 * pairing heuristic, which mis-handled negative-looking values.
 *
 * Engine conversion:
 * - [YtDlpArg.Flag] → `request.addOption(name)`
 * - [YtDlpArg.Opt] → `request.addOption(name, value)`
 * - [YtDlpArg.OptN] → `request.addOption(name)` then `addOption(v)` for each value
 *   (nargs>1 flags such as `--print-to-file WHEN:TEMPLATE FILE`)
 */
sealed class YtDlpArg {
    data class Flag(val name: String) : YtDlpArg()
    data class Opt(val name: String, val value: String) : YtDlpArg()
    data class OptN(val name: String, val values: List<String>) : YtDlpArg()
}

/**
 * A fully built request: positional [url] plus typed [options].
 * The URL is NOT part of [options] — pass it separately when constructing
 * the YoutubeDLRequest.
 *
 * Engine (another agent) converts this via:
 * ```
 * val request = YoutubeDLRequest(built.url)
 * built.options.forEach { arg ->
 *     when (arg) {
 *         is YtDlpArg.Flag -> request.addOption(arg.name)
 *         is YtDlpArg.Opt -> request.addOption(arg.name, arg.value)
 *     }
 * }
 * ```
 */
data class BuiltRequest(
    val url: String,
    val options: List<YtDlpArg>,
)

/** Flatten typed options to yt-dlp argv tokens (tests / logging). */
fun List<YtDlpArg>.toArgv(): List<String> = flatMap { arg ->
    when (arg) {
        is YtDlpArg.Flag -> listOf(arg.name)
        is YtDlpArg.Opt -> listOf(arg.name, arg.value)
        is YtDlpArg.OptN -> listOf(arg.name) + arg.values
    }
}

enum class PlayerClient { Default, Fallback }

/**
 * Pure yt-dlp argument builder. No Android framework, no YoutubeDLRequest.
 *
 * Callers receive a [BuiltRequest] of typed [YtDlpArg] pairs and convert it
 * to YoutubeDLRequest via `addOption(name)` / `addOption(name, value)`.
 *
 * NEVER force android/ios Innertube clients — they cap ~360p progressive
 * formats. Default = yt-dlp web defaults (full adaptive ladder). Fallback
 * uses web,tv,mweb which still expose adaptive formats.
 *
 * Play Integrity / PO-token note: high-res adaptive ladders
 * (bestvideo+bestaudio) require web clients that are subject to PO-token
 * gating. Do not "fix" that by forcing android/ios player clients (those
 * silently cap ~360p). Only the existing Fallback path may append
 * `youtube:player_client=web,tv,mweb`.
 */
object YtDlpRequestFactory {

    private const val DUAL_STREAM_DEFAULT = "bestvideo+bestaudio/best"

    /**
     * Args for a download. [client] = [PlayerClient.Default] uses yt-dlp web
     * defaults; [PlayerClient.Fallback] adds web/tv/mweb extractor args for
     * auth/bot failures.
     */
    fun downloadArgs(job: DownloadJob, client: PlayerClient = PlayerClient.Default): BuiltRequest {
        val options = mutableListOf<YtDlpArg>()
        val format = resolveFormat(job)

        // Ignore any packaged/user yt-dlp config so our args fully own the run.
        // android/app/src/main/assets/config.txt was dead (never loaded) but a
        // leftover ~/.config/yt-dlp/config could still inject -o/-f overrides.
        options += YtDlpArg.Flag("--ignore-config")

        options += YtDlpArg.Opt("-o", "${job.outputPath}/%(title).200B.%(ext)s")
        options += YtDlpArg.Opt("-f", format)

        // Cookies guard: only emit when path is non-empty AND the file exists.
        // yt-dlp hard-fails on a missing --cookies path.
        val cookies = job.cookiesPath
        if (!cookies.isNullOrEmpty() && File(cookies).exists()) {
            options += YtDlpArg.Opt("--cookies", cookies)
        }
        if (!job.userAgent.isNullOrEmpty()) {
            options += YtDlpArg.Opt("--user-agent", job.userAgent)
        }

        // Reliability flags (see historical MainActivity download path)
        options += YtDlpArg.Flag("--force-ipv4")
        options += YtDlpArg.Opt("--socket-timeout", "15")
        options += YtDlpArg.Opt("--retries", "10")
        options += YtDlpArg.Opt("--fragment-retries", "10")
        options += YtDlpArg.Opt("--file-access-retries", "3")
        options += YtDlpArg.Flag("--no-playlist")
        options += YtDlpArg.Flag("--no-warnings")
        options += YtDlpArg.Flag("--newline")
        // Pause/resume continues partial (.part) files after the process is killed.
        options += YtDlpArg.Flag("--continue")
        // Throughput: larger HTTP chunks + buffer keep the pipe full on
        // fast links (matches the Windows desktop download path).
        options += YtDlpArg.Opt("--http-chunk-size", "10M")
        options += YtDlpArg.Opt("--buffer-size", "16K")

        val concurrent = job.concurrentFragments
        if (concurrent != null && concurrent > 0) {
            options += YtDlpArg.Opt("--concurrent-fragments", concurrent.toString())
        }

        // Keep .part files out of public Gallery via a private temp dir.
        val temp = job.tempDir
        if (!temp.isNullOrEmpty()) {
            options += YtDlpArg.Opt("--paths", "temp:$temp")
        }

        // Path oracle: --print-to-file is nargs=2 ([WHEN:]TEMPLATE + FILE).
        // after_move writes the exact final path after post-processing/rename.
        // Emit as three argv tokens — a single Opt would drop the FILE token.
        val printTo = job.printToFile
        if (!printTo.isNullOrEmpty()) {
            options += YtDlpArg.OptN(
                "--print-to-file",
                listOf("after_move:filepath", printTo)
            )
        }

        // Post-processing requires FFmpeg. Skip merge/extract/embed when
        // unavailable so the download itself completes instead of dying in
        // post-processing.
        if (job.ffmpegAvailable) {
            if (job.audioOnly) {
                // --extract-audio replaces --merge-output-format.
                options += YtDlpArg.Flag("--extract-audio")
                options += YtDlpArg.Opt("--audio-format", "m4a")
                options += YtDlpArg.Opt("--audio-quality", job.audioQuality ?: "0")
            } else {
                // Format-aware merge: only dual-stream (+) selections need
                // FFmpeg merge. Progressive/single-stream files are already
                // muxed — omit --merge-output-format entirely.
                val needsMerge = format.contains('+')
                if (needsMerge) {
                    options += YtDlpArg.Opt("--merge-output-format", "mp4")
                }
            }
        }

        if (!job.archivePath.isNullOrEmpty()) {
            options += YtDlpArg.Opt("--download-archive", job.archivePath)
        }

        val langs = job.subtitleLanguages?.filter { it.isNotEmpty() }
        if (!langs.isNullOrEmpty()) {
            options += YtDlpArg.Opt("--sub-langs", langs.joinToString(","))
            options += YtDlpArg.Flag("--write-subs")
            if (job.embedSubs && job.ffmpegAvailable) {
                options += YtDlpArg.Flag("--embed-subs")
            }
        }

        if (job.sponsorBlock) {
            options += YtDlpArg.Opt("--sponsorblock-remove", "all")
        }

        // Embeds may apply to progressive files too; gate only on ffmpeg.
        if (job.embedThumbnail && job.ffmpegAvailable) {
            options += YtDlpArg.Flag("--write-thumbnail")
            options += YtDlpArg.Flag("--embed-thumbnail")
        }

        if (job.embedMetadata && job.ffmpegAvailable) {
            options += YtDlpArg.Flag("--embed-metadata")
        }

        if (client == PlayerClient.Fallback) {
            options += YtDlpArg.Opt("--extractor-args", "youtube:player_client=web,tv,mweb")
        }

        return BuiltRequest(url = job.url, options = options)
    }

    /**
     * Common args for metadata queries (-j / -J are appended by the caller).
     * [fallback] adds web/tv/mweb extractor args for auth/bot retries.
     */
    fun infoArgs(
        url: String,
        cookiesPath: String?,
        userAgent: String?,
        fallback: Boolean = false,
    ): BuiltRequest {
        val options = mutableListOf<YtDlpArg>()

        options += YtDlpArg.Flag("--ignore-config")

        val cookies = cookiesPath
        if (!cookies.isNullOrEmpty() && File(cookies).exists()) {
            options += YtDlpArg.Opt("--cookies", cookies)
        }
        if (!userAgent.isNullOrEmpty()) {
            options += YtDlpArg.Opt("--user-agent", userAgent)
        }

        options += YtDlpArg.Flag("--force-ipv4")
        options += YtDlpArg.Opt("--socket-timeout", "15")
        options += YtDlpArg.Opt("--retries", "10")
        options += YtDlpArg.Flag("--no-warnings")

        if (fallback) {
            options += YtDlpArg.Opt("--extractor-args", "youtube:player_client=web,tv,mweb")
        }

        return BuiltRequest(url = url, options = options)
    }

    /**
     * Resolve the effective -f format string.
     *
     * - audioOnly → caller format, else `bestaudio`.
     * - !ffmpegAvailable and dual-stream (+) → coerce to progressive mp4.
     * - targetHeight with auto/default format → progressive height ladder.
     * - explicit formatId is left alone (caller owns it).
     */
    private fun resolveFormat(job: DownloadJob): String {
        val raw = job.format?.takeIf { it.isNotEmpty() }

        if (job.audioOnly) {
            return raw ?: "bestaudio"
        }

        var resolved = raw
        if (!job.ffmpegAvailable && resolved != null && resolved.contains('+')) {
            // Do not pass merge format through when ffmpeg is unavailable.
            resolved = "best[ext=mp4]/best"
        }

        val height = job.targetHeight
        if (height != null && height > 0 && isAutoOrDefaultFormat(raw)) {
            // Progressive auto-select: avoids merge and works without DASH
            // when the caller did not pin an explicit formatId.
            return "best[height<=$height][ext=mp4]/best[height<=$height]/best[ext=mp4]/best"
        }

        return resolved ?: "best"
    }

    /** null/empty, factory default "best", or the dual-stream default. */
    private fun isAutoOrDefaultFormat(format: String?): Boolean {
        if (format.isNullOrEmpty()) return true
        return format == "best" || format == DUAL_STREAM_DEFAULT
    }
}
