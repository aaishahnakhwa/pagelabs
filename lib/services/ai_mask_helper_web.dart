// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'package:flutter/foundation.dart';
import '../models/mask_result.dart';

Future<MaskResult?> getWebAiMask(Uint8List imageBytes) async {
  try {
    final base64Str = base64Encode(imageBytes);
    final dataUri = 'data:image/png;base64,$base64Str';

    final completer = Completer<MaskResult?>();

    late html.EventListener listener;
    listener = (html.Event event) {
      if (event is html.CustomEvent) {
        html.window.removeEventListener('ai_mask_ready', listener);
        final detail = event.detail;
        if (detail == null) {
          completer.complete(null);
          return;
        }

        try {
          final width = (detail['width'] as num).toInt();
          final height = (detail['height'] as num).toInt();
          final List<dynamic> maskList = detail['mask'] as List<dynamic>;

          final dartMask = Uint8List(width * height);
          for (int i = 0; i < dartMask.length; i++) {
            dartMask[i] = (maskList[i] as num).toInt();
          }

          completer.complete(MaskResult(
            maskBytes: dartMask,
            width: width,
            height: height,
          ));
        } catch (err) {
          debugPrint('Error parsing CustomEvent detail: $err');
          completer.complete(null);
        }
      }
    };

    html.window.addEventListener('ai_mask_ready', listener);

    // Dispatch request event to trigger window.processAiBackgroundRemoval in index.html
    html.window.dispatchEvent(html.CustomEvent('start_ai_mask', detail: dataUri));

    return await completer.future.timeout(
      const Duration(seconds: 12),
      onTimeout: () {
        html.window.removeEventListener('ai_mask_ready', listener);
        debugPrint('MediaPipe segmentation timed out');
        return null;
      },
    );
  } catch (e) {
    debugPrint('MediaPipe web event exception: $e');
    return null;
  }
}
