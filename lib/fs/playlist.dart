import 'dart:convert';
import 'dart:io';

import 'package:Spogit/fs/contenttype.dart';
import 'package:Spogit/utility.dart';

class SpogitRoot {
  final Directory root;
  final File meta;
  final File coverImage;

  List<SpotifyPlaylist> _playlists;

  List<SpotifyPlaylist> get playlists => _playlists ??= _readPlaylists();

  SpogitRoot(this.root)
      : meta = [root, 'meta.json'].file,
        coverImage = [root, 'cover.png'].file;

  bool isValid() => meta.existsSync();

  List<SpotifyPlaylist> _readPlaylists() => root
      .listSync(recursive: true)
      .whereType<Directory>()
      .map((dir) => SpotifyPlaylist(dir))
      .where((play) => play.isValid)
      .toList();

  void save() {
    _playlists?.forEach((playlist) => playlist.save());
  }
}

class SpotifyPlaylist {
  final Directory root;
  final File coverImage;
  final File _songsFile;
  final File _meta;

  Map<String, dynamic> _metaJson;

  Map<String, dynamic> get meta =>
      _metaJson ??= jsonDecode(_meta.readAsStringSync());

  String get name => meta['name'];

  set name(String value) => meta['name'] = value;

  String get description => meta['description'];

  set description(String value) => meta['description'] = value;

  List<SpotifySong> _songs;

  List<SpotifySong> get songs => _songs ??= readSongs();

  SpotifyPlaylist(this.root)
      : coverImage = [root, 'cover.png'].file,
        _meta = [root, 'meta.json'].file,
        _songsFile = [root, 'songs.md'].file;

  bool get isValid => _meta.existsSync() && _songsFile.existsSync() && ContentType.getType(root) == ContentType.Playlist;

  List<SpotifySong> readSongs() =>
      _songsFile
        .readAsLinesSync()
        .map((line) => SpotifySong.create(line))
        .toList();

  void save() {
    _meta.writeAsStringSync(jsonEncode(meta));

    _songsFile.writeAsStringSync(songs.map((song) => song.toLine()).join('\n'));
  }

  @override
  String toString() {
    return 'SpotifyPlaylist{root: ${root.path}, meta: $meta, songs: $songs}';
  }
}

class SpotifySong {
  String id;

  SpotifySong.create(String line) : id = line.substring(17);

  String toLine() => id;

  @override
  String toString() {
    return 'SpotifySong{id: $id}';
  }
}
