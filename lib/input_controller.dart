import 'dart:convert';
import 'dart:io';

import 'package:Spogit/driver/driver_api.dart';
import 'package:Spogit/driver/playlist_manager.dart';
import 'package:Spogit/local_manager.dart';
import 'package:Spogit/utility.dart';

class InputController {
  final DriverAPI driverAPI;
  final LocalManager localManager;

  InputController(this.driverAPI, this.localManager);

  void start() {
    print('Listening for commands...');
    stdin.transform(utf8.decoder).listen((line) {
      print('Data = $line');

      var index = line.indexOf(' ');
      if (index == -1) {
        return;
      }

      var split = line.splitQuotes();
      print('Split = "$split"');

      //    add-remote
      var command = split.safeFirst;
      var args = split.skip(1).toList();

      switch (command) {
        case 'ar':
        case 'add-remote':
          if (args.length < 2) {
            print(
                'Please specify the name of the grouping and a list of root playlists/tracks to add from remote!');
            print('Example usage (Playlist and a folder):');
            print(
                '\tadd-remote "My Demo" spotify:playlist:41fMgMIEZJLJjJ9xbzYar6 27345c6f477d000');
            return;
          }

          print('Adding remote!');

          var name = args.first;

          var ids =
              args.skip(1).map((str) => ParsingUtils(str).parseId).toList();

          print('Name = $name');
          print('Parsed IDs: $ids');
          break;
        default:
          print('Couldn\'t recognise command "$command"');
          break;
      }
    });
  }
}
