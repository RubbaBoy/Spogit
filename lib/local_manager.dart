import 'dart:async';
import 'dart:io';

import 'package:Spogit/Spogit.dart';
import 'package:Spogit/cache/cache_manager.dart';
import 'package:Spogit/cache/cover_resource.dart';
import 'package:Spogit/driver/driver_api.dart';
import 'package:Spogit/driver/playlist_manager.dart';
import 'package:Spogit/fs/playlist.dart';
import 'package:Spogit/utility.dart';
import 'package:logging/logging.dart';

const bool APPLY_COVERS = false;

class LocalManager {
  final log = Logger('LocalManager');

  final Spogit spogit;
  final DriverAPI driverAPI;
  final CacheManager cacheManager;
  final Directory root;
  final List<LinkedPlaylist> linkedPlaylists = [];

  LocalManager(this.spogit, this.driverAPI, this.cacheManager, this.root);

  /// Should be invoked once at the beginning for initialization.
  Future<List<LinkedPlaylist>> getExistingRoots(
      BaseRevision baseRevision) async {
    linkedPlaylists.clear();
    for (var dir in root.listSync()) {
      if ([dir, 'meta.json'].file.existsSync()) {
        print('Found a directory with a meta.json in it: ${dir.path}');

        if ([dir, 'local'].file.existsSync()) {
          log.fine('Directory has already been locally synced');
          var linked = LinkedPlaylist.preLinked(spogit, this, dir);

          var rootLocal = linked.root.rootLocal;

          log.fine(
              'rootLocalRev = ${rootLocal.revision} baseRev = ${baseRevision.revision}');

          // TODO: Check if the contents have changed instead of just revision #
          if (rootLocal.revision != baseRevision.revision) {
            log.fine('Revisions do not match, pulling Spotify changes to local');
            await linked.refreshFromRemote();
          }

          linkedPlaylists.add(linked);
        } else {
          log.fine(
              'Directory has not been locally synced, creating and pushing to remote now');
          var local = LinkedPlaylist.fromLocal(spogit, this, dir);
          await local.initLocal(true);
          linkedPlaylists.add(local);
        }
      }
    }

    return linkedPlaylists;
  }

  /// Gets the LinkedPlaylist from any [id] it contains.
  LinkedPlaylist getFromAnyId(String name) =>
      linkedPlaylists.firstWhere((linked) => linked.root.root.uri.realName == name, orElse: () => null);

  void addPlaylist(LinkedPlaylist linkedPlaylist) =>
      linkedPlaylists.add(linkedPlaylist);

  LinkedPlaylist getPlaylist(Directory directory) =>
      linkedPlaylists.firstWhere((playlist) => playlist.root.root == directory,
          orElse: () => null);

  /// If the given [url] is different than what is in the cache, the cache will
  /// be updated and this new [url] will be returned. If the [url] matches the
  /// cached version, null is returned.
  String getCoverUrl(String id, String url) {
    if (url == null) {
      return null;
    }

    var generated = cacheManager
        .getOrSync<PlaylistCoverResource>(
            id, () => PlaylistCoverResource(id, url),
            forceUpdate: (resource) => resource.data != url ?? true)
        .generated;
    return generated ? url : null;
  }
}

class LinkedPlaylist {
  final log = Logger('LinkedPlaylist');

  final Spogit spogit;
  final LocalManager localManager;
  final CacheManager cacheManager;
  final DriverAPI driverAPI;
  final SpogitRoot root;

  PlaylistManager get playlists => driverAPI.playlistManager;

  /// A flat list of [RevisionElement]s
  List<RevisionElement> elements;

  /// Creates a [LinkedPlaylist] from
  LinkedPlaylist.preLinked(this.spogit, this.localManager, Directory directory)
      : cacheManager = spogit.cacheManager,
        driverAPI = spogit.driverAPI,
        root = SpogitRoot(spogit, directory) {
    elements = <RevisionElement>[];
  }

  /// Creates a [LinkedPlaylist] from an already populated purley local
  /// directory in ~/Spogit. Upon creation, this will update the Spotify API
  /// if no `local` files are found.
  LinkedPlaylist.fromLocal(this.spogit, this.localManager, Directory directory)
      : cacheManager = spogit.cacheManager,
        driverAPI = spogit.driverAPI,
        root = SpogitRoot(spogit, directory, creating: true) {
    elements = <RevisionElement>[];
  }

  /// Creates a [LinkedPlaylist] from a given [BaseRevision] and list of
  /// top-level Spotify folders/playlists as [elementIds]. This means that it
  /// should not be fed a child playlist or folder.
  LinkedPlaylist.fromRemote(this.spogit, this.localManager, Directory spogitPath, String name,
      BaseRevision baseRevision, List<String> elementIds)
      : cacheManager = spogit.cacheManager,
        driverAPI = spogit.driverAPI,
        root = SpogitRoot(spogit, [spogitPath, name].directoryRaw,
            creating: true, tracking: elementIds) {
    root.rootLocal.revision = baseRevision.revision;

    updateElements(baseRevision, elementIds);

    cacheManager.clearCacheFor(elements.map((element) => element.id).toList());
  }

