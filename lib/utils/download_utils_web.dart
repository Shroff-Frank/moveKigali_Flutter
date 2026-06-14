import 'dart:convert';
import 'dart:html' as html;

Future<String?> saveTicketAsFile(String fileName, String content) async {
  final bytes = utf8.encode(content);
  final blob = html.Blob([bytes]);
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.document.createElement('a') as html.AnchorElement;
  anchor.href = url;
  anchor.download = fileName;
  anchor.click();
  html.Url.revokeObjectUrl(url);
  return fileName;
}
