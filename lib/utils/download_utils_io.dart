import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

Future<String?> saveTicketAsFile(String fileName, String content) async {
  final directory = await getApplicationDocumentsDirectory();
  final file = File('${directory.path}/$fileName');
  await file.writeAsString(content, encoding: utf8);
  return file.path;
}
