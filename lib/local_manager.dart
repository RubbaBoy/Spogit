import 'dart:io';

import 'package:Spogit/driver/driver_api.dart';
import 'package:Spogit/driver/playlist_manager.dart';
import 'package:Spogit/fs/playlist.dart';
import 'package:Spogit/utility.dart';

class LocalManager {}

class LinkedPlaylist {

  final DriverAPI driverAPI;
  final SpogitRoot root;

  /// A flat list of [RevisionElement]s
  List<RevisionElement> elements;

  /// Creates a [LinkedPlaylist] from an already populated purley local
  /// directory in ~/Spogit. Upon creation, this will update the Spotify API.
  LinkedPlaylist.fromLocal(this.driverAPI, Directory directory) : root = SpogitRoot(directory) {
    print('Updating Spotify API');
  }

  /// Creates a [LinkedPlaylist] from a given [BaseRevision] and list of
  /// top-level Spotify folders/playlists as [elementIds]. This means that it
  /// should not be fed a child playlist or folder.
  LinkedPlaylist.fromRemote(this.driverAPI, String name, BaseRevision baseRevision, List<String> elementIds)
      : root = SpogitRoot('~/Spogit/$name'.directory) {
    print('Updating local');

    elements = <RevisionElement>[];

    elementIds = elementIds.map((id) => id.parseId).toList();
    for (var element in baseRevision.elements.where((element) => elementIds.contains(element.id))) {

      if (element.type == ElementType.Playlist) {
        elements.add(element);
      } else if (element.type == ElementType.FolderStart) {
        // Gets the elements starting from the start going over all children, and plus the end folder
        elements.addAll(baseRevision.elements.sublist(
            element.index, element.index + element.children + 1));
      }
    }
  }

  Future<void> initElement() async {
    print('Local list comprises of:');
    print(elements.map((el) => el.toString()).join('\n'));

    SpotifyContainer current = root;

    for (var element in elements) {
      var id = element.id;
      switch (element.type) {
        case ElementType.Playlist:
          var tracks = (await driverAPI.playlistManager.getTracks(id))['tracks']['items'];
          current.addPlaylist(element.name)
            ..spotifyId = id
            ..songs = List<SpotifySong>.from(tracks.map((track) => SpotifySong.create(track['track']['id'])));
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
}
