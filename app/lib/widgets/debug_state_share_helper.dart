import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../logic/app_logger.dart';
import '../logic/app_state_exporter.dart';
import '../logic/error_handler.dart';
import '../logic/l10n_extension.dart';
import '../logic/utils/file_downloader/file_downloader.dart';

typedef FileSaver =
    FutureOr<void> Function(String content, String fileName, {String mimeType});

/// Presentation helper for exporting and sharing application state.
class DebugStateShareHelper {
  /// Presents a modal progress dialog, exports state from [exporter],
  /// downloads or shares the resulting JSON file, or falls back to copying
  /// to the clipboard.
  static Future<void> shareDebugState(
    BuildContext context, {
    required AppStateExporter exporter,
    FileSaver? fileSaver,
    ErrorHandler? errorHandler,
    AppLogger? logger,
  }) async {
    if (!context.mounted) return;

    logger?.info('export', 'Debug state export initiated');

    final Completer<BuildContext> dialogContextCompleter =
        Completer<BuildContext>();
    bool isDismissed = false;
    bool isPopped = false;

    void popDialog(BuildContext ctx) {
      if (!isPopped && ctx.mounted) {
        final navigator = Navigator.of(ctx, rootNavigator: true);
        final route = ModalRoute.of(ctx);
        if (navigator.canPop() && (route == null || route.isCurrent)) {
          isPopped = true;
          navigator.pop();
        }
      }
    }

    dialogContextCompleter.future.then((dialogCtx) {
      if (!dialogCtx.mounted) return;
      if (isDismissed) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          popDialog(dialogCtx);
        });
      }
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext ctx) {
        if (isDismissed) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            popDialog(ctx);
          });
        }
        if (!dialogContextCompleter.isCompleted) {
          dialogContextCompleter.complete(ctx);
        }
        return const Center(child: CircularProgressIndicator());
      },
    );

    Future<void> dismissProgressDialog() async {
      if (isDismissed) return;
      isDismissed = true;
      final dialogCtx = await dialogContextCompleter.future;
      if (!dialogCtx.mounted) return;
      popDialog(dialogCtx);
    }

    try {
      try {
        final jsonString = await exporter.exportStateJson(pretty: true);
        logger?.info('export', 'Debug state export completed');
        await dismissProgressDialog();

        if (!context.mounted) return;

        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final fileName = 'debug_app_state_$timestamp.json';

        bool shared = false;
        if (kIsWeb || fileSaver != null) {
          try {
            if (fileSaver != null) {
              await fileSaver(
                jsonString,
                fileName,
                mimeType: 'application/json',
              );
            } else {
              downloadFile(jsonString, fileName, mimeType: 'application/json');
            }
            shared = true;
          } catch (e) {
            debugPrint('Web download failed, falling back to clipboard: $e');
          }
        } else {
          try {
            final RenderBox? box = context.findRenderObject() as RenderBox?;
            final fallbackRect = Rect.fromLTWH(
              0,
              0,
              MediaQuery.maybeOf(context)?.size.width ?? 400,
              (MediaQuery.maybeOf(context)?.size.height ?? 800) / 2,
            );
            final Rect sharePositionOrigin =
                (box != null && box.attached && box.hasSize)
                ? (box.localToGlobal(Offset.zero) & box.size)
                : fallbackRect;

            final tempDir = await getTemporaryDirectory();
            final filePath = '${tempDir.path}/$fileName';
            final tempFile = File(filePath);
            await tempFile.writeAsString(jsonString, flush: true);

            final xFile = XFile(
              filePath,
              mimeType: 'application/json',
              name: fileName,
            );

            if (!context.mounted) return;
            await SharePlus.instance.share(
              ShareParams(
                files: [xFile],
                subject: context.l10n.debugStateShareSubject,
                text: context.l10n.debugStateShareText,
                sharePositionOrigin: sharePositionOrigin,
              ),
            );
            shared = true;
          } catch (e) {
            debugPrint('Share file failed, falling back to clipboard: $e');
          }
        }

        if (!shared) {
          if (!context.mounted) return;
          await Clipboard.setData(ClipboardData(text: jsonString));
          if (!context.mounted) return;
          ScaffoldMessenger.maybeOf(context)?.showSnackBar(
            SnackBar(content: Text(context.l10n.debugStateCopiedToClipboard)),
          );
        }
      } finally {
        await dismissProgressDialog();
      }
    } catch (e, stackTrace) {
      if (!context.mounted) return;
      final handler = errorHandler ?? ErrorHandler();
      final report = handler.report(e, stackTrace: stackTrace);
      handler.showErrorDialog(context, report);
    }
  }
}
