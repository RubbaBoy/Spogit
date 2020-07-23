import 'dart:async';

import 'package:Spogit/cache/cache_manager.dart';
import 'package:Spogit/driver/driver_api.dart';
import 'package:Spogit/driver/playlist_manager.dart';
import 'package:Spogit/fs/playlist.dart';
import 'package:Spogit/local_manager.dart';
import 'package:Spogit/utility.dart';
import 'package:logging/logging.dart';

class ChangeWatcher {
  final log = Logger('ChangeWatcher');

  final DriverAPI driverAPI;
  final int treeDuration;
  final int playlistDuration;
  bool _lock = false;
  bool _nextUnlock = false;

  // The last etag for the playlist tree request
  String previousETag;

  ChangeWatcher(this.driverAPI, {this.treeDuration = 2, this.playlistDuration = 2});

  void lock() {
    _lock = true;
    previousETag = '';
  }

  void unlock() {
    _nextUnlock = true;
  }

  /// Watches for changes in the playlist tree
  void watchAllChanges(Function(BaseRevision) callback) {

    Timer.periodic(Duration(seconds: treeDuration), (timer) async {
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
        log.fine('Playlist tree has changed!');
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
      log.fine('It has changed on the Spotify side!');

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
        log.fine(
            'previous = ${prevHash.keys.toList().map((k) => '$k: ${prevHash[k].toRadixString(16)}').join(', ')}');
        log.fine(
            'theseHashes = ${theseHashes.keys.toList().map((k) => '$k: ${theseHashes[k].toRadixString(16)}').join(', ')}');

        if (difference.isNotEmpty) {
          log.fine(
              'Difference between hashes! Reloading ${exist.root.root.uri.realName} trackingIds: $difference');
          callback(revision, exist, difference.toList());
        } else {
          log.fine('No hash difference for ${exist.root.root.uri.realName}');
        }

        previousHashes[exist] = theseHashes;
        exist.root.rootLocal.revision = revision.revision;
      }
    });
  }

  /// Watches for changes in any playlist tracks or meta. [callback] is invoked
  /// with a parsed playlist ID every time it is updated.
  void watchPlaylistChanges(LocalManager localManager, Future<Map<SpogitRoot, Map<String, String>>> Function(Map<String, String>) callback) {
    // parsed playlist ID, snapshot
    final allSnapshots = <String, String>{};

    for (var linked in localManager.linkedPlaylists) {
      allSnapshots.addAll(trimStuff(linked.root.rootLocal.snapshotIds));
    }

    Timer.periodic(Duration(seconds: playlistDuration), (timer) async {
      if (_lock) {
        return;
      }

      var snapshots = trimStuff(await driverAPI.playlistManager.getPlaylistSnapshots());
      if (allSnapshots.isEmpty) {
        allSnapshots.addAll(snapshots);
        return;
      }

      var diff = _getDifference(allSnapshots, snapshots);
      if (diff.isNotEmpty) {
        await callback(diff).then((map) {
          for (var root in map.keys) {
            var local = root.rootLocal;
            local.snapshotIds = {...local.snapshotIds, ...map[root]};
            local.saveFile();
          }
        });

//        allSnapshots.clear();
        allSnapshots.addAll(snapshots);
      }
    });
  }

  Map<String, String> trimStuff(Map<String, String> map) => map.map((k, v) => MapEntry(k, v.substring(31)));

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
