import 'dart:io';

import 'package:Spogit/driver/driver_api.dart';
import 'package:Spogit/driver/playlist_manager.dart';
import 'package:Spogit/fs/playlist.dart';
import 'package:Spogit/utility.dart';

class LocalManager {
  final DriverAPI driverAPI;
  final Directory root;

  LocalManager(this.driverAPI, this.root);

  /// Should be invoked once at the beginning for initialization.
  List<LinkedPlaylist> getExistingRoots(BaseRevision baseRevision) {
    var res = <LinkedPlaylist>[];
    for (var dir in root.listSync()) {
      if ([dir, 'local'].file.existsSync()) {
        print('Found a directory with local in it: ${dir.path}');
        var linked = LinkedPlaylist.preLinked(driverAPI, dir);

        var rootLocal = linked.root.rootLocal;

        print('rootLocalRev = ${rootLocal.revision} baseRev = ${baseRevision.revision}');
        // TODO: Check if the contents have changed instead of just revision #
        if (rootLocal.revision != baseRevision.revision) {
          print('Revisions do not match, pulling Spotify changes to local');

          // TODO: Do more in-depth checks to see if each of the shit being used has changed

          linked.refreshFromRemote();
        }

        res.add(linked);
      }
    }
    return res;
  }
}

class LinkedPlaylist {
  final DriverAPI driverAPI;
  final SpogitRoot root;

  PlaylistManager get playlists => driverAPI.playlistManager;

  /// A flat list of [RevisionElement]s
  List<RevisionElement> elements;

  /// Creates a [LinkedPlaylist] from
  LinkedPlaylist.preLinked(this.driverAPI, Directory directory)
      : root = SpogitRoot(directory) {
    elements = <RevisionElement>[];
  }

  /// Creates a [LinkedPlaylist] from an already populated purley local
  /// directory in ~/Spogit. Upon creation, this will update the Spotify API
  /// if no `local` files are found.
  LinkedPlaylist.fromLocal(this.driverAPI, Directory directory)
      : root = SpogitRoot(directory, creating: true) {
    print('Updating Spotify API');

    elements = <RevisionElement>[];
  }

  /// Creates a [LinkedPlaylist] from a given [BaseRevision] and list of
  /// top-level Spotify folders/playlists as [elementIds]. This means that it
  /// should not be fed a child playlist or folder.
  LinkedPlaylist.fromRemote(this.driverAPI, String name,
      BaseRevision baseRevision, List<String> elementIds)
      : root = SpogitRoot('~/Spogit/$name'.directory, creating: true, tracking: elementIds) {
    root.rootLocal.revision = baseRevision.revision;

    print('Updating local');

    elements = <RevisionElement>[];

    elementIds = elementIds.map((id) => id.parseId).toList();
    for (var element in baseRevision.elements
        .where((element) => elementIds.contains(element.id))) {
      if (element.type == ElementType.Playlist) {
        elements.add(element);
      } else if (element.type == ElementType.FolderStart) {
        // Gets the elements starting from the start going over all children, and plus the end folder
        elements.addAll(baseRevision.elements
            .sublist(element.index, element.index + element.children + 1));
      }
    }
  }

  Future<void> initLocal([bool forceCreate = true]) async {
    Future<void> traverse(
        Mappable mappable, List<SpotifyFolder> parents) async {
      var to = parents.safeLast?.spotifyId;

      if (mappable.spotifyId != null && !forceCreate) {
        return;
      }

      if (mappable is SpotifyPlaylist) {
        print('Creating playlist "${mappable.name}" in #$to');

        var id = (await playlists.createPlaylist(mappable.name))['id'];

        await playlists.movePlaylist(id, toGroup: to);

        await playlists.addTracks(
            id, mappable.songs.map((song) => song.id).toList());

        print('Created previous with an ID of $id');
        mappable.spotifyId = id;
      } else if (mappable is SpotifyFolder) {
        print('Creating folder "${mappable.name}" in #$to');

        var id =
            (await playlists.createFolder(mappable.name, toGroup: to))['id'];
        mappable.spotifyId = id;

        mappable.children
            .forEach((child) => traverse(child, [...parents, mappable]));
      }
    }

    var pl = root.playlists;
    print('playlist  = $pl');
    pl.forEach((child) => traverse(child, []));
  }

  void traverse(Function(Mappable, List<SpotifyFolder>) callback) {
    void bruh(Mappable mappable, List<SpotifyFolder> parents) {
      if (mappable is SpotifyPlaylist) {
        callback(mappable, parents);
      } else if (mappable is SpotifyFolder) {
        mappable.children.forEach((child) {
          callback(child, parents);
          bruh(child, [...parents, mappable]);
        });
      }
    }

    root.playlists.forEach((child) => bruh(child, []));
  }

  Future<void> initElement() async {
    print('Local list comprises of:');
    print(elements.map((el) => el.toString()).join('\n'));

    SpotifyContainer current = root;

    for (var element in elements) {
      var id = element.id;
      switch (element.type) {
        case ElementType.Playlist:
          var playlistDetails =
              await driverAPI.playlistManager.getPlaylistInfo(id);

          current.addPlaylist(element.name)
            ..spotifyId = id
            ..name = element.name
            ..description = playlistDetails['description']
            ..songs = List<SpotifySong>.from(playlistDetails['tracks']['items']
                .map((track) => SpotifySong.create(track['track']['id'])));
          break;
        case ElementType.FolderStart:
          current = (current.addFolder(element.name)..spotifyId = id);
          break;
        case ElementType.FolderEnd:
          current = current.parent;
          break;
      }
    }

    root.save();

    print('root =\n$root');
  }

  Future<void> refreshFromRemote() async {
    print('bout to ${root.root.path}');
    await root.root.delete(recursive: true);
    print('done');
    await initElement();
    root.save();
  }
}
