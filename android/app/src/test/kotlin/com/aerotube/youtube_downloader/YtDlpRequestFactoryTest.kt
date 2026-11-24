package com.aerotube.youtube_downloader

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

class YtDlpRequestFactoryTest {

    private fun baseJob(
        ffmpeg: Boolean = true,
        format: String? = "bestvideo+bestaudio/best",
        subtitleLanguages: List<String>? = null,
        embedSubs: Boolean = false,
        sponsorBlock: Boolean = false,
        embedThumbnail: Boolean = true,
        embedMetadata: Boolean = true,
        cookiesPath: String? = null,
        audioOnly: Boolean = false,
        targetHeight: Int? = null,
        audioQuality: String? = null,
        concurrentFragments: Int? = null,
        tempDir: String? = null,
        printToFile: String? = null,
    ): DownloadJob = DownloadJob(
        url = "https://www.youtube.com/watch?v=dQw4w9WgXcQ",
        outputPath = "/storage/emulated/0/Download/AeroTube",
        format = format,
        cookiesPath = cookiesPath,
        userAgent = null,
        archivePath = null,
        subtitleLanguages = subtitleLanguages,
        embedSubs = embedSubs,
        sponsorBlock = sponsorBlock,
        embedThumbnail = embedThumbnail,
        embedMetadata = embedMetadata,
        ffmpegAvailable = ffmpeg,
        audioOnly = audioOnly,
        targetHeight = targetHeight,
        audioQuality = audioQuality,
        concurrentFragments = concurrentFragments,
        tempDir = tempDir,
        printToFile = printToFile,
    )

    private fun BuiltRequest.optValue(name: String): String? =
        options.filterIsInstance<YtDlpArg.Opt>().find { it.name == name }?.value

    private fun BuiltRequest.optN(name: String): YtDlpArg.OptN? =
        options.filterIsInstance<YtDlpArg.OptN>().find { it.name == name }

    private fun BuiltRequest.hasOpt(name: String): Boolean =
        options.any { it is YtDlpArg.Opt && it.name == name }

    private fun BuiltRequest.hasFlag(name: String): Boolean =
        options.any { it is YtDlpArg.Flag && it.name == name }

    private fun BuiltRequest.hasOption(name: String): Boolean =
        hasOpt(name) || hasFlag(name) || optN(name) != null

    private fun BuiltRequest.argv(): List<String> = listOf(url) + options.toArgv()

    // --- reliability / core ---

    @Test
    fun defaultDownloadArgsContainReliabilityFlags() {
        val req = YtDlpRequestFactory.downloadArgs(baseJob(ffmpeg = true))

        assertTrue(req.hasFlag("--ignore-config"))
        assertTrue(req.hasFlag("--continue"))
        assertTrue(req.hasFlag("--force-ipv4"))
        assertTrue(req.hasFlag("--newline"))
        assertTrue(req.hasFlag("--no-playlist"))
        assertTrue(req.hasFlag("--no-warnings"))
        assertTrue(req.hasOpt("--socket-timeout"))
        assertTrue(req.hasOpt("--retries"))
    }

    @Test
    fun infoArgsAlsoIgnoreExternalConfig() {
        val req = YtDlpRequestFactory.infoArgs(
            url = "https://www.youtube.com/watch?v=dQw4w9WgXcQ",
            cookiesPath = null,
            userAgent = null,
        )
        assertTrue(req.hasFlag("--ignore-config"))
    }

    @Test
    fun retriesUseElevatedCounts() {
        val req = YtDlpRequestFactory.downloadArgs(baseJob())
        assertEquals("10", req.optValue("--retries"))
        assertEquals("10", req.optValue("--fragment-retries"))
        assertEquals("3", req.optValue("--file-access-retries"))
    }

    @Test
    fun defaultDownloadArgsIncludeMergeOutputFormatWhenFfmpegDualStream() {
        val req = YtDlpRequestFactory.downloadArgs(
            baseJob(ffmpeg = true, format = "bestvideo+bestaudio/best")
        )
        assertEquals("mp4", req.optValue("--merge-output-format"))
    }

