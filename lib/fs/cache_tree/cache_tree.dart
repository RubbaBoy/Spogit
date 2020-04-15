import 'package:Spogit/utility.dart';

class SpotifyPlaylist extends SpotifyEntity {
  SpotifyPlaylist(String id) : super(id);

  @override
  String print(int indentation) => '${'  ' * indentation} $id';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is SpotifyPlaylist &&
              runtimeType == other.runtimeType &&
              id == other.id;

  @override
  int get hashCode => id.hashCode;
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

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is SpotifyFolder &&
              runtimeType == other.runtimeType &&
              listEquals(children, other.children) &&
              id == other.id;

  @override
  int get hashCode => children.hashCode ^ id.hashCode;
}

abstract class SpotifyEntity {
  final String id;

  SpotifyEntity(this.id);

  String print(int indentation);

  @override
  String toString() => id;
}

extension EntityFlatten on List<SpotifyEntity> {
  List<SpotifyPlaylist> get flattenPlaylists =>
      List<SpotifyPlaylist>.of(expand((entity) => entity is SpotifyFolder
          ? entity.children.flattenPlaylists
          : [entity])).toList();
}
