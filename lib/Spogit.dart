import 'dart:async';
import 'dart:io';

import 'package:Spogit/cache/cache_manager.dart';
import 'package:Spogit/cache/cache_types.dart';
import 'package:Spogit/cache/playlist_cover.dart';
import 'package:Spogit/change_watcher.dart';
import 'package:Spogit/driver/driver_api.dart';
import 'package:Spogit/driver/playlist_manager.dart';
import 'package:Spogit/fs/playlist.dart';
import 'package:Spogit/local_manager.dart';

class Spogit {
  final DriverAPI driverAPI;
  final CacheManager cacheManager;

  PlaylistManager get playlistManager => driverAPI?.playlistManager;

  Spogit._(this.driverAPI, this.cacheManager);

  static Future<Spogit> createSpogit(File cacheFile) async {
    final cacheManager = CacheManager(cacheFile)
      ..registerType(CacheType.PLAYLIST_COVER, (id, map) => PlaylistCoverResource.fromPacked(id, map));
    await cacheManager.readCache();
    cacheManager.scheduleWrites();

    final driverAPI = DriverAPI();
    await driverAPI.startDriver();
    return Spogit._(driverAPI, cacheManager);
  }

  Future<void> start(Directory path) async {
    final changeWatcher = ChangeWatcher(driverAPI);

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

    final manager = LocalManager(driverAPI, cacheManager, path);

    final existing = manager.getExistingRoots(currRevision);

    print('Got ${existing.length} existing');

    for (var exist in existing) {
      await exist.initElement();
      print('\nExisting:');
      print(exist.root.rootLocal.id);
      print(exist.root);
    }

    changeWatcher.watchChanges(currRevision, existing,
        (baseRevision, linkedPlaylist, ids) {
      print('Pulling remote');
      linkedPlaylist.pullRemote(baseRevision, ids);
    });

    print('Watching for playlist changes...');
    changeWatcher.watchPlaylistChanges((changed) async {
      for (var id in changed.keys) {
        bruh:
        for (var exist in existing) {
          var searched = exist.root.searchForId(id) as SpotifyPlaylist;
          if (searched != null) {
            var playlistDetails = await playlistManager.getPlaylistInfo(id);

            searched
              ..description = playlistDetails['description']
              ..imageUrl = manager.getCoverUrl(id, playlistDetails['images'][0]['url'])
              ..songs = List<SpotifySong>.from(playlistDetails['tracks']
                      ['items']
                  .map((track) => SpotifySong.fromJson(track)));
            await searched.save();

            break bruh;
          }
        }
      }

      print('Updated change stuff');
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
