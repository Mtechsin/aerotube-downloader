import 'package:flutter/material.dart';
import 'package:webview_windows/webview_windows.dart';
import 'package:url_launcher/url_launcher.dart';

class YoutubeLoginScreen extends StatefulWidget {
  const YoutubeLoginScreen({super.key});

  @override
  State<YoutubeLoginScreen> createState() => _YoutubeLoginScreenState();
}

class _YoutubeLoginScreenState extends State<YoutubeLoginScreen> {
  final _controller = WebviewController();
  bool _isInitialized = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initWebView();
  }

  Future<void> _initWebView() async {
    // final cookieService = context.read<CookieService>();
    // final userDataPath = await cookieService.webViewPath;

    try {
      // Check if WebView2 Runtime is installed
      final webViewVersion = await WebviewController.getWebViewVersion();
      if (webViewVersion == null) {
        if (mounted) {
          setState(() {
            _errorMessage = 'WebView2 Runtime is not installed.\n\n'
                'This is required for YouTube login functionality.\n\n'
                'Please install it from Microsoft\'s website.';
          });
        }
        return;
      }

      await _controller.initialize();
      
      // Listen for URL changes if needed
      _controller.url.listen((url) {
        // Optional: Could detect successful login redirection if desired
      });

      await _controller.loadUrl('https://accounts.google.com/ServiceLogin?service=youtube');
      
      if (mounted) {
        setState(() => _isInitialized = true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to initialize WebView: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.orange,
            ),
            const SizedBox(height: 24),
            Text(
              _errorMessage ?? 'An error occurred',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () async {
                final url = Uri.parse(
                    'https://developer.microsoft.com/en-us/microsoft-edge/webview2/');
                if (await canLaunchUrl(url)) {
                  await launchUrl(url);
                }
              },
              icon: const Icon(Icons.download),
              label: const Text('Download WebView2 Runtime'),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Go Back'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Login to YouTube'),
        actions: [
          if (_isInitialized)
            TextButton(
              onPressed: () {
                // When user says "Done", assume they logged in.
                // The cookies are automatically saved by WebView2 in userDataFolder
                Navigator.pop(context, true);
              },
              child: const Text('Done', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
        ],
      ),
      body: _errorMessage != null
          ? _buildErrorWidget()
          : _isInitialized
              ? Webview(_controller)
              : const Center(child: CircularProgressIndicator()),
    );
  }
}
