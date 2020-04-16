import 'dart:io';

import 'package:Spogit/utility.dart';

class ContentType {
  static const ContentType Root = ContentType._('Root');
//  static const ContentType Folder = ContentType._('Folder');
  static const ContentType Playlist = ContentType._('Playlist');

  static const values = <ContentType>[Root, Playlist];

  final String type;

  const ContentType._(this.type);

  static ContentType getType(Directory directory) {
    var file = [directory, 'meta.json'].file;
    if (!file.existsSync()) {
      return null;
    }

    var typeJson = tryJsonDecode(file.readAsStringSync())['type'];
    if (typeJson == null) {
      return null;
    }

    return ContentType.values.firstWhere((value) => value.type == typeJson, orElse: () => null);
  }

  @override
  String toString() {
    return 'ContentType{type: $type}';
  }
}
