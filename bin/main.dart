import 'dart:io';

import 'package:Spogit/Spogit.dart';
import 'package:Spogit/utility.dart';
import 'package:args/args.dart';
import 'package:intl/intl.dart';
import 'package:logging/logging.dart';

Future<void> main(List<String> args) async {
  setupLogging();

  var parser = ArgParser();
  parser.addFlag('help', abbr: 'h', help: 'Shows help');
  parser.addOption('path', abbr: 'p', defaultsTo: '~/Spogit', help: 'The path to store and listen to Spotify files');
  parser.addOption('cookies', abbr: 'c', defaultsTo: '~/Spogit/cookies.json', help: 'The location your Spotify cookies will be generated in');
  parser.addOption('chromedriver', abbr: 'd', defaultsTo: '~/Spogit/chromedriver.exe', help: 'Specify the location of your chromedriver executable');

  var parsed = parser.parse(args);

  if (parsed['help']) {
    print('Note: For all paths, you may use ~/ for your home directory.\n');
    print(parser.usage);
    return;
  }

  var path = (parsed['path'] as String).directory;
  var cookies = (parsed['cookies'] as String).file;
  var chromedriver = (parsed['chromedriver'] as String).file;

  if (!path.existsSync()) {
    print('Path does not exist!');
    return;
  }

  final spogit = await Spogit.createSpogit(cookies, chromedriver, [path, 'cache'].file);
  await spogit.start(path);
}

void setupLogging() {
  Logger.root.level = Level.ALL; // defaults to Level.INFO
  final jms = DateFormat.jms();
  Logger.root.onRecord.listen((record) => print('[${jms.format(record.time)}] [${record.level.name}/${record.loggerName}]: ${record.message}'));
}
