import 'package:Spogit/utility.dart';

class CachedPlaylist extends CachedEntity {
  CachedPlaylist(String id, CachedFolder parent) : super(id, parent);

  @override
  String print(int indentation) => '${'  ' * indentation} $id';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is CachedPlaylist &&
              runtimeType == other.runtimeType &&
              id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Playlist[#$id]';
}

class CachedFolder extends CachedEntity {
  final List<CachedEntity> children = [];
  final String name;

  CachedFolder([String id, CachedFolder parent, this.name]) : super(id, parent);

  @override
  String print(int indentation) => """${'  ' * indentation} $name ($id)
${children.map((entity) => entity.print(indentation + 2)).join('\n')}""";

  @override
  String toString() => 'Folder[#$id]';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is CachedFolder &&
              runtimeType == other.runtimeType &&
              id == other.id;

  @override
  int get hashCode => id.hashCode;
}

abstract class CachedEntity {
  final String id;
  final CachedFolder parent;

  List<CachedFolder> get parents {
    var res = <CachedFolder>[];
    var last = parent;
    while (last?.id != null) {
      res.add(last);
      last = last.parent;
    }
    return res;
  }

  CachedEntity(this.id, this.parent);

  String print(int indentation);

  @override
  String toString() => id;
}

extension EntityFlatten on List<CachedEntity> {
  List<CachedPlaylist> get flattenPlaylists =>
      List<CachedPlaylist>.of(expand((entity) => entity is CachedFolder
          ? entity.children.flattenPlaylists
          : [entity])).toList();
}