    @Test
    fun progressiveFormatOmitsMergeOutputFormatEvenWithFfmpeg() {
        val progressive = YtDlpRequestFactory.downloadArgs(
            baseJob(ffmpeg = true, format = "best[ext=mp4]")
        )
        assertFalse(
            "progressive format must omit --merge-output-format",
            progressive.hasOpt("--merge-output-format")
        )

        // Height ladder from targetHeight is also progressive (no '+').
        val heightLadder = YtDlpRequestFactory.downloadArgs(
            baseJob(ffmpeg = true, format = null, targetHeight = 720)
        )
        assertFalse(heightLadder.hasOpt("--merge-output-format"))
        assertEquals(
            "best[height<=720][ext=mp4]/best[height<=720]/best[ext=mp4]/best",
            heightLadder.optValue("-f")
        )
    }

    @Test
    fun ffmpegFalseOmitsMergeAndEmbedOptions() {
        val req = YtDlpRequestFactory.downloadArgs(
            baseJob(
                ffmpeg = false,
                embedThumbnail = true,
                embedMetadata = true,
                embedSubs = true,
                subtitleLanguages = listOf("en"),
            )
        )
        assertFalse(req.hasOpt("--merge-output-format"))
        assertFalse(req.hasFlag("--embed-thumbnail"))
        assertFalse(req.hasFlag("--embed-metadata"))
        assertFalse(req.hasFlag("--embed-subs"))
    }

    @Test
    fun formatCoercedWhenFfmpegMissingAndFormatHasPlus() {
        val req = YtDlpRequestFactory.downloadArgs(
            baseJob(ffmpeg = false, format = "bestvideo+bestaudio/best")
        )
        assertEquals("best[ext=mp4]/best", req.optValue("-f"))
        assertFalse(req.hasOpt("--merge-output-format"))
    }

    @Test
    fun formatUnchangedWhenFfmpegMissingAndNoPlus() {
        val req = YtDlpRequestFactory.downloadArgs(
            baseJob(ffmpeg = false, format = "best[ext=mp4]")
        )
        assertEquals("best[ext=mp4]", req.optValue("-f"))
    }

    // --- player client invariants ---

    @Test
    fun fallbackContainsWebTvMwebPlayerClient() {
        val req = YtDlpRequestFactory.downloadArgs(baseJob(), PlayerClient.Fallback)
        assertEquals("youtube:player_client=web,tv,mweb", req.optValue("--extractor-args"))
    }

    @Test
    fun defaultHasNoForcedPlayerClient() {
        val req = YtDlpRequestFactory.downloadArgs(baseJob(), PlayerClient.Default)
        assertFalse("Default must not force a player_client", req.hasOpt("--extractor-args"))
    }

    @Test
    fun neitherDefaultNorFallbackContainsAndroidOrIosPlayerClient() {
        val requests = listOf(
            YtDlpRequestFactory.downloadArgs(baseJob(), PlayerClient.Default),
            YtDlpRequestFactory.downloadArgs(baseJob(), PlayerClient.Fallback),
            YtDlpRequestFactory.downloadArgs(
                baseJob(ffmpeg = true, format = "bestvideo+bestaudio/best")
            ),
        )
        for (req in requests) {
            for (token in req.argv()) {
                assertFalse(
                    "player_client must never include android: $token",
                    token.contains("player_client=android") || token.contains("player_client=ios")
                )
                assertFalse(
                    "standalone android/ios token must not appear: $token",
                    token == "android" || token == "ios"
                )
            }
        }
    }

    // --- embeds / subs / sponsorblock ---

    @Test
    fun embedOptionsGatedByFlagsAndFfmpeg() {
        val withFfmpeg = YtDlpRequestFactory.downloadArgs(
            baseJob(ffmpeg = true, embedThumbnail = true, embedMetadata = true)
        )
        assertTrue(withFfmpeg.hasFlag("--embed-thumbnail"))
        assertTrue(withFfmpeg.hasFlag("--write-thumbnail"))
        assertTrue(withFfmpeg.hasFlag("--embed-metadata"))

        val flagsOff = YtDlpRequestFactory.downloadArgs(
            baseJob(ffmpeg = true, embedThumbnail = false, embedMetadata = false)
        )
        assertFalse(flagsOff.hasFlag("--embed-thumbnail"))
        assertFalse(flagsOff.hasFlag("--embed-metadata"))
    }