  void updateElements(BaseRevision baseRevision, List<String> elementIds) {
    elements = <RevisionElement>[];

    elementIds.parseAll();
    for (var element in baseRevision.elements
        .where((element) => elementIds.contains(element.id))) {
      if (element.type == ElementType.FolderStart) {
        // Gets the elements starting from the start going over all children, and plus the end folder
        elements.addAll(baseRevision.elements
            .sublist(element.index, element.index + element.children + 1));
      } else {
        elements.add(element);
      }
    }

    var playlistCount = elements.where((element) => element.type == ElementType.Playlist).length;

    log.info('Processing $playlistCount playlists...');
  }

  /// Returns a list of root watching IDs
  Future<List<String>> initLocal([bool forceCreate = true]) async {
    Future<String> traverse(
        Mappable mappable, List<SpotifyFolder> parents) async {
      var to = parents.safeLast?.spotifyId;

      if (mappable.spotifyId != null && !forceCreate) {
        return null;
      }

      if (mappable is SpotifyPlaylist) {
        var id = (await playlists.createPlaylist(
            mappable.name, mappable.description))['id'];

        if (APPLY_COVERS) {
          await playlists.uploadCover(mappable.coverImage, id);
        }

        await playlists.movePlaylist(id, toGroup: to);

        await playlists.addTracks(
            id, mappable.songs.map((song) => song.id).toList());

        mappable.spotifyId = id;
        return id;
      } else if (mappable is SpotifyFolder) {
        var id = (await playlists.createFolder(mappable.name,
            toGroup: to))['id'] as String;
        mappable.spotifyId = id;

        for (var child in mappable.children) {
          await traverse(child, [...parents, mappable]);
        }

        return id;
      }

      return null;
    }

    var pl = root.children;
    var res = <String>[];

    for (var child in pl) {
      res.add(await traverse(child, []));
    }

    root.rootLocal.tracking = res;

    return res;
  }

  /// Initializes the [root] with the set [elements] via [updateElements].
  Future<void> initElement() async {
    await parseElementsToContainer(root, elements);

    await root.save();
  }

  Future<void> refreshFromRemote() async {
    root.root.deleteSync(recursive: true);
    await initElement();
    await root.save();
  }

  Future<void> pullRemote(BaseRevision baseRevision, List<String> ids) async {
    print(root.children.map((map) => map.spotifyId).join(', '));
    var mappables =
        root.children.where((mappable) => ids.contains(mappable.spotifyId));

    if (mappables.isEmpty) {
      return;
    }

    // So currently the local elements (flat) have not been updated and are out of date.
    // baseRevision is updated, with a flat element list, and only "ids" should be updated
    // So we need to take local root and replace the overlapping stuff

//    print('Outdated elements: $elements');

    elements.clear();
    elements.addAll(baseRevision.elements);

    var idMap = elements
        .where((element) =>
            element.type != ElementType.FolderEnd && ids.contains(element.id))
        .toList()
        .asMap()
        .map((i, element) => MapEntry(element.id, element));

    for (var id in ids) {
      var element = idMap[id];
      if (element.type == ElementType.Playlist) {
        var playlistDetails =
            await driverAPI.playlistManager.getPlaylistInfo(id);

        root.replacePlaylist(id)
          ..name = element.name
          ..description = playlistDetails.description
          ..imageUrl = localManager.getCoverUrl(
              id, playlistDetails.images?.safeFirst?.url)
          ..songs = List<SpotifySong>.from(playlistDetails?.tracks?.items
                  ?.map((track) {
                    // TODO: Investigate
                    var song = SpotifySong.fromJson(spogit, track);
                    if (song.id == null) {
                      print('id null from json');
                      print('from id $id | $element');
                      print(playlistDetails.toJson());
                    }
                    return song;
                  }) ??
              const []);
      } else if (element.type == ElementType.FolderStart) {
        var replaced = root.replaceFolder(id);
        var start = element.index;
        var end = element.index + element.moveCount;
        if (++start >= --end) {
          // This should never happen
          log.fine('start >= end so not copying anything over');
          continue;
        }

        await parseElementsToContainer(replaced, elements.sublist(start, end));
      }
    }

    await root.save();
  }

  Future<void> parseElementsToContainer(
      SpotifyContainer container, List<RevisionElement> elements) async {
    // Was just `current = root` before, not sure if changing this will work?
    var current = container;
    for (var element in elements) {
      var id = element.id;
      switch (element.type) {
        case ElementType.Playlist:
          var playlistDetails =
              await driverAPI.playlistManager.getPlaylistInfo(id);

          current.addPlaylist(element.name)
            ..spotifyId = id
            ..name = element.name
            ..description = playlistDetails.description
            ..imageUrl = localManager.getCoverUrl(
                id, playlistDetails.images?.safeFirst?.url)
            ..songs = List<SpotifySong>.from(playlistDetails?.tracks?.items
                    ?.map((track) => SpotifySong.fromJson(spogit, track)) ??
                const []);
          break;
        case ElementType.FolderStart:
          current = (current.addFolder(element.name)..spotifyId = id);
          break;
        case ElementType.FolderEnd:
          current = current.parent;
          break;
      }
    }
  }
}
