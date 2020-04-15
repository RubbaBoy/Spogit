import 'dart:io';

import 'package:Spogit/fs/playlist_tree_parser.dart';

class SpotifyPlaylist extends SpotifyEntity {
  SpotifyPlaylist(String id) : super(id);

  @override
  String print(int indentation) => '${'  ' * indentation} $id';
}

class SpotifyFolder extends SpotifyEntity {
  final List<SpotifyEntity> children = [];
  final String name;
  final SpotifyFolder parent;

  SpotifyFolder([String id, this.name, this.parent]) : super(id);

  @override
  String print(int indentation) => """${'  ' * indentation} $name ($id)
${children.map((entity) => entity.print(indentation + 2)).join('\n')}""";

  @override
  String toString() => print(0);
}

abstract class SpotifyEntity {
  final String id;

  SpotifyEntity(this.id);

  String print(int indentation);
}