    @Test
    fun progressiveWithFfmpegStillAllowsEmbeds() {
        val req = YtDlpRequestFactory.downloadArgs(
            baseJob(
                ffmpeg = true,
                format = "best[ext=mp4]",
                embedThumbnail = true,
                embedMetadata = true,
            )
        )
        assertFalse(req.hasOpt("--merge-output-format"))
        assertTrue(req.hasFlag("--embed-thumbnail"))
        assertTrue(req.hasFlag("--embed-metadata"))
    }

    @Test
    fun subtitlesRequireLanguagesToEmitWriteAndEmbed() {
        val noLangs = YtDlpRequestFactory.downloadArgs(
            baseJob(ffmpeg = true, embedSubs = true, subtitleLanguages = null)
        )
        assertFalse(noLangs.hasFlag("--write-subs"))
        assertFalse(noLangs.hasFlag("--embed-subs"))

        val full = YtDlpRequestFactory.downloadArgs(
            baseJob(ffmpeg = true, embedSubs = true, subtitleLanguages = listOf("en", "es"))
        )
        assertTrue(full.hasFlag("--write-subs"))
        assertTrue(full.hasFlag("--embed-subs"))
        assertEquals("en,es", full.optValue("--sub-langs"))

        val noFfmpeg = YtDlpRequestFactory.downloadArgs(
            baseJob(ffmpeg = false, embedSubs = true, subtitleLanguages = listOf("en"))
        )
        assertTrue(noFfmpeg.hasFlag("--write-subs"))
        assertFalse(noFfmpeg.hasFlag("--embed-subs"))
    }

    @Test
    fun sponsorBlockDoesNotRequireFfmpeg() {
        val req = YtDlpRequestFactory.downloadArgs(baseJob(ffmpeg = false, sponsorBlock = true))
        assertEquals("all", req.optValue("--sponsorblock-remove"))
    }

    // --- output / format defaults ---

    @Test
    fun outputTemplateUsesTitleCap() {
        val req = YtDlpRequestFactory.downloadArgs(baseJob())
        assertEquals(
            "/storage/emulated/0/Download/AeroTube/%(title).200B.%(ext)s",
            req.optValue("-o")
        )
    }

    @Test
    fun formatDefaultsToBestWhenNullOrEmpty() {
        val nullFormat = YtDlpRequestFactory.downloadArgs(baseJob(format = null))
        assertEquals("best", nullFormat.optValue("-f"))

        val emptyFormat = YtDlpRequestFactory.downloadArgs(baseJob(format = ""))
        assertEquals("best", emptyFormat.optValue("-f"))
    }

    @Test
    fun targetHeightAppliesProgressiveLadderOnAutoFormat() {
        val nullFormat = YtDlpRequestFactory.downloadArgs(
            baseJob(format = null, targetHeight = 1080)
        )
        assertEquals(
            "best[height<=1080][ext=mp4]/best[height<=1080]/best[ext=mp4]/best",
            nullFormat.optValue("-f")
        )

        val dualDefault = YtDlpRequestFactory.downloadArgs(
            baseJob(format = "bestvideo+bestaudio/best", targetHeight = 480)
        )
        assertEquals(
            "best[height<=480][ext=mp4]/best[height<=480]/best[ext=mp4]/best",
            dualDefault.optValue("-f")
        )
    }

    @Test
    fun targetHeightLeavesExplicitFormatIdAlone() {
        val explicit = YtDlpRequestFactory.downloadArgs(
            baseJob(format = "137+140", targetHeight = 720)
        )
        assertEquals("137+140", explicit.optValue("-f"))
        assertEquals("mp4", explicit.optValue("--merge-output-format"))
    }

    // --- cookies ---

    @Test
    fun cookiesOmittedWhenPathNullOrEmpty() {
        val nullPath = YtDlpRequestFactory.downloadArgs(baseJob(cookiesPath = null))
        assertFalse(nullPath.hasOpt("--cookies"))

        val emptyPath = YtDlpRequestFactory.downloadArgs(baseJob(cookiesPath = ""))
        assertFalse(emptyPath.hasOpt("--cookies"))
    }

