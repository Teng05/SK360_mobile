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
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(AppColors.surface)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (progress) {
            if (mounted) setState(() => _progress = progress);
          },
          onPageStarted: (_) {
            if (mounted) setState(() => _failed = false);
          },
          onWebResourceError: (error) {
            if (mounted && error.isForMainFrame == true) {
              setState(() => _failed = true);
            }
          },
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
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.darkGray,
        title: Text(widget.title),
        actions: [
          IconButton(
            tooltip: 'Reload page',
            onPressed: () => _controller.reload(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (_progress < 100)
              LinearProgressIndicator(
                value: _progress / 100,
                minHeight: 3,
                color: AppColors.primaryRed,
                backgroundColor: AppColors.border,
              ),
            Expanded(
              child: _failed
                  ? Center(
                      child: AppEmptyState(
                        icon: Icons.cloud_off_outlined,
                        title: 'Unable to load this page',
                        message: 'Check your connection and try again.',
                        onAction: () => _controller.reload(),
                      ),
                    )
                  : WebViewWidget(controller: _controller),
            ),
          ],
        ),
      ),
    );
  }
}
