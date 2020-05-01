import 'dart:async';

import 'package:Spogit/driver/driver_api.dart';
import 'package:Spogit/driver/playlist_manager.dart';
import 'package:Spogit/fs/playlist.dart';
import 'package:Spogit/local_manager.dart';
import 'package:Spogit/utility.dart';

class ChangeWatcher {
  final DriverAPI driverAPI;

  ChangeWatcher(this.driverAPI);

  /// Watches for changes in the playlist tree
  void watchAllChanges(Function(BaseRevision) callback) {
    // The last etag for the playlist tree request
    String previousETag;

    Timer.periodic(Duration(seconds: 2), (timer) async {
      var etag = await driverAPI.playlistManager.baseRevisionETag();
      if (etag == previousETag) {
        return;
      }

      var sendCallback = previousETag != null;

      previousETag = etag;

      if (sendCallback) {
        print('\n\nPlaylist tree has changed!');
        callback(await driverAPI.playlistManager.analyzeBaseRevision());
      }
    });
  }

  /// Watches changes to the base [tracking] elements. This only watches for
  /// tree changes, and not playlist changes.
  void watchChanges(BaseRevision baseRevision, List<LinkedPlaylist> tracking, Function(BaseRevision, LinkedPlaylist, List<String>) callback) {
    var previousHashes = <LinkedPlaylist, Map<String, int>>{};

    for (var exist in tracking) {
      var theseHashes = <String, int>{};

      var trackingIds = exist.root.rootLocal.tracking;
      for (var track in trackingIds) {
        var hash = baseRevision.getHash(id: track);
        theseHashes[track] = hash;
      }

      previousHashes[exist] = theseHashes;
    }

    watchAllChanges((revision) async {
      print('It has changed on the Spotify side!');

      for (var exist in tracking) {
        // The fully qualified track/playlist ID and its hash
        var theseHashes = <String, int>{};
        var trackingIds = exist.root.rootLocal.tracking;

//        if (previousHashes.isNotEmpty &&
//            previousHashes[exist].length != trackingIds.length) {
//          print('Tracking lengths to not match up! Pulling from remote...');
//
//        } else {
          for (var track in trackingIds) {
            var hash = revision.getHash(id: track);
            theseHashes[track] = hash;
          }

            var prevHash = {...previousHashes.putIfAbsent(exist, () => {})};

            var difference = getDifference(prevHash, theseHashes);
            print(
                'previous = ${prevHash.keys.toList().map((k) => '$k: ${prevHash[k].toRadixString(16)}').join(', ')}');
            print(
                'theseHashes = ${theseHashes.keys.toList().map((k) => '$k: ${theseHashes[k].toRadixString(16)}').join(', ')}');

            if (difference.isNotEmpty) {
              print(
                  'Difference between hashes! Reloading ${exist.root.root.uri.realName} trackingIds: $difference');
              callback(revision, exist, difference);
            } else {
              print('No hash difference for ${exist.root.root.uri.realName}');
            }
//        }

        previousHashes[exist] = theseHashes;
        exist.root.rootLocal.revision = revision.revision;
      }
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
}