    @Test
    fun cookiesOmittedWhenFileDoesNotExist() {
        val missing = File.createTempFile("aerotube-missing-cookies", ".txt")
        val path = missing.absolutePath
        missing.delete()
        assertFalse(File(path).exists())

        val req = YtDlpRequestFactory.downloadArgs(baseJob(cookiesPath = path))
        assertFalse("nonexistent cookies file must be omitted", req.hasOpt("--cookies"))
    }

    @Test
    fun cookiesEmittedWhenFileExists() {
        val cookies = File.createTempFile("aerotube-cookies", ".txt")
        try {
            cookies.writeText("# Netscape HTTP Cookie File\n")
            assertTrue(cookies.exists())

            val req = YtDlpRequestFactory.downloadArgs(
                baseJob(cookiesPath = cookies.absolutePath)
            )
            assertEquals(cookies.absolutePath, req.optValue("--cookies"))
        } finally {
            cookies.delete()
        }
    }

    @Test
    fun infoArgsCookiesRespectExistsGuard() {
        val missing = File.createTempFile("aerotube-info-missing", ".txt")
        val path = missing.absolutePath
        missing.delete()

        val without = YtDlpRequestFactory.infoArgs("https://youtu.be/abc", path, null, false)
        assertFalse(without.hasOpt("--cookies"))

        val cookies = File.createTempFile("aerotube-info-cookies", ".txt")
        try {
            val with = YtDlpRequestFactory.infoArgs(
                "https://youtu.be/abc", cookies.absolutePath, null, false
            )
            assertEquals(cookies.absolutePath, with.optValue("--cookies"))
        } finally {
            cookies.delete()
        }
    }

    // --- concurrent fragments ---

    @Test
    fun concurrentFragmentsPresentWhenPositive() {
        val req = YtDlpRequestFactory.downloadArgs(baseJob(concurrentFragments = 4))
        assertEquals("4", req.optValue("--concurrent-fragments"))
    }

    @Test
    fun concurrentFragmentsOmittedWhenNullOrNonPositive() {
        val nullCf = YtDlpRequestFactory.downloadArgs(baseJob(concurrentFragments = null))
        assertFalse(nullCf.hasOpt("--concurrent-fragments"))

        val zero = YtDlpRequestFactory.downloadArgs(baseJob(concurrentFragments = 0))
        assertFalse(zero.hasOpt("--concurrent-fragments"))

        val negative = YtDlpRequestFactory.downloadArgs(baseJob(concurrentFragments = -1))
        assertFalse(negative.hasOpt("--concurrent-fragments"))
    }

    // --- audio-only extract ---

    @Test
    fun audioOnlyWithFfmpegEmitsExtractAudioFlags() {
        val req = YtDlpRequestFactory.downloadArgs(
            baseJob(
                ffmpeg = true,
                audioOnly = true,
                format = null,
                embedThumbnail = true,
                embedMetadata = true,
                audioQuality = "0",
            )
        )
        assertEquals("bestaudio", req.optValue("-f"))
        assertTrue(req.hasFlag("--extract-audio"))
        assertEquals("m4a", req.optValue("--audio-format"))
        assertEquals("0", req.optValue("--audio-quality"))
        assertFalse(
            "extract-audio replaces merge",
            req.hasOpt("--merge-output-format")
        )
        assertTrue(req.hasFlag("--embed-metadata"))
        assertTrue(req.hasFlag("--embed-thumbnail"))
    }

    @Test
    fun audioOnlyUsesExplicitAudioQualityWhenProvided() {
        val req = YtDlpRequestFactory.downloadArgs(
            baseJob(ffmpeg = true, audioOnly = true, audioQuality = "5")
        )
        assertEquals("5", req.optValue("--audio-quality"))
    }

    @Test
    fun audioOnlyDefaultsAudioQualityToBest() {
        val req = YtDlpRequestFactory.downloadArgs(
            baseJob(ffmpeg = true, audioOnly = true, audioQuality = null)
        )
        assertEquals("0", req.optValue("--audio-quality"))
    }

