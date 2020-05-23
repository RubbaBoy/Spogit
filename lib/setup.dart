import 'dart:io';

import 'package:Spogit/utility.dart';
import 'package:logging/logging.dart';

void main(List<String> args) {
    Setup().setup(r'C:\Users\RubbaBoy\Spogit'.directory);
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
  /// Takes the ~/Spogit directory and places got hooks in there, and then runs
  /// a git config command to set the hooks to that location.
  Future<void> setup(Directory spogit) async {
    log.info('Creating and setting hooks...');
    var hooksDir = [spogit, 'hooks'].directory;
    await hooksDir.create(recursive: true);

    for (var name in hooks.keys) {
      hooks[name] >> [hooksDir, name];
    }

    await Process.run(
        'git', ['config', '--global', 'core.hooksPath', hooksDir.path]);
  }
}
