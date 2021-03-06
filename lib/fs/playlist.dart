import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:Spogit/Spogit.dart';
import 'package:Spogit/cache/id/id_resource_manager.dart';
import 'package:Spogit/driver/playlist_manager.dart';
import 'package:Spogit/fs/local_storage.dart';
import 'package:Spogit/json/album_simplified.dart';
import 'package:Spogit/json/playlist_full.dart';
import 'package:Spogit/markdown/readme.dart';
import 'package:Spogit/markdown/table_generator.dart';
import 'package:Spogit/utility.dart';
import 'package:http/http.dart' as http;

class SpogitRoot extends SpotifyContainer {
  final RootLocal rootLocal;
  final File meta;
  final File coverImage;
  final File readme;

  @override
  final Spogit spogit;

  @override
  final Directory root;

  @override
  SpotifyContainer get parent => null;

  List<Mappable> _children;

  @override
  List<Mappable> get children => _children ??= _traverseDir(root, null);

  SpogitRoot(this.spogit, this.root,
      {bool creating = false, List<String> tracking = const []})
      : rootLocal = RootLocal([root, 'local'].file),
        meta = [root, 'meta.json'].file..tryCreateSync(),
        coverImage = [root, 'cover.jpg'].file,
        readme = [root, 'README.md'].file {
    children;
    if (creating) {
      'local' >> [root, '.gitignore'];

      rootLocal
        ..id = randomHex(16)
        ..tracking = tracking;
    }
  }

  bool get isValid => meta.existsSync();

  List<Mappable> _traverseDir(Directory dir, SpotifyFolder parent) => dir
          .listSync()
          .whereType<Directory>()
          .where((dir) => !dir.uri.realName.startsWith('.'))
          .map((dir) {
        var name = dir.uri.realName;
        if (dir.isPlaylist) {
          return SpotifyPlaylist(spogit, unescapeSlash(name), dir.parent, parent);
        } else {
          final folder = SpotifyFolder(unescapeSlash(name), dir.parent, parent);
          folder.children = _traverseDir(dir, folder);
          return folder;
        }
      }).toList();

  Future<void> save() async {
    rootLocal.saveFile();
    var images = <String>[];

    for (var playlist in _children ?? const <Mappable>[]) {
      await playlist.save();
      images.add(playlist.readmeSnippet());
    }

    var parsed = Readme.parse(await readme.tryRead())
      ..title = root.uri.realName
      ..content = TableGenerator(images).generate();
    parsed.create() >> readme;
  }

  String treeString() {
    var out = '';
    for (var child in children) {
      out += '${child.treeString(0)}\n';
    }
    return out;
  }

  int getSongCount() => children.map((child) => child.getSongCount()).reduce((a, b) => a + b);

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

  set id(String value) => _id = this['id'] = value;

  List<String> _tracking;

  /// The IDs of the things that are being tracked.
  List<String> get tracking => _tracking ??=
      List<String>.from(this['tracking'] ?? const [], growable: false);

  set tracking(List<String> value) => _tracking = this['tracking'] = value;

  Map<String, String> _snapshotIds;

  /// A map of the playlist IDs and their snapshots, used for change tracking.
  Map<String, String> get snapshotIds =>
      _snapshotIds ??= Map.unmodifiable(this['snapshotIds'] ?? const {});

  set snapshotIds(Map<String, String> value) =>
      _snapshotIds = this['snapshotIds'] = value;

  String _revision;

  /// The ETag of the last base revision used.
  String get revision => _revision ??= this['revision'];

  set revision(String value) => _revision = this['revision'] = value;
}

class SpotifyPlaylist extends Mappable {
  final Spogit _spogit;
  final File coverImage;
  final File _songsFile;
  final File _meta;

  String _imageUrl;

