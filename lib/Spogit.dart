import 'dart:async';
import 'dart:io';

import 'package:Spogit/change_watcher.dart';
import 'package:Spogit/driver/driver_api.dart';
import 'package:Spogit/driver/playlist_manager.dart';
import 'package:Spogit/file_watcher.dart';
import 'package:Spogit/local_manager.dart';
import 'package:Spogit/utility.dart';

class Spogit {
  final DriverAPI driverAPI;

  PlaylistManager get playlistManager => driverAPI?.playlistManager;

  Spogit._(this.driverAPI);

  static Future<Spogit> createSpogit() async {
    final driverAPI = DriverAPI();
    await driverAPI.startDriver();
    return Spogit._(driverAPI);
  }

  Future<void> start(Directory path) async {
    final changeWatcher = ChangeWatcher(driverAPI);
    final fileWatcher = FileWatcher(path);

//    changeWatcher.watchChanges((baseRevision) {
//      for (var value in baseRevision.elements) {
//
//      }
//    });
//
//    fileWatcher.listenSpogit((root) {
//
//    });

    var name = 'Test Local';

    var elements = [
      'spotify:playlist:77TYGLTCm45nA9SOT2kAaj',
      'spotify:start-group:27345c6f477d000:first'
    ];

//    // first,   tld playlist
    var linkedStuff = LinkedPlaylist.fromRemote(driverAPI, 'Test Local', await playlistManager.analyzeBaseRevision(), elements);
    await linkedStuff.initElement();
//
//    exit(0);

//    path.listSync().forEach((child) => child.deleteSync(recursive: true));

    var currRevision = await playlistManager.analyzeBaseRevision();

    final manager = LocalManager(driverAPI, path);

    final existing = manager.getExistingRoots(currRevision);

    print('Got ${existing.length} existing');

    print('waiting 10 sec....');
    sleep(Duration(seconds: 3));
    print('done!');

    for (var exist in existing) {
      await exist.initElement();
      print('\nExisting:');
      print(exist.root.rootLocal.id);
      print(exist.root);
    }

    print('bnoutta watch');
    changeWatcher.watchChanges(currRevision, existing, (baseRevision, linkedPlaylist, ids) {
      print('Pulling remote');
      linkedPlaylist.pullRemote(baseRevision, ids);
    });
  }

//  void startDaemon(Directory path) {
//    final watcher = FileWatcher(path);
//
//    /// Use the spotify API for stuff
//    watcher.listenSpogit((root) {
//      // Actual files changed spotify:playlist:4T8gh2JVgZoiGFutx04ErJ
//      print('Spogit files have changed.');
//      print(root.playlists.join('\n'));
//    });
//
//    /// Modify files to reflect the Spotify API
//    watcher.listenSpotify((entities) {
//      // Order changed
//      for (var entity in entities) {
//        print('Moved $entity to ${entity.parent}');
//      }
//    }, (entities) {
//      // Playlists changed
//      for (var entity in entities) {
//        print('Modified the contents of $entity');
//      }
//    });
//  }

  /// Creates a fresh playlist, adding it to Spotify
  Future<void> createFresh(String name) async {
    await playlistManager.createPlaylist(name);
  }

  /// Creates a Spogit playlist from an existing Spotify playlist. [playlistId]
  /// is the raw playlist ID.
  Future<void> createLinked(String playlistId) async {}
}
