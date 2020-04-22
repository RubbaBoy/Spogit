import 'dart:convert';
import 'dart:io';

import 'package:Spogit/fs/contenttype.dart';
import 'package:Spogit/utility.dart';

class SpogitRoot with SpotifyContainer {
  final Directory root;
  final File meta;
  final File coverImage;

  @override
  SpotifyContainer get parent => null;

  List<Mappable> _playlists = [];

  List<Mappable> get playlists => _playlists.isEmpty ? _playlists = _traverseDir(root) : _playlists;

  SpogitRoot(this.root)
      : meta = [root, 'meta.json'].file..createSync(recursive: true),
        coverImage = [root, 'cover.png'].file;

  bool get isValid => meta.existsSync();

  List<Mappable> _traverseDir(Directory dir) => dir
          .listSync()
          .whereType<Directory>()
          .where((elem) => elem.isMappable)
          .map((dir) {
        if (dir.isPlaylist) {
          return SpotifyPlaylist(dir);
        } else {
          return SpotifyFolder(dir, this, _traverseDir(dir));
        }
      });

  @override
  SpotifyPlaylist addPlaylist(String name) {
    var playlist = SpotifyPlaylist([root, name].directory);
    _playlists?.add(playlist);
    return playlist;
  }

  @override
  SpotifyFolder addFolder(String name) {
    var folder = SpotifyFolder([root, name].directory, this);
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
  final Directory root;
  final File coverImage;
  final File _songsFile;
  final File _meta;

  Map<String, dynamic> _metaJson;

  Map<String, dynamic> get meta =>
      _metaJson ??= tryJsonDecode(_meta.readAsStringSync());

  String get name => meta['name'];

  set name(String value) => meta['name'] = value;

  String get description => meta['description'];

  set description(String value) => meta['description'] = value;

  List<SpotifySong> _songs;

  List<SpotifySong> get songs => _songs ??= readSongs();

  set songs(List<SpotifySong> songs) => _songs = songs;

  SpotifyPlaylist(this.root)
      : coverImage = [root, 'cover.png'].file,
        _meta = [root, 'meta.json'].file..createSync(recursive: true),
        _songsFile = [root, 'songs.md'].file..createSync(recursive: true),
        super(root);

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
  final Directory root;

  @override
  final SpotifyContainer parent;

  List<Mappable> children;

  SpotifyFolder(this.root, this.parent, [List<Mappable> children])
      : children = children ?? <Mappable>[],
        super(root);

  @override
  SpotifyPlaylist addPlaylist(String name) {
    var playlist = SpotifyPlaylist([root, name].directory);
    children?.add(playlist);
    return playlist;
  }

  @override
  SpotifyFolder addFolder(String name) {
    var folder = SpotifyFolder([root, name].directory, this);
    children?.add(folder);
    return folder;
  }

  @override
  void save() {
    print('Playlist ($this) saving ${children?.length ?? 0} children');
    children?.forEach((mappable) => mappable.save());
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
  final File _local;

  Mappable(Directory root)
      : _local = [root, 'local'].file..createSync(recursive: true);

  String _spotifyId;

  String get spotifyId =>
      _spotifyId ??= (tryJsonDecode(_local.readAsStringSync())['id']);

  set spotifyId(String id) =>
      _local.writeAsStringSync(jsonEncode({'id': _spotifyId = id}));

  void save();
}

extension MappableChecker on Directory {
  bool get isPlaylist =>
      [this, 'meta.json'].file.existsSync() &&
      [this, 'songs.md'].file.existsSync() &&
      ContentType.getType(this) == ContentType.Playlist;

  bool get isMappable => [this, 'local'].file.existsSync();
}

/// An object that stores playlists and folders.
abstract class SpotifyContainer {
  SpotifyContainer get parent;

  SpotifyPlaylist addPlaylist(String name);

  SpotifyFolder addFolder(String name);
}