    @Test
    fun audioOnlyKeepsCallerFormatWhenSet() {
        val req = YtDlpRequestFactory.downloadArgs(
            baseJob(ffmpeg = true, audioOnly = true, format = "251")
        )
        assertEquals("251", req.optValue("-f"))
        assertTrue(req.hasFlag("--extract-audio"))
    }

    @Test
    fun audioOnlyWithoutFfmpegOmitsExtractFlags() {
        val req = YtDlpRequestFactory.downloadArgs(
            baseJob(ffmpeg = false, audioOnly = true, format = null)
        )
        assertEquals("bestaudio", req.optValue("-f"))
        assertFalse(req.hasFlag("--extract-audio"))
        assertFalse(req.hasOpt("--audio-format"))
        assertFalse(req.hasOpt("--audio-quality"))
        assertFalse(req.hasOpt("--merge-output-format"))
        assertFalse(req.hasFlag("--embed-metadata"))
        assertFalse(req.hasFlag("--embed-thumbnail"))
    }

    // --- temp isolation / path oracle ---

    @Test
    fun pathsTempEmittedWhenTempDirSet() {
        val req = YtDlpRequestFactory.downloadArgs(
            baseJob(tempDir = "/data/user/0/com.aerotube.youtube_downloader/cache/yt")
        )
        assertEquals(
            "temp:/data/user/0/com.aerotube.youtube_downloader/cache/yt",
            req.optValue("--paths")
        )
    }

    @Test
    fun pathsOmittedWhenTempDirNull() {
        val req = YtDlpRequestFactory.downloadArgs(baseJob(tempDir = null))
        assertFalse(req.hasOpt("--paths"))
    }

    @Test
    fun printToFileAfterMoveEmittedWhenSet() {
        val req = YtDlpRequestFactory.downloadArgs(
            baseJob(printToFile = "/data/user/0/com.aerotube.youtube_downloader/files/final_path.txt")
        )
        // --print-to-file is nargs=2: WHEN:TEMPLATE + FILE (three argv tokens).
        val opt = req.optN("--print-to-file")
        assertTrue("--print-to-file must be OptN (nargs=2)", opt != null)
        assertEquals(
            listOf(
                "after_move:filepath",
                "/data/user/0/com.aerotube.youtube_downloader/files/final_path.txt"
            ),
            opt!!.values
        )
        val argv = req.options.toArgv()
        val idx = argv.indexOf("--print-to-file")
        assertTrue(idx >= 0)
        assertEquals("after_move:filepath", argv[idx + 1])
        assertEquals(
            "/data/user/0/com.aerotube.youtube_downloader/files/final_path.txt",
            argv[idx + 2]
        )
    }

    @Test
    fun printToFileOmittedWhenNull() {
        val req = YtDlpRequestFactory.downloadArgs(baseJob(printToFile = null))
        assertFalse(req.hasOption("--print-to-file"))
    }

    // --- typed pairs / BuiltRequest shape ---

    @Test
    fun urlIsSeparateFromOptions() {
        val req = YtDlpRequestFactory.downloadArgs(baseJob())
        assertEquals("https://www.youtube.com/watch?v=dQw4w9WgXcQ", req.url)
        assertTrue(
            "URL must not appear as an option name or value",
            req.options.none {
                when (it) {
                    is YtDlpArg.Flag -> it.name == req.url
                    is YtDlpArg.Opt -> it.name == req.url || it.value == req.url
                    is YtDlpArg.OptN -> it.name == req.url || it.values.any { v -> v == req.url }
                }
            }
        )
    }

