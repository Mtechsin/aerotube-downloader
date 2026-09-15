package com.aerotube.youtube_downloader;

import java.io.File;
import java.util.HashMap;
import java.util.Map;

public class MimeTypeResolutionTest {

    public static String getExtension(File file) {
        String name = file.getName();
        int idx = name.lastIndexOf('.');
        return (idx == -1) ? "" : name.substring(idx + 1);
    }

    public static String resolveMimeType(File file) {
        String ext = getExtension(file).toLowerCase();
        return switch (ext) {
            case "mp4" -> "video/mp4";
            case "mkv" -> "video/x-matroska";
            case "webm" -> "video/webm";
            case "m4a" -> "audio/mp4";
            case "mp3" -> "audio/mpeg";
            case "opus" -> "audio/opus";
            case "aac" -> "audio/aac";
            case "ogg" -> "audio/ogg";
            case "wav" -> "audio/wav";
            case "flac" -> "audio/flac";
            case "ts" -> "video/mp2t";
            case "mov" -> "video/quicktime";
            case "avi" -> "video/x-msvideo";
            case "3gp" -> "video/3gpp";
            case "apk" -> "application/vnd.android.package-archive";
            default -> "*/*";
        };
    }

    public static void main(String[] args) {
        int passed = 0;
        int failed = 0;

        Map<String, String> testCases = new HashMap<>();
        // 1. Lowercase standard media
        testCases.put("/storage/emulated/0/Download/AeroTube/video.mp4", "video/mp4");
        testCases.put("/storage/emulated/0/Download/AeroTube/movie.mkv", "video/x-matroska");
        testCases.put("/storage/emulated/0/Download/AeroTube/stream.webm", "video/webm");
        testCases.put("/storage/emulated/0/Download/AeroTube/podcast.m4a", "audio/mp4");
        testCases.put("/storage/emulated/0/Download/AeroTube/track.mp3", "audio/mpeg");
        testCases.put("/storage/emulated/0/Download/AeroTube/voice.opus", "audio/opus");
        testCases.put("/storage/emulated/0/Download/AeroTube/hifi.flac", "audio/flac");
        testCases.put("/storage/emulated/0/Download/AeroTube/audio.aac", "audio/aac");
        testCases.put("/storage/emulated/0/Download/AeroTube/audio.ogg", "audio/ogg");
        testCases.put("/storage/emulated/0/Download/AeroTube/audio.wav", "audio/wav");
        testCases.put("/storage/emulated/0/Download/AeroTube/stream.ts", "video/mp2t");
        testCases.put("/storage/emulated/0/Download/AeroTube/clip.mov", "video/quicktime");
        testCases.put("/storage/emulated/0/Download/AeroTube/movie.avi", "video/x-msvideo");
        testCases.put("/storage/emulated/0/Download/AeroTube/cell.3gp", "video/3gpp");
        testCases.put("/storage/emulated/0/Download/AeroTube/app.apk", "application/vnd.android.package-archive");

        // 2. Uppercase extensions
        testCases.put("/storage/emulated/0/Download/AeroTube/VIDEO.MP4", "video/mp4");
        testCases.put("/storage/emulated/0/Download/AeroTube/MOVIE.MKV", "video/x-matroska");
        testCases.put("/storage/emulated/0/Download/AeroTube/STREAM.WEBM", "video/webm");
        testCases.put("/storage/emulated/0/Download/AeroTube/PODCAST.M4A", "audio/mp4");
        testCases.put("/storage/emulated/0/Download/AeroTube/TRACK.MP3", "audio/mpeg");
        testCases.put("/storage/emulated/0/Download/AeroTube/VOICE.OPUS", "audio/opus");
        testCases.put("/storage/emulated/0/Download/AeroTube/HIFI.FLAC", "audio/flac");
        testCases.put("/storage/emulated/0/Download/AeroTube/AUDIO.AAC", "audio/aac");
        testCases.put("/storage/emulated/0/Download/AeroTube/AUDIO.OGG", "audio/ogg");
        testCases.put("/storage/emulated/0/Download/AeroTube/AUDIO.WAV", "audio/wav");

        // 3. Mixed case extensions
        testCases.put("/storage/emulated/0/Download/AeroTube/video.Mp4", "video/mp4");
        testCases.put("/storage/emulated/0/Download/AeroTube/track.Mp3", "audio/mpeg");
        testCases.put("/storage/emulated/0/Download/AeroTube/voice.OpUs", "audio/opus");
        testCases.put("/storage/emulated/0/Download/AeroTube/lossless.FlAc", "audio/flac");

        // 4. Unknown extensions
        testCases.put("/storage/emulated/0/Download/AeroTube/file.xyz123", "*/*");
        testCases.put("/storage/emulated/0/Download/AeroTube/file.unknown", "*/*");
        testCases.put("/storage/emulated/0/Download/AeroTube/file.bin", "*/*");
        testCases.put("/storage/emulated/0/Download/AeroTube/file.dat", "*/*");
        testCases.put("/storage/emulated/0/Download/AeroTube/file.UNKNOWN_EXT", "*/*");

        // 5. No extension
        testCases.put("/storage/emulated/0/Download/AeroTube/download_without_extension", "*/*");
        testCases.put("/storage/emulated/0/Download/AeroTube/README", "*/*");

        // 6. Multiple dots
        testCases.put("/storage/emulated/0/Download/AeroTube/Rick.Astley.Never.Gonna.Give.You.Up.1080p.mp4", "video/mp4");
        testCases.put("/storage/emulated/0/Download/AeroTube/Track.01.Remix.v2.FLAC", "audio/flac");
        testCases.put("/storage/emulated/0/Download/AeroTube/audio.track.final.opus", "audio/opus");

        // 7. Trailing dot
        testCases.put("/storage/emulated/0/Download/AeroTube/file_with_trailing_dot.", "*/*");

        // 8. Hidden dotfile
        testCases.put("/storage/emulated/0/Download/AeroTube/.mp4", "video/mp4");
        testCases.put("/storage/emulated/0/Download/AeroTube/.opus", "audio/opus");

        // 9. Folder with dot in name but file has no extension
        testCases.put("/storage/emulated/0/Download/AeroTube/v1.0.release/untyped_file", "*/*");

        // 10. Folder with dot in name and file has extension
        testCases.put("/storage/emulated/0/Download/AeroTube/v1.0.release/sample.mkv", "video/x-matroska");

        System.out.println("Running empirical MIME type resolution test suite (" + testCases.size() + " test cases)...");

        for (Map.Entry<String, String> entry : testCases.entrySet()) {
            File f = new File(entry.getKey());
            String expected = entry.getValue();
            String actual = resolveMimeType(f);

            if (expected.equals(actual)) {
                passed++;
            } else {
                failed++;
                System.err.println("FAIL: " + f.getName() + " -> expected '" + expected + "', got '" + actual + "'");
            }
        }

        System.out.println("Result: " + passed + " PASSED, " + failed + " FAILED out of " + testCases.size() + " tests.");
        if (failed > 0) {
            System.exit(1);
        }
    }
}
