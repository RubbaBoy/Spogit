import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:Spogit/fs/cache_tree/cache_tree.dart';
import 'package:Spogit/utility.dart';

Stream<List<CachedEntity>> getFolders() {
  final controller = StreamController<List<CachedEntity>>.broadcast();

  var cache = Directory(r'C:\Users\RubbaBoy\AppData\Local\Spotify\Storage');

  getCacheFile(cache).then((result) {
    void pushUpdate(Uint8List data) =>
        parseFolders(data).then((value) => controller.add(value));

    pushUpdate(result[1]);

    cache.watch(events: FileSystemEvent.create, recursive: true).listen((event) async {
      if (!event.isDirectory) {
        var file = event.path.file;
        print(file);
        if (await file.length() > 0) {
          var data = await file.readAsBytes();
          if (bytesContains(data)) {
            pushUpdate(data);
          }
        }
      }
    });
  });

  return controller.stream;
}

Future<List<CachedEntity>> parseFolders(Uint8List data) async {
  var bytes = stripList(data);

  var parsed = String.fromCharCodes(bytes)
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

  return root.children;
}

List<int> stripList(Uint8List list) {
  var pastComma = false;
  var pastFirst = false;
  return <int>[...list.toList()]..removeWhere((i) {
      if (pastFirst) {
        return true;
      }

      if (i == 10 || i == 13) {
        pastFirst = true;
      }

      var res = !pastComma || i < 32 || i > 126;
      pastComma = pastComma || i == 44; // ,
      return res;
    });
}

Future<List> getCacheFile(Directory cache) async {
  final completer = Completer<List>();

  StreamSubscription sub;
  sub = cache.list(recursive: true).listen((entity) {
    if (entity is File) {
      var data = entity.readAsBytesSync();
      if (bytesContains(data)) {
        completer.complete([entity, data]);
        sub.cancel();
      }
    }
  },
      onDone: () => completer.complete(),
      onError: (e) => completer.completeError(e));

  return completer.future;
}

final units = 'spotify:start-group'.codeUnits;

bool bytesContains(Uint8List list) {
  var unitIndex = 0;
  for (var value in list) {
    // We're only looking for the first line
    if (value == 10 || value == 13) {
      return false;
    }

    if (value == units[unitIndex++]) {
      if (unitIndex >= units.length) {
        return true;
      }
    } else {
      unitIndex = 0;
    }
  }

  return false;
}
