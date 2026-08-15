/// Platform-agnostic stub for downloading a file.
void downloadFile(
  String content,
  String fileName, {
  String mimeType = 'application/json',
}) {
  // No-op on non-web platforms.
}
