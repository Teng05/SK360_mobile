import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import '../../ui/app_ui.dart';

class MeetingWebViewScreen extends StatefulWidget {
  final String url;
  final String title;

  const MeetingWebViewScreen({
    super.key,
    required this.url,
    required this.title,
  });

  @override
  State<MeetingWebViewScreen> createState() => _MeetingWebViewScreenState();
}

class _MeetingWebViewScreenState extends State<MeetingWebViewScreen> {
  late final WebViewController _controller;
  int _progress = 0;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF111111))
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (progress) => setState(() => _progress = progress),
        ),
      );

    _configureAndLoad();
  }

  Future<void> _configureAndLoad() async {
    final platform = _controller.platform;
    if (platform is AndroidWebViewController) {
      await platform.setMediaPlaybackRequiresUserGesture(false);
      await platform.setOnPlatformPermissionRequest((request) {
        request.grant();
      });
    }
    await _controller.loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF111111),
      appBar: AppBar(
        backgroundColor: AppColors.primaryRed,
        foregroundColor: Colors.white,
        title: Text(widget.title),
      ),
      body: Column(
        children: [
          if (_progress < 100)
            LinearProgressIndicator(
              value: _progress / 100,
              minHeight: 3,
              color: Colors.white,
              backgroundColor: AppColors.primaryRed,
            ),
          Expanded(child: WebViewWidget(controller: _controller)),
        ],
      ),
    );
  }
}
