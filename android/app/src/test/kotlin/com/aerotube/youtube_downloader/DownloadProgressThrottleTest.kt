package com.aerotube.youtube_downloader

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Pure JVM tests for the DownloadService notification throttle.
 *
 * [shouldEmitProgressNotification] is a top-level pure function so these
 * tests never load the Android [DownloadService] class (Service, Log, etc.).
 *
 * Integration-only paths intentionally NOT unit-tested here:
 * - [YtDlpEngine.cancel] / cancelledIds: depends on the YoutubeDL singleton
 *   and android.util.Log; covered by instrumented/integration runs only.
 * - DownloadService.updateNotification / startForeground: Android framework.
 * - YtDlpEngine.buildRequest pairing: private, owned by YtDlpEngine; flag
 *   pairing rules are documented there. Factory argv tests live in
 *   [YtDlpRequestFactoryTest].
 */
class DownloadProgressThrottleTest {

    @Test
    fun firstSampleAlwaysEmits() {
        assertTrue(
            shouldEmitProgressNotification(
                lastProgress = null,
                lastTimeMs = null,
                progress = 0.05f,
                nowMs = 1_000L,
            )
        )
    }

    @Test
    fun firstSampleWithZeroLastTimeStillEmits() {
        // lastProgress present but lastTimeMs null => treated as first sample
        assertTrue(
            shouldEmitProgressNotification(
                lastProgress = 0f,
                lastTimeMs = null,
                progress = 0.01f,
                nowMs = 5_000L,
            )
        )
    }

    @Test
    fun suppressesTinyDeltaWithinOneSecondWindow() {
        // Emitted 0.5s ago at 10.0%; new tick is 10.4% (< 1pp delta)
        assertFalse(
            shouldEmitProgressNotification(
                lastProgress = 0.10f,
                lastTimeMs = 10_000L,
                progress = 0.104f,
                nowMs = 10_500L,
            )
        )
    }

    @Test
    fun emitsWhenIntervalElapsesEvenWithTinyDelta() {
        // 1.0s elapsed, same-ish progress
        assertTrue(
            shouldEmitProgressNotification(
                lastProgress = 0.10f,
                lastTimeMs = 10_000L,
                progress = 0.101f,
                nowMs = 11_000L,
            )
        )
    }

    @Test
    fun emitsWhenDeltaReachesOnePercentagePointWithinWindow() {
        // 0.3s elapsed but progress jumped 1.5pp
        assertTrue(
            shouldEmitProgressNotification(
                lastProgress = 0.20f,
                lastTimeMs = 20_000L,
                progress = 0.215f,
                nowMs = 20_300L,
            )
        )
    }

    @Test
    fun jumpAtOrAboveMinDeltaEmits() {
        // Binary32 cannot represent "exactly 1.00 percentage point" from most
        // bases: 0.51f - 0.50f is slightly UNDER 0.01f. The production
        // threshold is therefore tested with a clear margin above 1pp.
        assertTrue(
            shouldEmitProgressNotification(
                lastProgress = 0.50f,
                lastTimeMs = 1L,
                progress = 0.515f, // +1.5pp — safely >= 0.01f in float32
                nowMs = 2L,
            )
        )
    }

    @Test
    fun justUnderOnePercentagePointSuppressesWithinWindow() {
        // 0.99pp — below threshold
        assertFalse(
            shouldEmitProgressNotification(
                lastProgress = 0.50f,
                lastTimeMs = 1L,
                progress = 0.5099f,
                nowMs = 2L,
            )
        )
    }

    @Test
    fun completionAlwaysEmitsRegardlessOfThrottle() {
        // 0.2s since last emit, progress jumped to 1.0
        assertTrue(
            shouldEmitProgressNotification(
                lastProgress = 0.99f,
                lastTimeMs = 100_000L,
                progress = 1.0f,
                nowMs = 100_200L,
            )
        )
    }

    @Test
    fun progressAboveOneTreatedAsComplete() {
        assertTrue(
            shouldEmitProgressNotification(
                lastProgress = 0.5f,
                lastTimeMs = 0L,
                progress = 1.05f,
                nowMs = 10L,
            )
        )
    }

    @Test
    fun backwardsProgressWithinWindowSuppresses() {
        // Rare glitch: progress reported slightly lower (e.g. playlist item
        // boundary). Within the window and |delta| < 1pp => no notify.
        assertFalse(
            shouldEmitProgressNotification(
                lastProgress = 0.40f,
                lastTimeMs = 50_000L,
                progress = 0.395f,
                nowMs = 50_400L,
            )
        )
    }

    @Test
    fun backwardsProgressByFullPointEmits() {
        // Large regression should refresh the notification
        assertTrue(
            shouldEmitProgressNotification(
                lastProgress = 0.40f,
                lastTimeMs = 50_000L,
                progress = 0.39f,
                nowMs = 50_400L,
            )
        )
    }

    @Test
    fun burstOfTicksWithinWindowOnlyAllowsFirstAndDeltaJumps() {
        // Simulate a burst of tiny ticks after the first sample.
        // Null last-state means "no emit yet" — the helper always emits once.
        var lastP: Float? = null
        var lastT: Long? = null
        var emissions = 0
        var now = 1_000L
        var progress = 0.50f

        // First sample of session — must emit
        if (shouldEmitProgressNotification(lastP, lastT, progress, now)) {
            emissions++
            lastP = progress
            lastT = now
        }
        assertEqualsOne(emissions)

        // 10 ticks of +0.05pp every 50ms — all suppressed
        for (i in 1..10) {
            now += 50L
            progress += 0.0005f
            if (shouldEmitProgressNotification(lastP, lastT, progress, now)) {
                emissions++
                lastP = progress
                lastT = now
            }
        }
        assertEqualsOne(emissions) // still 1

        // Jump +1.2pp — emits
        progress += 0.012f
        now += 50L
        if (shouldEmitProgressNotification(lastP, lastT, progress, now)) {
            emissions++
            lastP = progress
            lastT = now
        }
        assertTrue(emissions == 2)

        // Another 200ms of tiny ticks — suppressed
        for (i in 1..4) {
            now += 50L
            progress += 0.0001f
            if (shouldEmitProgressNotification(lastP, lastT, progress, now)) {
                emissions++
                lastP = progress
                lastT = now
            }
        }
        assertTrue(emissions == 2)

        // Cross the 1s boundary — emits on time
        now = (lastT ?: 0L) + 1_000L
        if (shouldEmitProgressNotification(lastP, lastT, progress, now)) {
            emissions++
        }
        assertTrue(emissions == 3)
    }

    private fun assertEqualsOne(value: Int) {
        assertTrue("expected 1 emission, got $value", value == 1)
    }
}
