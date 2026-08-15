// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:convert';
import 'dart:html' as html;

/// Initiates a browser file download using a Blob and temporary AnchorElement.
void downloadFile(
  String content,
  String fileName, {
  String mimeType = 'application/json',
}) {
  final bytes = utf8.encode(content);
  final blob = html.Blob([bytes], mimeType);
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)..download = fileName;
  anchor.click();
  html.Url.revokeObjectUrl(url);
}