  set imageUrl(String url) {
    if (url != null && url != _imageUrl) {
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
  SpotifyPlaylist(this._spogit, String name, Directory parentDirectory,
      [SpotifyFolder parentFolder])
      : parent = parentFolder,
        coverImage = [parentDirectory, name, 'cover.jpg'].file,
        _meta = [parentDirectory, name, 'meta.json'].file
          ..createSync(recursive: true),
        _songsFile = [parentDirectory, name, 'songs.md'].file
          ..createSync(recursive: true),
        super([parentDirectory, name].directory) {
    meta;
  }

  List<SpotifySong> readSongs() {
    var read = Readme.parse(_songsFile.tryReadSync());
    return read.content
        .split('---')
        .where((line) => line.trim().isNotEmpty)
        .map((line) => SpotifySong.fromLine(_spogit, line))
        .notNull()
        .toList();
  }

  @override
  int getSongCount() => songs.length;

  @override
  Future<void> save() async {
    await super.save();

    var currMetaHash = _metaJson?.customHash;
    if (metaHash == 0 || metaHash != currMetaHash) {
      metaHash = currMetaHash;
      await _meta.tryCreate();
      await _meta.writeAsString(jsonEncode(meta));
    } else if (!_meta.existsSync()) {
      _meta.createSync();
    }

    var currSongsHash = _songs?.customHash;
    if (songsHash == 0 || songsHash != currSongsHash) {
      songsHash = currSongsHash;
      await _songsFile.tryCreate();

      Readme.createTitled(
                  title: name,
                  description: description,
                  content:
                      (await songs.aMap((song) async => await song.toLine()))
                          .join('\n\n'))
              .create() >>
          _songsFile;
    } else if (!_songsFile.existsSync()) {
      _songsFile.createSync();
    }

    if (imageChanged) {
      imageChanged = false;
      if (_imageUrl != null) {
        await coverImage.writeAsBytes(
            await http.get(_imageUrl).then((res) => res.bodyBytes));
      }
    }
  }

  @override
  String treeString([int depth = 0]) => '${'  ' * depth} $name #$spotifyId';

  // TODO: Change songs.md to the README when description and whatnot is added maybe
  @override
  String readmeSnippet() =>
      '<a href="$name/songs.md"><img width="150" height="150" src="${coverImage.existsSync() ? '$name/cover.jpg' : 'https://rubbaboy.me/images/d4w3yqc'}"><br><b>$name<b></a>';

  @override
  String toString() =>
      'SpotifyPlaylist{root: ${root.path}, meta: $meta, songs: $songs}';
}

class SpotifyFolder extends Mappable with SpotifyContainer {
  File readme;

  @override
  String get name => root.uri.realName;

  @override
  final SpotifyContainer parent;

  @override
  List<Mappable> children;

  SpotifyFolder(String name, Directory parentDirectory, this.parent,
      [List<Mappable> children])
      : children = children ?? <Mappable>[],
        super([parentDirectory, name].directory) {
    readme = [root, 'README.md'].file;
  }

  @override
  int getSongCount() => children.map((child) => child.getSongCount()).reduce((a, b) => a + b);

  /// Folder image: https://rubbaboy.me/images/uuy0w5i
  /// Empty playlist image: https://rubbaboy.me/images/d4w3yqc
  @override
  String readmeSnippet() =>
      '<a href="$name"><img width="150" height="150" src="https://rubbaboy.me/images/uuy0w5i"><br><b>$name<b></a>';

  @override
  Future<void> save() async {
    await super.save();

    var images = <String>[];

    for (var child in children) {
      await child.save();
      images.add(child.readmeSnippet());
    }

    var str = await readme.tryRead();

    var desc = str != null ? descriptionRegex.firstMatch(str)?.group(1) : null;

    Readme.createTitled(
                title: name,
                description: desc,
                content: TableGenerator(images).generate())
            .create() >>
        readme;
  }

  @override
  String treeString([int depth = 0]) {
    var out = '${'  ' * depth} $name #$spotifyId';
    for (var child in children) {
      out += '\n${child.treeString(depth + 1)}';
    }
    return '$out';
  }

  @override
  String toString() {
    return 'SpotifyFolder{root: $root, children: $children}';
  }
}

class SpotifySong {
  /// The parsed track ID
  final String id;

  /// The track name
  final String trackName;

  /// The ID of the album
  String albumId;

  /// The simplified album. This may be null
  AlbumSimplified _album;

  /// Gets or retrieves the [AlbumSimplified] from the constructor or [albumId].
  FutureOr<AlbumSimplified> get album =>
      _album ??
      spogit.albumResourceManager
          .getAlbumFromId(albumId)
          .then((full) => _album = full);

  Spogit spogit;
  String cachedLine;

  /// Creates a SpotifySong from a single track json element.
  SpotifySong.fromJson(this.spogit, PlaylistTrack playlistTrack)
      : id = playlistTrack.track?.id,
        trackName = playlistTrack.track?.name ?? 'Unknown',
        _album = playlistTrack.track?.album {
    albumId = _album?.id ?? '';
  }

  /// The [id] should be the parsed track ID, and the [artistName] is the full
  /// `Song - Artist` unparsed line from an existing link.
  SpotifySong._create(this.spogit, this.trackName, this.id, this.albumId,
      [this.cachedLine]);

  /// Example of a song chunk:
  /// ```
  /// <img align="left" width="100" height="100" src="https://i.scdn.co/image/ab67616d00001e02f7db43292a6a99b21b51d5b4">
  /// ### [Lucid Dreams](https://open.spotify.com/go?uri=spotify:track:285pBltuF7vW8TeWk8hdRR)
  /// [Goodbye & Good Riddance](https://open.spotify.com/go?uri=spotify:track:6tkjU4Umpo79wwkgPMV3nZ)
  /// ---
  /// ```
  factory SpotifySong.fromLine(Spogit spogit, String songChunk) {
    var allMatches = linkRegex.allMatches(songChunk);
    var matches = allMatches.iterator;
    if (allMatches.length != 2) {
      return null;
    }

    matches.moveNext();
    var trackMatch = matches.current;
    matches.moveNext();
    var albumMatch = matches.current;

    return SpotifySong._create(spogit, trackMatch.group(1), trackMatch.group(2),
        albumMatch.group(2), songChunk.trim());
  }

  FutureOr<String> toLine() async => id == null ? '' : await (() async {
        var fetchedAlbum = await album;
        return '''
<img align="left" width="100" height="100" src="${fetchedAlbum?.images?.safeFirst?.url}">

### [${await spogit.idResourceManager.getName(id, ResourceType.Track)}](https://open.spotify.com/go?uri=spotify:track:$id)
[${fetchedAlbum?.name}](https://open.spotify.com/go?uri=spotify:album:$albumId)

---
''';
      })();

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

  int getSongCount();

  Future<void> save() async => saveFile();

  String treeString([int depth = 0]);

  /// Creates a snippet of markdown to put in a README file displaying the
  /// current object in a list. This should be something like a cover image
  /// or similar, around 75px square.
  String readmeSnippet();
}

extension MappableChecker on Directory {
  bool get isPlaylist =>
      [this, 'meta.json'].file.existsSync() &&
      [this, 'songs.md'].file.existsSync();
}

/// An object that stores playlists and folders.
abstract class SpotifyContainer {
  Spogit spogit;

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
      _createMappable(name, () => SpotifyPlaylist(spogit, name, root));

  /// Creates a [SpotifyFolder] in the current container with the given name.
  SpotifyFolder addFolder(String name) =>
      _createMappable(name, () => SpotifyFolder(name, root, this));

  /// Replaces a given [SpotifyPlaylist] by an existing [id]. This ID should be
  /// directly in the current container and not in any child. If no direct child
  /// is found with the given ID, it is added to the end of the child list.
  SpotifyPlaylist replacePlaylist(String id) =>
      _replaceMappable(id, (name) => SpotifyPlaylist(spogit, name, root))
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
  var artistNames =
      List<String>.from(trackJson['artists'].map((data) => data['name']));
  if (artistNames.isEmpty) {
    return 'Unknown';
  }

  return artistNames.join(', ');
}
