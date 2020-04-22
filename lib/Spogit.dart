import 'dart:async';
import 'dart:io';

import 'package:Spogit/change_watcher.dart';
import 'package:Spogit/driver/driver_api.dart';
import 'package:Spogit/driver/playlist_manager.dart';
import 'package:Spogit/file_watcher.dart';
import 'package:Spogit/local_manager.dart';

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

    // first,   tld playlist
    var linkedStuff = LinkedPlaylist.fromRemote(driverAPI, 'Test Local', await playlistManager.analyzeBaseRevision(), ['spotify:start-group:b623551dee2c000:first', 'spotify:playlist:5LtVZsSVm60F8lHAWGnute']);
    await linkedStuff.initElement();
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
  Future<void> createLinked(String playlistId) async {

  }
}
