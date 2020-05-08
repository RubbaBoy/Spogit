import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:Spogit/cache/cache_manager.dart';
import 'package:Spogit/cache/cache_types.dart';
import 'package:Spogit/cache/playlist_cover.dart';
import 'package:Spogit/change_watcher.dart';
import 'package:Spogit/driver/driver_api.dart';
import 'package:Spogit/driver/playlist_manager.dart';
import 'package:Spogit/fs/playlist.dart';
import 'package:Spogit/git_hook.dart';
import 'package:Spogit/input_controller.dart';
import 'package:Spogit/local_manager.dart';
import 'package:Spogit/utility.dart';

class Spogit {
  final GitHook gitHook;
  final ChangeWatcher changeWatcher;
  final DriverAPI driverAPI;
  final CacheManager cacheManager;

  PlaylistManager get playlistManager => driverAPI?.playlistManager;

  Spogit._(this.gitHook, this.changeWatcher, this.driverAPI, this.cacheManager);

  static Future<Spogit> createSpogit(File cacheFile) async {
    final cacheManager = CacheManager(cacheFile)
      ..registerType(CacheType.PLAYLIST_COVER, (id, map) => PlaylistCoverResource.fromPacked(id, map));
    await cacheManager.readCache();
    cacheManager.scheduleWrites();

    final driverAPI = DriverAPI();
    await driverAPI.startDriver();

    final changeWatcher = ChangeWatcher(driverAPI);
    final gitHook = GitHook();
    return Spogit._(gitHook, changeWatcher, driverAPI, cacheManager);
  }

  Future<void> start(Directory path) async {
    final manager = LocalManager(driverAPI, cacheManager, path);
    final inputController = InputController(driverAPI, manager);

    await gitHook.listen();
    gitHook.postCheckout.stream.listen((data) async {
      var wd = data.workingDirectory;

      if (directoryEquals(wd.parent, path)) {
        var foundLocal = manager.getPlaylist(wd);
        if (foundLocal == null) {
          print('Creating playlist at ${wd.path}');
          var linked = LinkedPlaylist.fromLocal(manager, normalizeDir(wd).directory);
          manager.addPlaylist(linked);
          await linked.initLocal();
        } else {
          print('Playlist already exists locally! No need to create it, updating from local...');
          await foundLocal.initLocal();
        }
      } else {
        print('Not a direct child in ${path.path}');
      }
    });

    var currRevision = await playlistManager.analyzeBaseRevision();

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
              ..imageUrl = manager.getCoverUrl(id, (SafeUtils(playlistDetails['images'])?.safeFirst ?? const {})['url'])
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

    inputController.start();
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

  bool directoryEquals(Directory one, Directory two) =>
      listEquals(normalizeDir(one), normalizeDir(two));

  List<String> normalizeDir(Directory directory) {
    var segments = directory.uri.pathSegments;
    return [...segments]..replaceRange(0, 1, ['${segments.first.substring(0, 1).toLowerCase()}:']);
  }
}
