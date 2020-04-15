import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:collection/collection.dart';

const firstSongCache = SearchQuery(needle: 'premium', firstLine: true);
var mapEquals = MapEquality().equals;

Future<void> main(List<String> args) async {
  var modified = true;

  String cacheFile;
  Map<SpotifyPlaylist, String> playlists;
  List<SpotifyEntity> entityTree;

  syncPeriodic(Duration(milliseconds: 1000), () async {
    if (modified) {
      modified = false;

      var entities = await getEntities();
      var foundPlaylists = entities.value.flattenPlaylists;

      var currFiles = await getPlaylistCache(foundPlaylists);

      var shit = foundPlaylists.asMap().map((i, playlist) => MapEntry(playlist, (currFiles[playlist])[0].path as String));

      cacheFile = entities.key.path;

      playlists ??= shit;
      entityTree ??= entities.value;

      // Testing is the whole tree order is identical or not. If not, the order changed.
      if (!equals(entityTree, entities.value)) {
        playlists = shit;
        entityTree = entities.value;

        print('Modified the order of playlists!');
      }

      // The playlists could be changed too, so handle that
      if (!equals(playlists.values.toList(), shit.values.toList())) {
        playlists = shit;
        entityTree = entities.value;

        print('Modified playlist contents!');
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

void syncPeriodic(Duration duration, Function callback) {
  callback();
  Timer(duration, () async => await syncPeriodic(duration, callback));
}

Future<Map<SpotifyPlaylist, List>> getPlaylistCache(List<SpotifyPlaylist> playlists) async {
  var map = {
    for (var playlist in playlists)
      playlist: [
        firstSongCache,
        SearchQuery(needle: 'spotify:playlist:${playlist.id}', skipFirst: true)
      ]
  };

  return await getCacheFile(map);
}

Future<MapEntry<File, List<SpotifyEntity>>> getEntities() async {
  var result = (await getCacheFile({
    'all': [SearchQuery(needle: 'spotify:', offset: 11, firstLine: true)]
  }))['all'];

  var bytes = stripList(result[1]);

  var str = String.fromCharCodes(bytes);

  var parsed = str
      .split('spotify:')
      .skip(1)
      .map((line) => line.substring(0, line.length - 1).split(':'));

  var root = SpotifyFolder();
  var current = root;

  for (var value in parsed) {
    var id = value[1];
    <String, Function>{
      'playlist': () => current.children.add(SpotifyPlaylist(id)),
      'start-group': () {
        final group = SpotifyFolder(
            id, Uri.decodeComponent(value[2].replaceAll('+', ' ')), current);
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

class SearchQuery {
  final String needle;
  final List<int> needleBytes;
  final int offset;
  final bool firstLine;
  final bool skipFirst;

  const SearchQuery({this.needle, this.needleBytes, this.offset = -1, this.firstLine = false, this.skipFirst = false});
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



extension ASCIIShit on int {
  bool get isASCII => (this == 10 || this == 13 || (this >= 32 && this <= 126));

  bool get isNotASCII => !isASCII;
}