    @Test
    fun allOptsHaveNonEmptyNameAndValue() {
        val req = YtDlpRequestFactory.downloadArgs(
            baseJob(
                ffmpeg = true,
                format = "bestvideo+bestaudio/best",
                subtitleLanguages = listOf("en"),
                embedSubs = true,
                sponsorBlock = true,
                embedThumbnail = true,
                embedMetadata = true,
                cookiesPath = null,
                audioOnly = false,
                targetHeight = null,
                audioQuality = null,
                concurrentFragments = 3,
                tempDir = "/tmp/yt",
                printToFile = "/tmp/path.txt",
            )
        )
        for (opt in req.options) {
            when (opt) {
                is YtDlpArg.Flag ->
                    assertTrue("Flag name must be non-empty", opt.name.isNotEmpty())
                is YtDlpArg.Opt -> {
                    assertTrue("Opt name must be non-empty", opt.name.isNotEmpty())
                    assertTrue(
                        "Opt ${opt.name} value must be non-empty",
                        opt.value.isNotEmpty()
                    )
                }
                is YtDlpArg.OptN -> {
                    assertTrue("OptN name must be non-empty", opt.name.isNotEmpty())
                    assertTrue("OptN ${opt.name} must have values", opt.values.isNotEmpty())
                    assertTrue(
                        "OptN ${opt.name} values must be non-empty",
                        opt.values.all { it.isNotEmpty() }
                    )
                }
            }
        }
    }

    @Test
    fun infoArgsAllOptsHaveNonEmptyNameAndValue() {
        val req = YtDlpRequestFactory.infoArgs(
            "https://youtu.be/abc", null, "UA", fallback = true
        )
        for (opt in req.options) {
            when (opt) {
                is YtDlpArg.Flag -> assertTrue(opt.name.isNotEmpty())
                is YtDlpArg.Opt -> {
                    assertTrue(opt.name.isNotEmpty())
                    assertTrue(opt.value.isNotEmpty())
                }
                is YtDlpArg.OptN -> {
                    assertTrue(opt.name.isNotEmpty())
                    assertTrue(opt.values.isNotEmpty())
                    assertTrue(opt.values.all { it.isNotEmpty() })
                }
            }
        }
    }

    @Test
    fun toArgvFlattensFlagOptAndOptN() {
        val options = listOf(
            YtDlpArg.Flag("--continue"),
            YtDlpArg.Opt("--retries", "10"),
            YtDlpArg.OptN("--print-to-file", listOf("after_move:filepath", "/tmp/p.txt")),
        )
        assertEquals(
            listOf(
                "--continue",
                "--retries", "10",
                "--print-to-file", "after_move:filepath", "/tmp/p.txt",
            ),
            options.toArgv()
        )
    }

    @Test
    fun fullDownloadJobNewFieldsDefaultCompatible() {
        // Old call-site shape (no new fields) must still compile & run.
        val legacy = DownloadJob(
            url = "https://youtu.be/x",
            outputPath = "/out",
            format = null,
            cookiesPath = null,
            userAgent = null,
            archivePath = null,
            subtitleLanguages = null,
            embedSubs = false,
            sponsorBlock = false,
            embedThumbnail = false,
            embedMetadata = false,
            ffmpegAvailable = false,
        )
        assertEquals(false, legacy.audioOnly)
        assertEquals(null, legacy.targetHeight)
        assertEquals(null, legacy.audioQuality)
        assertEquals(null, legacy.concurrentFragments)
        assertEquals(null, legacy.tempDir)
        assertEquals(null, legacy.printToFile)

        val req = YtDlpRequestFactory.downloadArgs(legacy)
        assertEquals("best", req.optValue("-f"))
    }

    // --- infoArgs ---

    @Test
    fun infoArgsIncludeReliabilityAndOptionalFallback() {
        val base = YtDlpRequestFactory.infoArgs(
            "https://youtu.be/abc", null, null, fallback = false
        )
        assertTrue(base.hasFlag("--force-ipv4"))
        assertTrue(base.hasFlag("--no-warnings"))
        assertFalse(base.hasOpt("--extractor-args"))
        assertEquals("10", base.optValue("--retries"))
        assertEquals("https://youtu.be/abc", base.url)

        val fb = YtDlpRequestFactory.infoArgs(
            "https://youtu.be/abc", null, null, fallback = true
        )
        assertEquals("youtube:player_client=web,tv,mweb", fb.optValue("--extractor-args"))
        assertFalse(
            fb.argv().any { it.contains("player_client=android") || it.contains("player_client=ios") }
        )
    }

    @Test
    fun infoArgsUserAgentEmittedWhenPresent() {
        val req = YtDlpRequestFactory.infoArgs(
            "https://youtu.be/abc", null, "MyAgent/1.0", fallback = false
        )
        assertEquals("MyAgent/1.0", req.optValue("--user-agent"))
    }
}
