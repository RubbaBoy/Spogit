import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:Spogit/driver/playlist_manager.dart';
import 'package:Spogit/fs/local_storage.dart';
import 'package:Spogit/utility.dart';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

class SpogitRoot with SpotifyContainer {
  final RootLocal rootLocal;
  final File meta;
  final File coverImage;

  @override
  final Directory root;

  @override
  SpotifyContainer get parent => null;

  List<Mappable> _children;

  @override
  List<Mappable> get children => _children ??= _traverseDir(root, null);

  SpogitRoot(this.root,
      {bool creating = false, List<String> tracking = const []})
      : rootLocal = RootLocal([root, 'local'].file),
        meta = [root, 'meta.json'].file..tryCreateSync(),
        coverImage = [root, 'cover.png'].file {
    children;
    if (creating) {
      rootLocal
        ..id = randomHex(16)
        ..tracking = tracking;
    }
  }

  bool get isValid => meta.existsSync();

  List<Mappable> _traverseDir(Directory dir, SpotifyFolder parent) => dir.listSync().whereType<Directory>().where((dir) => !dir.uri.realName.startsWith('.')).map((dir) {
        var name = dir.uri.realName;
        if (dir.isPlaylist) {
          return SpotifyPlaylist(name, dir.parent, parent);
        } else {
          final folder = SpotifyFolder(name, dir.parent, parent);
          folder.children = _traverseDir(dir, folder);
          return folder;
        }
      }).toList();

  void save() {
    rootLocal.saveFile();
    _children?.forEach((playlist) async => await playlist.save());
  }

  @override
  String toString() {
    return 'SpogitRoot{root: $root, meta: $meta, coverImage: $coverImage, _playlists: $_children}';
  }
}

/// Information in the `local` file in the stored Root with an identifier and
/// the playlists/folders used. All but the ID are mutable.
class RootLocal extends LocalStorage {
  RootLocal(File file) : super(file);

  String _id;

  /// The randomized, local ID used to identify this.
  String get id => _id ??= this['id'];

  set id(String value) => this['id'] = value;

  List<String> _tracking;

  /// The IDs of the things that are being tracked.
  List<String> get tracking =>
      _tracking ??= List<String>.from(this['tracking']);

  set tracking(List<String> value) => this['tracking'] = value;

  String _revision;

  /// The ETag of the last base revision used.
  String get revision => _revision ??= this['revision'];

  set revision(String value) => this['revision'] = value;
}

class SpotifyPlaylist extends Mappable {
  final File coverImage;
  final File _songsFile;
  final File _meta;

  String _imageUrl;

  set imageUrl(String url) {
    print('url = $url');
    if (url != null && url != _imageUrl) {
      print('CHANBGING!!!!');
      _imageUrl = url;
      imageChanged = true;
    }
  }

  bool imageChanged = false;
  int songsHash = 0;
  int metaHash = 0;

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
  SpotifyPlaylist(String name, Directory parentDirectory,
      [SpotifyFolder parentFolder])
      : parent = parentFolder,
        coverImage = [parentDirectory, name, 'cover.png'].file,
        _meta = [parentDirectory, name, 'meta.json'].file
          ..createSync(recursive: true),
        _songsFile = [parentDirectory, name, 'songs.md'].file
          ..createSync(recursive: true),
        super([parentDirectory, name].directory) {
    meta;
  }

  List<SpotifySong> readSongs() => _songsFile
      .readAsLinesSync()
      .map((line) => SpotifySong.fromLine(line))
      .notNull()
      .toList();

  @override
  Future<void> save() async {
    await super.save();

    var currMetaHash = _metaJson?.customHash;
    if (metaHash == 0 || metaHash != currMetaHash) {
      metaHash = currMetaHash;
      _meta
        ..tryCreateSync()
        ..writeAsStringSync(jsonEncode(meta));
    }

    var currSongsHash = _songs?.customHash;
    if (songsHash == 0 || songsHash != currSongsHash) {
      songsHash = currSongsHash;
      _songsFile
        ..tryCreateSync()
        ..writeAsStringSync(songs.map((song) => song.toLine()).join('\n\n'));
    }

    if (imageChanged) {
      imageChanged = false;
      coverImage.writeAsBytesSync(await http.get(_imageUrl).then((res) => res.bodyBytes));
    }
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

  @override
  List<Mappable> children;

  SpotifyFolder(String name, Directory parentDirectory, this.parent,
      [List<Mappable> children])
      : children = children ?? <Mappable>[],
        super([parentDirectory, name].directory);

  @override
  Future<void> save() async {
    await super.save();

    children?.forEach((mappable) async => await mappable.save());
  }

  @override
  String toString() {
    return 'SpotifyFolder{root: $root, children: $children}';
  }
}

class SpotifySong {
  static final RegExp linkRegex =
      RegExp(r'\[([^\\]*)\]\(.*?spotify:track:([a-zA-Z0-9]{22})\)');

