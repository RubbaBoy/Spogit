import 'dart:io';

import 'package:Spogit/Spogit.dart';
import 'package:Spogit/utility.dart';
import 'package:args/args.dart';

Future<void> main(List<String> args) async {
  var parser = ArgParser();
  parser.addFlag('daemon', abbr: 'd');
  parser.addOption('path', abbr: 'p', defaultsTo: '~/Spogit', help: 'The path to store and listen to Spotify files. Use ~/ for your home directory');

  var parsed = parser.parse(args);

  var daemon = parsed['daemon'];
  var path = (parsed['path'] as String).directory;

  if (!path.existsSync()) {
    print('Path does not exist!');
    return;
  }

  if (!daemon) {
    print('Restarting as daemon...');
    // TODO: This
    return;
  }

  print('Running as daemon');

  final spogit = await Spogit.createSpogit([path, 'cache'].file);
  await spogit.start(path);
}
