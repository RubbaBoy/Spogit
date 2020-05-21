import 'dart:async';
import 'dart:io';

import 'package:Spogit/cache/album/album_resource_manager.dart';
import 'package:Spogit/cache/cache_manager.dart';
import 'package:Spogit/cache/cache_types.dart';
import 'package:Spogit/cache/cover_resource.dart';
import 'package:Spogit/cache/id/id_resource.dart';
import 'package:Spogit/cache/id/id_resource_manager.dart';
import 'package:Spogit/change_watcher.dart';
import 'package:Spogit/driver/driver_api.dart';
import 'package:Spogit/driver/playlist_manager.dart';
import 'package:Spogit/fs/playlist.dart';
import 'package:Spogit/git_hook.dart';
import 'package:Spogit/input_controller.dart';
import 'package:Spogit/local_manager.dart';
import 'package:Spogit/utility.dart';
import 'package:logging/logging.dart';

class Spogit {
  final log = Logger('Spogit');

  final GitHook gitHook;
  final ChangeWatcher changeWatcher;
  final DriverAPI driverAPI;
  final CacheManager cacheManager;
  final IdResourceManager idResourceManager;
  final AlbumResourceManager albumResourceManager;

  PlaylistManager get playlistManager => driverAPI?.playlistManager;

  Spogit._(this.gitHook, this.changeWatcher, this.driverAPI, this.cacheManager,
      this.idResourceManager, this.albumResourceManager);

  static Future<Spogit> createSpogit(File cookiesFile, File chromedriverFile, File cacheFile, {int treeDuration = 2, int playlistDuration = 2}) async {
    final cacheManager = CacheManager(cacheFile)
      ..registerType(CacheType.PLAYLIST_COVER,
          (id, map) => PlaylistCoverResource.fromPacked(id, map))
      ..registerType(CacheType.ID, (id, map) => IdResource.fromPacked(id, map));
    await cacheManager.readCache();
    cacheManager.scheduleWrites();

    final driverAPI = DriverAPI(cookiesFile, chromedriverFile);
    await driverAPI.startDriver();

    final changeWatcher = ChangeWatcher(driverAPI, treeDuration: treeDuration, playlistDuration: playlistDuration);
    final gitHook = GitHook();

    final idResourceManager =
        IdResourceManager(driverAPI.playlistManager, cacheManager);
    final albumResourceManager =
        AlbumResourceManager(driverAPI.playlistManager, cacheManager);

    return Spogit._(gitHook, changeWatcher, driverAPI, cacheManager,
        idResourceManager, albumResourceManager);
  }

  Future<void> start(Directory path) async {
    final manager = LocalManager(this, driverAPI, cacheManager, path);
    final inputController = InputController(this, manager);

    await gitHook.listen();
    gitHook.postCheckout.stream.listen((data) async {
      var wd = data.workingDirectory;

      if (directoryEquals(wd.parent, path)) {
        var foundLocal = manager.getPlaylist(wd);
        if (foundLocal == null) {
          log.info('Creating playlist at ${wd.path}');

          changeWatcher.lock();

          var linked =
              LinkedPlaylist.fromLocal(this, manager, normalizeDir(wd).directory);
          manager.addPlaylist(linked);
          var tracking = await linked.initLocal();
          await linked.root.save();

          Timer(Duration(seconds: 2), () => changeWatcher.unlock());
        } else {
          log.info(
              'Playlist already exists locally! No need to create it, updating from local...');
          await foundLocal.initLocal();
        }
      } else {
        log.warning('Not a direct child in ${path.path}');
      }
    });

    var currRevision = await playlistManager.analyzeBaseRevision();

    final existing = await manager.getExistingRoots(currRevision);

    log.info('Got ${existing.length} existing');

    changeWatcher.watchChanges(currRevision, existing,
        (baseRevision, linkedPlaylist, ids) => linkedPlaylist.pullRemote(baseRevision, ids));

    log.info('Watching for playlist changes...');
    changeWatcher.watchPlaylistChanges(manager, (changed) async {
      var res = <SpogitRoot, Map<String, String>>{};
      for (var id in changed.keys) {
        bruh:
        for (var exist in existing) {
          var searched = exist.root.searchForId(id) as SpotifyPlaylist;
          if (searched != null) {
            var playlistDetails = await playlistManager.getPlaylistInfo(id);

            res.putIfAbsent(exist.root, () => <String, String>{})[id] = changed[id];

            searched
              ..description = playlistDetails.description
              ..imageUrl = manager.getCoverUrl(
                  id, playlistDetails.images?.safeFirst?.url)
              ..songs = List<SpotifySong>.from(playlistDetails?.tracks?.items
                  ?.map((track) => SpotifySong.fromJson(this, track)) ?? const []);
            await searched.save();

            break bruh;
          }
        }
      }

      log.info('Updated change stuff: ${changed}');
      return res;
    });

    inputController.start();
  }

  bool directoryEquals(Directory one, Directory two) =>
      listEquals(normalizeDir(one), normalizeDir(two));

  List<String> normalizeDir(Directory directory) {
    var segments = directory.uri.pathSegments;
    return [
      ...segments
    ]..replaceRange(0, 1, ['${segments.first.substring(0, 1).toLowerCase()}:']);
  }
}