  final String id;
  final String artistLine;

  /// Creates a SpotifySong from individual pieces. The [id] should be a parsed
  /// track ID.
  SpotifySong(this.id, String artistName, String songName)
      : artistLine = '$songName - $artistName' {
    print('Artistline = $artistLine');
  }

  /// Creates a SpotifySong from a single track json element.
  SpotifySong.fromJson(Map<String, dynamic> json) :
        id = json['track']['id'],
        artistLine = '${parseArtists(json['track'])} - ${json['track']['name']}';

  /// The [id] should be the parsed track ID, and the [artistName] is the full
  /// `Song - Artist` unparsed line from an existing link.
  SpotifySong._create(this.id, this.artistLine);

  /// Example of a song chunk:
  /// ```
  /// [Crazy - Gnarls Barkley](https://open.spotify.com/go?uri=spotify:track:2N5zMZX7YeL1tico8oQxa9)
  /// ```
  factory SpotifySong.fromLine(String songChunk) {
    var matches = linkRegex.allMatches(songChunk);
    if (matches.isEmpty) {
      return null;
    }

    print('Creating from $songChunk');

    var match = matches.first;
    return SpotifySong._create(match.group(2), match.group(1));
  }

  String toLine() =>
      '[$artistLine](https://open.spotify.com/go?uri=spotify:track:$id)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SpotifySong &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'SpotifySong{id: $id}';
  }
}

abstract class Mappable extends LocalStorage {
  final Directory root;

  Mappable(this.root)
      : super([root, 'local'].file..createSync(recursive: true));

  String get name;

  SpotifyContainer get parent;

  String _spotifyId;

  String get spotifyId => _spotifyId ??= this['id'];

  set spotifyId(String id) => this['id'] = id;

  Future<void> save() async => saveFile();
}

extension MappableChecker on Directory {
  bool get isPlaylist =>
      [this, 'meta.json'].file.existsSync() &&
      [this, 'songs.md'].file.existsSync();
}

/// An object that stores playlists and folders.
abstract class SpotifyContainer {
  /// The directory holding any data related to this container, including children.
  Directory get root;

  /// The parent of the container
  SpotifyContainer get parent;

  /// A nested list of [Mappable]s in the container
  List<Mappable> get children;

  Mappable searchForId(String id) {
    id = id.parseId;
    Mappable traverse(Mappable mappable) {
      if (mappable.spotifyId == id) {
        return mappable;
      }

      if (mappable is SpotifyFolder) {
        for (var child in mappable.children) {
          var traversed = traverse(child);
          if (traversed != null) {
            return traversed;
          }
        }
      }
      return null;
    }

    for (var child in children) {
      var traversed = traverse(child);
      if (traversed != null) {
        return traversed;
      }
    }

    return null;
  }

  /// Creates a [SpotifyPlaylist] in the current container with the given name.
  SpotifyPlaylist addPlaylist(String name) =>
      _createMappable(name, () => SpotifyPlaylist(name, root));

  /// Creates a [SpotifyFolder] in the current container with the given name.
  SpotifyFolder addFolder(String name) =>
      _createMappable(name, () => SpotifyFolder(name, root, this));

  /// Replaces a given [SpotifyPlaylist] by an existing [id]. This ID should be
  /// directly in the current container and not in any child. If no direct child
  /// is found with the given ID, it is added to the end of the child list.
  SpotifyPlaylist replacePlaylist(String id) =>
      _replaceMappable(id, (name) => SpotifyPlaylist(name, root))
        ..spotifyId = id;

  /// Replaces a given [SpotifyFolder] by an existing [id]. This ID should be
  /// directly in the current container and not in any child. If no direct child
  /// is found with the given ID, it is added to the end of the child list.
  SpotifyFolder replaceFolder(String id) =>
      _replaceMappable(id, (name) => SpotifyFolder(name, root, this))
        ..spotifyId = id;

  T _createMappable<T extends Mappable>(
      String name, T Function() createMappable) {
    var playlist = createMappable();
    children?.add(playlist);
    return playlist;
  }

  T _replaceMappable<T extends Mappable>(
      String id, T Function(String) createMappable) {
    var foundMappable = children.indexWhere((map) => map.spotifyId == id);
    if (foundMappable == -1) {
      var playlist = createMappable(null);
      children.add(playlist);
      return playlist;
    } else {
      var playlist = createMappable(children[foundMappable]?.name);
      children.setAll(foundMappable, [playlist]);
      return playlist;
    }
  }
}

extension IDUtils on List<String> {
  void parseAll() => replaceRange(0, length, map((s) => s.parseId));
}

String parseArtists(Map<String, dynamic> trackJson) {
  var artistNames = List<String>.from(trackJson['artists'].map((data) => data['name']));
  if (artistNames.isEmpty) {
    return 'Unknown';
  }

  return artistNames.join(', ');
}

