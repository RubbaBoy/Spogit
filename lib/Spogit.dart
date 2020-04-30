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
//    var linkedStuff = LinkedPlaylist.fromRemote(driverAPI, 'Test Local', await playlistManager.analyzeBaseRevision(), elements);
//    await linkedStuff.initElement();
//
//    exit(0);

//    path.listSync().forEach((child) => child.deleteSync(recursive: true));

    var currRevision = await playlistManager.analyzeBaseRevision();

    final manager = LocalManager(driverAPI, path);

    final existing = manager.getExistingRoots(currRevision);

    print('Got ${existing.length} existing');

    for (var exist in existing) {
      await exist.initElement();
      print('\nExisting:');
      print(exist.root.rootLocal.id);
      print(exist.root);
    }

    var previousHashes = <LinkedPlaylist, Map<String, int>>{};

    changeWatcher.watchChanges((revision) async {
      print('It has changed on the Spotify side!');

      var adding = previousHashes.isEmpty;
      for (var exist in existing) {
        // The fully qualified track/playlist ID and its hash
        var theseHashes = <String, int>{};
        var tracking = exist.root.rootLocal.tracking;

        if (previousHashes.isNotEmpty &&
            previousHashes[exist].length != tracking.length) {
          print('Tracking lengths to not match up! Pulling from remote...');
        } else {
          for (var track in tracking) {
            var hash = revision.getHash(id: track);
            theseHashes[track] = hash;
          }

          if (!adding) {
            var prevHash = {...previousHashes.putIfAbsent(exist, () => {})};

            var difference = getDifference(prevHash, theseHashes);
            print(
                'previous = ${prevHash.keys.toList().map((k) => '$k: ${prevHash[k].toRadixString(16)}').join(', ')}');
            print(
                'theseHashes = ${theseHashes.keys.toList().map((k) => '$k: ${theseHashes[k].toRadixString(16)}').join(', ')}');

            if (difference.isNotEmpty) {
              print(
                  'Difference between hashes! Reloading ${exist.root.root.uri.realName} tracking: $difference');
            } else {
              print('No hash difference for ${exist.root.root.uri.realName}');
            }
          }
        }

        previousHashes[exist] = theseHashes;
        exist.root.rootLocal.revision = revision.revision;
      }

//      var linkedStuff = LinkedPlaylist.fromRemote(
//          driverAPI, name, revision, elements);
//
//      await linkedStuff.initElement();
    });
  }

  List<String> getDifference(Map<String, int> first, Map<String, int> second) {
    var res = <String>{};
    void checkMaps(Map<String, int> one, Map<String, int> two) {
      for (var id in one.keys) {
        if (!two.containsKey(id) || two[id] != one[id]) {
          res.add(id);
        }
      }
    }

    checkMaps(first, second);
    checkMaps(second, first);

    return res.toList();
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
