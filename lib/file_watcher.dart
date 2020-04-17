import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:Spogit/fs/cache_tree/cache_tree.dart';
import 'package:Spogit/fs/playlist.dart';

import 'utility.dart';

class FileWatcher {
  static const firstSongCache = SearchQuery(needle: 'premium', firstLine: true);

  // ~/Spogit
  final Directory root;

  FileWatcher(this.root);

  int lastModified = -1;
  Timer timer;

  SpogitRoot parseTree() => SpogitRoot(root);

  // Listen to Spogit
  void listenSpogit(Function(SpogitRoot) callback) {
    root.watch(recursive: true).listen((event) {
      var whateverRoot =
      event.isDirectory ? event.path.directory : event.path.file.parent;

      print('Something happened in ${whateverRoot.path}');

      lastModified = now;
      timer?.cancel();
      timer = Timer(Duration(seconds: 2), () {
        print('Reparsing tree!');
        callback(parseTree());
      });
    });
  }

  void listenSpotify(void Function(List<CachedEntity>) newOrder, void Function(List<CachedPlaylist>) playlistChange) {
    var modified = true;

    String cacheFile;
    Map<CachedPlaylist, String> playlists;
    List<CachedEntity> entityTree;
    List<CachedPlaylist> flatPlaylists;

    syncPeriodic(Duration(milliseconds: 500), () async {
      if (modified) {
        modified = false;

        var entities = await getEntities();
        var foundPlaylists = entities.value.flattenPlaylists;

        var currFiles = await getPlaylistCache(foundPlaylists);

        var newPlaylists = foundPlaylists.asMap().map((i, playlist) => MapEntry(playlist, currFiles[playlist]?.elementAt(0)?.path as String));

        cacheFile = entities.key.path;

        playlists ??= newPlaylists;
        entityTree ??= entities.value;
        flatPlaylists ??= foundPlaylists;

        // Testing is the whole tree order is identical or not. If not, the order changed.
        if (!listEquals(entityTree, entities.value)) {
          var previous = flatPlaylists.asMap().map((i, playlist) => MapEntry(playlist, playlist.parents));
          var current = foundPlaylists.asMap().map((i, playlist) => MapEntry(playlist, playlist.parents));

          var diff = previous..removeWhere((k, v) => listEquals(current[k], v));

          playlists = newPlaylists;
          entityTree = entities.value;
          flatPlaylists = foundPlaylists;

          // This converts the CachedPlaylist from the old to new stuff, as to retain non-id data (Currently only parent)
          var kk = newPlaylists.map((k, v) => MapEntry(k, k));
          newOrder(diff.keys.map((playlist) => kk[playlist]).toList());
        }

        // The playlists could be changed too, so handle that
        if (!listEquals(playlists.values.toList(), newPlaylists.values.toList())) {
          var modified = newPlaylists.keys.where((key) => newPlaylists[key] != playlists[key]).toList();

          playlists = newPlaylists;
          entityTree = entities.value;
          foundPlaylists = flatPlaylists;

          playlistChange(modified);
        }
      }
    });

    Directory(r'C:\Users\RubbaBoy\AppData\Local\Spotify\Storage').watch(events: FileSystemEvent.all, recursive: true).listen((event) {
      if (!event.isDirectory) {
        if (cacheFile == event?.path || (playlists?.values?.contains(event.path) ?? false)) {
          modified = true;
        }
      }
    });
  }

  Future<Map<CachedPlaylist, List>> getPlaylistCache(List<CachedPlaylist> playlists) async {
    var map = {
      for (var playlist in playlists)
        playlist: [
          firstSongCache,
          SearchQuery(needle: 'spotify:playlist:${playlist.id}', skipFirst: true)
        ]
    };

    return await getCacheFile(map);
  }

  Future<MapEntry<File, List<CachedEntity>>> getEntities() async {
    var result = (await getCacheFile({
      'all': [SearchQuery(needle: 'spotify:', offset: 11, firstLine: true)]
    }))['all'];

    var bytes = stripList(result[1]);

    var str = String.fromCharCodes(bytes);

    var parsed = str
        .split('spotify:')
        .skip(1)
        .map((line) => line.substring(0, line.length - 1).split(':'));

    var root = CachedFolder();
    var current = root;

    for (var value in parsed) {
      var id = value[1];
      <String, Function>{
        'playlist': () => current.children.add(CachedPlaylist(id, current)),
        'start-group': () {
          final group = CachedFolder(
              id, current, Uri.decodeComponent(value[2].replaceAll('+', ' ')));
          current.children.add(current = group);
        },
        'end-group': () => current = current.parent
      }[value[0]]();
    }

    return MapEntry(result[0], root.children);
  }

  List<int> stripList(Uint8List list) {
    var pastFirst = false;
    return <int>[...list.toList().skip(11)]..removeWhere((i) {
      if (pastFirst) {
        return true;
      }

      if (i == 10 || i == 13) {
        pastFirst = true;
      }

      return i.isNotASCII;
    });
  }

  Future<Map<T, List>> getCacheFile<T>(Map<T, List<SearchQuery>> queries) async {
    final completer = Completer<Map<T, List>>();
    var result = <T, List>{};

    var dir = Directory(r'C:\Users\RubbaBoy\AppData\Local\Spotify\Storage');

    dir.list(recursive: true).listen((entity) {
      try {
        if (entity is File) {
          var data = entity.readAsBytesSync();

          if (entity.path.endsWith('~')) {
            return;
          }

          for (var entry in queries.entries) {
            if (entry.value.every((query) => bytesContains(Uint8List.fromList(data.toList()),
                query.needle?.codeUnits ?? query.needleBytes, query.firstLine, query.skipFirst, query.offset))) {
              result[entry.key] = [entity, data];
            }
          }
        }
      } catch (_) {}
    },
        onDone: () => completer.complete(result),
        onError: (e) => completer.completeError(e));

    return completer.future;
  }

  bool bytesContains(
      Uint8List list, List<int> units, bool firstLine, bool skipFirst, int offset) {
    var unitIndex = 0;
    var seenNewline = false;
    var usingOffset = offset != -1;

    for (var value in list) {

      if (offset > 0) {
        offset--;
        continue;
      }

      // If we're only looking for the first line
      if (value == 10 || value == 13) {
        seenNewline = true;
        if (firstLine) {
          return false;
        }
      }

      if (skipFirst && !seenNewline) {
        continue;
      }

      if (value == units[unitIndex++]) {
        if (unitIndex >= units.length) {
          return true;
        }
      } else {
        if (usingOffset) {
          return false;
        }

        unitIndex = 0;
      }
    }

    return false;
  }
}

class SearchQuery {
  final String needle;
  final List<int> needleBytes;
  final int offset;
  final bool firstLine;
  final bool skipFirst;

  const SearchQuery({this.needle, this.needleBytes, this.offset = -1, this.firstLine = false, this.skipFirst = false});
}
