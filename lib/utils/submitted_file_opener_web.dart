import 'package:web/web.dart' as web;

class SubmittedFileOpenResult {
  final bool opened;
  final String? message;

  const SubmittedFileOpenResult({required this.opened, this.message});
}

class SubmittedFileOpener {
  static Future<SubmittedFileOpenResult> open(String url) async {
    web.window.open(url, '_blank');
    return const SubmittedFileOpenResult(opened: true);
  }
}
