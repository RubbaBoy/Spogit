import 'dart:async';

import 'package:Spogit/driver/driver_api.dart';
import 'package:Spogit/driver/playlist_manager.dart';
import 'package:Spogit/local_manager.dart';
import 'package:Spogit/utility.dart';

class ChangeWatcher {
  final DriverAPI driverAPI;
  bool _lock = false;
  bool _nextUnlock = false;

  // The last etag for the playlist tree request
  String previousETag;

  ChangeWatcher(this.driverAPI);

  void lock() {
    _lock = true;
    previousETag = '';
  }

  void unlock() {
    _nextUnlock = true;
  }

  /// Watches for changes in the playlist tree
  void watchAllChanges(Function(BaseRevision) callback) {

    Timer.periodic(Duration(seconds: 2), (timer) async {
      var etag = await driverAPI.playlistManager.baseRevisionETag();

      if (_lock) {
        previousETag = etag;
        _lock = !_nextUnlock;
        return;
      }

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
  void watchChanges(BaseRevision baseRevision, List<LinkedPlaylist> tracking,
      Function(BaseRevision, LinkedPlaylist, List<String>) callback) {
    var previousHashes = <LinkedPlaylist, Map<String, int>>{};

    for (var exist in tracking) {
      var theseHashes = <String, int>{};

      var trackingIds = exist.root.rootLocal?.tracking;
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

        for (var track in trackingIds) {
          var hash = revision.getHash(id: track);
          theseHashes[track] = hash;
        }

        var prevHash = {...previousHashes.putIfAbsent(exist, () => {})};

        var difference = _getDifference(prevHash, theseHashes).keys;
        print(
            'previous = ${prevHash.keys.toList().map((k) => '$k: ${prevHash[k].toRadixString(16)}').join(', ')}');
        print(
            'theseHashes = ${theseHashes.keys.toList().map((k) => '$k: ${theseHashes[k].toRadixString(16)}').join(', ')}');

        if (difference.isNotEmpty) {
          print(
              'Difference between hashes! Reloading ${exist.root.root.uri.realName} trackingIds: $difference');
          callback(revision, exist, difference.toList());
        } else {
          print('No hash difference for ${exist.root.root.uri.realName}');
        }

        previousHashes[exist] = theseHashes;
        exist.root.rootLocal.revision = revision.revision;
      }
    });
  }

  /// Watches for changes in any playlist tracks or meta. [callback] is invoked
  /// with a parsed playlist ID every time it is updated.
  void watchPlaylistChanges(Function(Map<String, String>) callback) {
    // parsed playlist ID, snapshot
    final allSnapshots = <String, String>{};
    Timer.periodic(Duration(seconds: 2), (timer) async {
      var snapshots = await driverAPI.playlistManager.getPlaylistSnapshots();
      if (allSnapshots.isEmpty) {
        allSnapshots.addAll(snapshots);
        return;
      }

      var diff = _getDifference(allSnapshots, snapshots);
      if (diff.isNotEmpty) {
        callback(diff);
        allSnapshots.clear();
        allSnapshots.addAll(snapshots);
      }
    });
  }

  Map<K, V> _getDifference<K, V>(Map<K, V> first, Map<K, V> second) {
    var res = <K, V>{};
    void checkMaps(Map<K, V> one, Map<K, V> two) {
      for (var id in one.keys) {
        if (!two.containsKey(id) || two[id] != one[id]) {
          res[id] = one[id];
        }
      }
    }

    checkMaps(first, second);
    checkMaps(second, first);

    return res;
  }
}
