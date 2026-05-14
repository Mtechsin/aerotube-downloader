import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../../services/cookie_service.dart';
import '../../providers/navigation_provider.dart';
import '../../core/utils/platform_utils.dart';

class WebViewAuthScreen extends StatefulWidget {
  const WebViewAuthScreen({super.key});

  @override
  State<WebViewAuthScreen> createState() => _WebViewAuthScreenState();
}

class _WebViewAuthScreenState extends State<WebViewAuthScreen> {
  InAppWebViewController? _webViewController;
  CookieManager cookieManager = CookieManager.instance();
  bool _isLoading = true;
  double _progress = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Login to YouTube'),
        actions: [
          if (PlatformUtils.isAndroid)
            IconButton(
              icon: const Icon(Icons.home_outlined),
              tooltip: 'Home',
              onPressed: () {
                final nav = context.read<NavigationProvider>();
                Navigator.of(context).popUntil((route) => route.isFirst);
                nav.switchToHome();
              },
            ),
          IconButton(
            icon: const Icon(Icons.done_all),
            tooltip: 'Export Cookies & Close',
            onPressed: () async {
              await _exportCookiesForYtdlp();
              if (mounted) Navigator.pop(context);
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _webViewController?.reload(),
          ),
        ],
      ),
      body: Stack(
        children: [
          InAppWebView(
            initialUrlRequest: URLRequest(
              url: WebUri('https://m.youtube.com'),
            ),
            initialSettings: InAppWebViewSettings(
              javaScriptEnabled: true,
              domStorageEnabled: true,
              cacheEnabled: false, // Disable cache for security
              useWideViewPort: true, // Enable wide viewport
              loadWithOverviewMode: true,
              safeBrowsingEnabled: true, // Enable safe browsing
              mixedContentMode: MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
              thirdPartyCookiesEnabled: true,
              allowsInlineMediaPlayback: true,
              mediaPlaybackRequiresUserGesture: false,
              useShouldOverrideUrlLoading: true,
              // Security settings
              disableDefaultErrorPage: false,
              supportMultipleWindows: false, // Disable multiple windows for security
              javaScriptCanOpenWindowsAutomatically: false,
              // Use modern Chrome user agent (Android 14 + Chrome 124)
              userAgent:
                  'Mozilla/5.0 (Linux; Android 14; Pixel 7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36',
            ),
            onWebViewCreated: (controller) {
              _webViewController = controller;
            },
            onLoadStart: (controller, url) {
              setState(() {
                _isLoading = true;
                _progress = 0;
              });
            },
            onLoadStop: (controller, url) async {
              setState(() {
                _isLoading = false;
              });
            },
            onProgressChanged: (controller, progress) {
              setState(() {
                _progress = progress / 100;
              });
            },
            shouldOverrideUrlLoading: (controller, navigationAction) async {
              final url = navigationAction.request.url;
              if (url != null && url.host.contains('accounts.google.com')) {
                return NavigationActionPolicy.ALLOW;
              }
              return NavigationActionPolicy.ALLOW;
            },
          ),
          if (_progress < 1.0) LinearProgressIndicator(value: _progress),
        ],
      ),
    );
  }

  Future<void> _exportCookiesForYtdlp() async {
    try {
      final youtubeCookies = await cookieManager.getCookies(
        url: WebUri('https://.youtube.com'),
      );
      final googleCookies = await cookieManager.getCookies(
        url: WebUri('https://.google.com'),
      );

      final allCookies = [...youtubeCookies, ...googleCookies];
      final cookieLines = <String>[];

      // Netscape cookie file format that yt-dlp understands
      for (final cookie in allCookies) {
        if (cookie.name.isEmpty || cookie.value.isEmpty) continue;

        final domain = cookie.domain ?? '.youtube.com';
        final path = cookie.path ?? '/';
        final secure = (cookie.isSecure ?? false) ? 'TRUE' : 'FALSE';
        final expiry = cookie.expiresDate;
        int expirySeconds = 0;
        if (expiry != null) {
          expirySeconds = expiry ~/ 1000;
        }
        final expiryStr = expirySeconds.toString();

        cookieLines.add(
          '${domain.startsWith('.') ? '' : '.'}$domain\tTRUE\t$path\t$secure\t$expiryStr\t${cookie.name}\t${cookie.value}',
        );
      }

      final dir = await getApplicationSupportDirectory();
      final cookiePath = p.join(dir.path, 'cookies.txt');
      final cookieFile = File(cookiePath);

      final content = [
        '# Netscape HTTP Cookie File',
        '# https://curl.haxx.se/docs/http-cookies.html',
        '# This file was generated by youtube downloader',
        '# Exported at: ${DateTime.now().toIso8601String()}',
        '',
        ...cookieLines,
        '',
      ].join('\n');

      await cookieFile.writeAsString(content);

      // Update cookie service
      final cookieService = CookieService();
      await cookieService.init();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Successfully exported ${cookieLines.length} cookies'),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to export cookies: $e')));
      }
    }
  }

  @override
  void dispose() {
    super.dispose();
  }
}
