import 'dart:io';

import 'package:Spogit/utility.dart';
import 'package:logging/logging.dart';

Future<void> main(List<String> args) async {
  await Setup().setup();
}

class Setup {
  final log = Logger('Setup');

  final hooks = const <String, String>{
    'post-checkout': r'''
#!/bin/bash

DOT_SPOGIT="$(dirname "$(pwd)")/.spogit"

if [ -f "$DOT_SPOGIT" ]; then
  echo "Updating Spogit"
  printf "GET /post-checkout?prev=$1&new=$2&from-branch=$3&pwd=$(pwd) HTTP/1.0\r\n\r\n" > /dev/tcp/localhost/9082
fi
    ''',
  };

  /// Should only be invoked once, such as when logging in.
  /// Adds relevant hooks to the default git repo template
  Future<void> setup() async {
    log.info('Creating and setting hooks...');
    try {
      var templateDir = await getTemplateDirectory();
      var hooksDir = [templateDir, 'hooks'].directory;

      await hooksDir.create(recursive: true);

      for (var name in hooks.keys) {
        var outFile = [hooksDir, name].file;
        if (!(await outFile.exists())) {
          await outFile.create();
          hooks[name] >> outFile;
          log.info('Added $name hook');
        } else {
          log.info('"${outFile.path}" already exists, not adding hook.');
        }
      }

      log.info('Created hooks');
    } on FileSystemException catch (e, s) {
      log.severe('Unable to create hook', e, s);
      print(e);
    }
  }

  Future<Directory> getTemplateDirectory() async {
    var info = (await gitCommand('--info-path')).directory.parent;
    var man = (await gitCommand('--man-path')).directory.parent;
    var html = (await gitCommand('--html-path')).directory.parent.parent;

    var share = getSimilarity([info, man, html]) ?? info;
    return [share, 'git-core', 'templates'].directory;
  }

  T getSimilarity<T>(List<T> data, [int minEquals = 2]) {
    var equalsData = <List<T>>[];

    for (var i = 0; i < data.length; i++) {
      var outer = data[i];
      var thisEquals = <T>[];
      for (var j = 0; j < data.length; j++) {
        if (j != i && data[j] == outer) {
          thisEquals.add(data[j]);
        }
      }

      if (thisEquals.length >= minEquals) {
        equalsData.add(thisEquals);
      }
    }

    if (equalsData.isEmpty) {
      return null;
    }

    equalsData.sort((list1, list2) => list2.length.compareTo(list1.length));
    return equalsData.safeFirst?.first;
  }

  Future<String> gitCommand(String command) async =>
      (await Process.run('git', [command])).stdout;
}
