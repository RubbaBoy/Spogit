import 'dart:convert';
import 'dart:io';

import 'package:Spogit/utility.dart';

class SpogitRoot with SpotifyContainer {
  final Directory root;
  final File meta;
  final File coverImage;

  @override
  SpotifyContainer get parent => null;

  List<Mappable> _playlists;

  List<Mappable> get playlists => _playlists ??= _traverseDir(root, null);

  SpogitRoot(this.root)
      : meta = [root, 'meta.json'].file..createSync(recursive: true),
        coverImage = [root, 'cover.png'].file {
    playlists;
  }

  bool get isValid => meta.existsSync();

  List<Mappable> _traverseDir(Directory dir, SpotifyFolder parent) {
    print('traversing $dir');
    return dir
          .listSync()
          .whereType<Directory>()
          .map((dir) {
            var name = dir.uri.realName;
            print('name = $name');
      if (dir.isPlaylist) {
          return SpotifyPlaylist(name, dir.parent, parent);
        } else {
          final folder = SpotifyFolder(name, dir.parent, parent);
          folder.children = _traverseDir(dir, folder);
          return folder;
        }
      }).toList();
  }

  @override
  SpotifyPlaylist addPlaylist(String name) {
    var playlist = SpotifyPlaylist(name, root);
    _playlists?.add(playlist);
    return playlist;
  }

  @override
  SpotifyFolder addFolder(String name) {
    var folder = SpotifyFolder(name, root, this);
    _playlists?.add(folder);
    return folder;
  }

  void save() {
    print('Root: Saving ${_playlists?.length ?? 0} items');
    _playlists?.forEach((playlist) => playlist.save());
  }

  @override
  String toString() {
    return 'SpogitRoot{root: $root, meta: $meta, coverImage: $coverImage, _playlists: $_playlists}';
  }
}

class SpotifyPlaylist extends Mappable {
  final File coverImage;
  final File _songsFile;
  final File _meta;

  @override
  final SpotifyFolder parent;

  Map<String, dynamic> _metaJson;

  Map<String, dynamic> get meta =>
      _metaJson ??= {...tryJsonDecode(_meta.readAsStringSync())};

  @override
  String get name => _metaJson['name'];

  set name(String value) => _metaJson['name'] = value;

  String get description => _metaJson['description'];

  set description(String value) => _metaJson['description'] = value;

  List<SpotifySong> _songs;

  List<SpotifySong> get songs => _songs ??= readSongs();

  set songs(List<SpotifySong> songs) => _songs = songs;

  /// The [name] is the name of the playlist. The [parentDirectory] is the
  /// filesystem directory of what this playlist's folder will be contained in.
  /// The [parentFolder] is the [SpotifyFolder] of the parent, this may be null.
  SpotifyPlaylist(String name, Directory parentDirectory, [SpotifyFolder parentFolder])
      : parent = parentFolder,
        coverImage = [parentDirectory, name, 'cover.png'].file,
        _meta = [parentDirectory, name, 'meta.json'].file..createSync(recursive: true),
        _songsFile = [parentDirectory, name, 'songs.md'].file..createSync(recursive: true),
        super([parentDirectory, name].directory) {
    meta;
  }

  List<SpotifySong> readSongs() => _songsFile
      .readAsLinesSync()
      .map((line) => SpotifySong.create(line))
      .toList();

  @override
  void save() {
    print('Saving $this');
    _meta.writeAsStringSync(jsonEncode(meta));

    _songsFile.writeAsStringSync(songs.map((song) => song.toLine()).join('\n'));
  }

  @override
  String toString() {
    return 'SpotifyPlaylist{root: ${root.path}, meta: $meta, songs: $songs}';
  }
}

class SpotifyFolder extends Mappable with SpotifyContainer {

  @override
  String get name => root.uri.realName;

  @override
  final SpotifyContainer parent;

  List<Mappable> children;

  SpotifyFolder(String name, Directory parentDirectory, this.parent, [List<Mappable> children])
      : children = children ?? <Mappable>[],
        super([parentDirectory, name].directory);

  @override
  SpotifyPlaylist addPlaylist(String name) {
    var playlist = SpotifyPlaylist(name, root, this);
    children?.add(playlist);
    return playlist;
  }

  @override
  SpotifyFolder addFolder(String name) {
    var folder = SpotifyFolder(name, root, this);
    children?.add(folder);
    return folder;
  }

  @override
  void save() {
    print('Playlist ($this) saving ${children?.length ?? 0} children');
    children?.forEach((mappable) => mappable.save());
  }

  @override
  String toString() {
    return 'SpotifyFolder{root: $root, children: $children}';
  }
}

class SpotifySong {
  String id;

//  SpotifySong.create(String line) : id = line.substring(17);
  SpotifySong.create(String line) : id = line {
    print('creating with $line');
  }

  String toLine() => id;

  @override
  String toString() {
    return 'SpotifySong{id: $id}';
  }
}

abstract class Mappable {
  final Directory root;
  final File _local;

  Mappable(this.root)
      : _local = [root, 'local'].file..createSync(recursive: true);

  String get name;

  SpotifyContainer get parent;

  String _spotifyId;

  String get spotifyId =>
      _spotifyId ??= access(tryJsonDecode(_local.readAsStringSync()), 'id') as String;

  set spotifyId(String id) =>
      _local.writeAsStringSync(jsonEncode({'id': _spotifyId = id}));

  void save();
}

extension MappableChecker on Directory {
  bool get isPlaylist =>
      [this, 'meta.json'].file.existsSync() &&
      [this, 'songs.md'].file.existsSync();
}

/// An object that stores playlists and folders.
abstract class SpotifyContainer {
  SpotifyContainer get parent;

  SpotifyPlaylist addPlaylist(String name);

  SpotifyFolder addFolder(String name);
}
