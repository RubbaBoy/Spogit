import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:Spogit/fs/playlist.dart';

import 'utility.dart';

class FileWatcher {
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
}
