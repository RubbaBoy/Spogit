import 'dart:io';

import 'package:Spogit/Spogit.dart';
import 'package:Spogit/utility.dart';
import 'package:args/args.dart';
import 'package:intl/intl.dart';
import 'package:logging/logging.dart';

final log = Logger('Main');

Future<void> main(List<String> args) async {
  setupLogging();

  var parser = ArgParser();
  parser.addFlag('help', abbr: 'h', help: 'Shows help');
  parser.addOption('path',
      abbr: 'p',
      defaultsTo: '~/Spogit',
      help: 'The path to store and listen to Spotify files');
  parser.addOption('cookies',
      abbr: 'c',
      defaultsTo: 'cookies.json',
      help: 'The location your Spotify cookies will be generated in, relative to the --path');
  parser.addOption('chromedriver',
      abbr: 'd',
      defaultsTo: 'chromedriver${Platform.isWindows ? '.exe' : ''}',
      help: 'Specify the location of your chromedriver executable, relative to the --path');
  parser.addOption('treeDuration',
      abbr: 't',
      defaultsTo: '4',
      help: 'Interval in seconds to check the Spotify tree');
  parser.addOption('playlistDuration',
      abbr: 'l',
      defaultsTo: '4',
      help: 'Interval in seconds to check for playlist modification');

  var parsed = parser.parse(args);
  var access = ArgAccess<String>(parsed);

  if (parsed['help']) {
    print('Note: For all paths, you may use ~/ for your home directory.\n');
    print(parser.usage);
    return;
  }

  var path = access['path'].directory;
  var cookies = [path, access['cookies']].file;
  var chromedriver = [path, access['chromedriver']].file;

  if (!path.existsSync()) {
    log.info('Path does not exist!');
    return;
  }

  final spogit = await Spogit.createSpogit(
      path, cookies, chromedriver, [path, 'cache'].file,
      treeDuration: access['treeDuration'].parseInt(),
      playlistDuration: access['playlistDuration'].parseInt());
  await spogit.start();
}

void setupLogging() {
  Logger.root.level = Level.ALL; // defaults to Level.INFO
  final jms = DateFormat.jms();
  Logger.root.onRecord.listen((record) => print(
      '[${jms.format(record.time)}] [${record.level.name}/${record.loggerName}]: ${record.message}'));
}

class ArgAccess<T> {
  final ArgResults _results;

  ArgAccess(this._results);

  T operator [](String key) => _results[key] as T;
}
