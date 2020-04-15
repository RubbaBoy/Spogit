import 'dart:async';
import 'dart:io';

import 'package:Spogit/fs/playlist.dart';

import 'utility.dart';

class FileWatcher {
  // ~/Spogit
  final Directory root;

  FileWatcher(this.root);

  int lastModified = -1;
  Timer timer;

  SpogitRoot parseTree() {
    return SpogitRoot(root);
  }

  void listenChange(Function(SpogitRoot) callback) {
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

//      print(event);
//      print(event.isDirectory);

//      print('Modified a file, lets see if its music or meta');
//
//
//      print('Modified ${event.path} which is (or is in) ${whateverRoot.path}');
//
//      final type = ContentType.getType(whateverRoot);
//
//      if (type == null) {
//        print('No type found');
//        return;
//      }
//
//      print('This is a $type');
//
//      if (type == ContentType.Folder) {
//        print('Is a folder "${whateverRoot.uri.pathSegments.last}"');
//      } else if (type == ContentType.Playlist) {
//        print('Is a playlist "${whateverRoot.uri.pathSegments.last}"');
//
////        if (event is FileSystemModifyEvent) {
//          if (event.isDirectory) {
//            print('Was probbaly a rename, ignore');
//          } else {
//            var file = event.path.file;
//            var name = file.uri.pathSegments.last;
//            print('Update $name');
//        }
////        }
//      }
//
//      return;

//      if (directory.parent.path != root.path) {
//        print('${directory.parent.path} != ${root.path}');
//        return;
//      }
//
//      if ([directory, 'meta.json'].file.existsSync()) {
//        print('meta exists!');
//
//        var spogitRoot = SpogitRoot(directory);
//        callback(spogitRoot);
//
//      } else {
//        print('Meta does NOT exist!');
//      }
    });
  }
}
