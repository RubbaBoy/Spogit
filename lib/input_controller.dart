import 'dart:convert';
import 'dart:io';

import 'package:Spogit/Spogit.dart';
import 'package:Spogit/driver/driver_api.dart';
import 'package:Spogit/driver/playlist_manager.dart';
import 'package:Spogit/git_hook.dart';
import 'package:Spogit/local_manager.dart';
import 'package:Spogit/utility.dart';

class InputController {
  final Spogit spogit;
  final DriverAPI driverAPI;
  final LocalManager localManager;

  InputController(this.spogit, this.localManager)
      : driverAPI = spogit.driverAPI;

  void start(Directory path) {
    print('Listening for commands...');
    stdin.transform(utf8.decoder).listen((line) async {
      var split = line.splitQuotes();

      //    add-remote
      var command = split.safeFirst;
      var args = split.skip(1).toList();

      switch (command) {
        case 'help':
        case '?':
          print('''
=== Command help ===

add-remote "My Demo" spotify:playlist:41fMgMIEZJLJjJ9xbzYar6 27345c6f477d000
    Adds a list of playlist or folder IDs to the local Spogit root with the given name.
  
status
    Lists the linked repos and playlists
  
list
    Lists your Spotify accounts' playlist and folder names and IDs.

===''');
          break;
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

          var base = await driverAPI.playlistManager.analyzeBaseRevision();
          var baseIds = base.elements.map((elem) => elem.id.parseId).toSet();
          ids.removeWhere((id) => !baseIds.contains(id));

          if (ids.isEmpty) {
            print('Could not perform that action as no IDs were top-level.');
            break;
          }

          var local = LinkedPlaylist.fromRemote(spogit, localManager, name,
              await driverAPI.playlistManager.analyzeBaseRevision(), ids);
          localManager.addPlaylist(local);
          await local.initElement();
          break;
        case 'al':
        case 'add-local':
          if (args.length != 1) {
            print('The arguments must be a single directory name as the Spogit child');
            break;
          }

          var addingPath = [path, args[0]].directory;
          print('Adding local repository ${addingPath.path}');
          spogit.gitHook.postCheckout.add(PostCheckoutData('', '', false, addingPath));
          break;
        case 'status':
          for (var value in localManager.linkedPlaylists) {
            print('\nSpogit/${value.root.root.uri.realName}:');
            print(value.root.treeString());
          }
          break;
        case 'list':
          print('''

Listing of all current Spotify tree data.
Key:
P - Playlist. ID starts with spotify:playlist
S - Group start. ID starts with spotify:start-group
E - Group end. ID starts with spotify:end-group

''');
          var base = await driverAPI.playlistManager.analyzeBaseRevision();
          var depth = 0;
          var nameMap = <String, String>{};
          for (var element in base.elements) {
            String line(String type, [String name]) =>
                '${'  ' * depth} [$type] ${name ?? element.name} #${element.id}';
            switch (element.type) {
              case ElementType.Playlist:
                print(line('P'));
                break;
              case ElementType.FolderStart:
                nameMap[element.id] = element.name;
                print(line('S'));
                depth++;
                break;
              case ElementType.FolderEnd:
                depth--;
                print(line('E', nameMap[element.id]));
                break;
            }
          }
          break;
        case 'save':
          print('Saving data from memory...');

          if (args.isEmpty) {
            print('Please provide a list of IDs to pull.');
            break;
          }

          for (var id in args) {
            var pulling = localManager.getFromAnyId(id);
            await pulling.initElement();
          }

          break;
        default:
          print('Couldn\'t recognise command "$command"');
          break;
      }
      print('');
    });
  }
}
