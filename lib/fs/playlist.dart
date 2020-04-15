import 'dart:convert';
import 'dart:io';

import 'package:Spogit/utility.dart';
import 'package:Spogit/fs/contenttype.dart';

class SpogitRoot {
  final Directory root;
  final File meta;
  final File coverImage;

  List<SpotifyPlaylist> _playlists;

  List<SpotifyPlaylist> get playlists => _playlists ??= readPlaylists();

  SpogitRoot(this.root)
      : meta = [root, 'meta.json'].file,
        coverImage = [root, 'cover.png'].file;

  bool isValid() => meta.existsSync();

  List<SpotifyPlaylist> readPlaylists() {
    return root.listSync(recursive: true)
          .whereType<Directory>()
          .map((dir) => SpotifyPlaylist(dir))
          .where((play) => play != null);
  }

  void save() {

  }
}

class SpotifyFolder extends Metable {
  final Directory root;

  SpotifyFolder(this.root) :
        super([root, 'meta.json'].file, ContentType.Folder);
}

class SpotifyPlaylist extends Metable {
  final Directory root;
  final File coverImage;
  final File _songsFile;

  List<SpotifySong> _songs;

  List<SpotifySong> get songs => _songs ??= readSongs();

  SpotifyPlaylist(this.root)
      : coverImage = [root, 'cover.png'].file,
        _songsFile = [root, 'songs.md'].file,
        super([root, 'meta.json'].file, ContentType.Playlist);

  bool isValid() =>
    ContentType.getType(root) == ContentType.Playlist;

  List<SpotifySong> readSongs() {
    return _songsFile
        .readAsLinesSync()
        .map((line) => SpotifySong.create(line))
        .toList();
  }

  void save() {
    _meta.writeAsStringSync(jsonEncode(meta));

    _songsFile.writeAsStringSync(songs.map((song) => song.toLine()).join('\n'));
  }
}

class SpotifySong {
  String id;

  SpotifySong.create(String line) : id = line;

  String toLine() => id;
}

abstract class Metable {
  final File _meta;
  final ContentType type;
  Map<String, dynamic> _metaJson;

  Map<String, dynamic> get meta =>
      _metaJson ??= jsonDecode(_meta.readAsStringSync());

  String get name => meta['name'];

  set name(String value) => meta['name'] = value;

  String get description => meta['description'];

  set description(String value) => meta['description'] = value;

  Metable(this._meta, this.type);
}
