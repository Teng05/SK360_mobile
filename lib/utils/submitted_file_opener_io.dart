import 'package:flutter/services.dart';

class SubmittedFileOpenResult {
  final bool opened;
  final String? message;

  const SubmittedFileOpenResult({required this.opened, this.message});
}

class SubmittedFileOpener {
  static const MethodChannel _channel = MethodChannel('sk360/file_viewer');

  static Future<SubmittedFileOpenResult> open(String url) async {
    try {
      final opened = await _channel.invokeMethod<bool>('openUrl', {'url': url});
      if (opened == true) {
        return const SubmittedFileOpenResult(opened: true);
      }

      return const SubmittedFileOpenResult(
        opened: false,
        message: 'No app was found to view this file.',
      );
    } on MissingPluginException {
      return const SubmittedFileOpenResult(
        opened: false,
        message: 'Restart the app fully after rebuilding, then try again.',
      );
    } on PlatformException catch (exception) {
      return SubmittedFileOpenResult(
        opened: false,
        message: exception.message ?? 'Unable to open submitted file.',
      );
    } catch (_) {
      return const SubmittedFileOpenResult(
        opened: false,
        message: 'Unable to open submitted file on this device.',
      );
    }
  }
}
