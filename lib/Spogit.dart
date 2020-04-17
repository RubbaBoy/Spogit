import 'dart:async';
import 'dart:io';

import 'package:Spogit/auth_retriever.dart';
import 'package:Spogit/file_watcher.dart';
import 'package:oauth2/oauth2.dart';
import 'package:spotify/spotify.dart';

class Spogit {
  final Credentials _credentials;
  final SpotifyApi _spotify;
  final User me;

  Spogit._(this._credentials, this._spotify, this.me);

  static Future<Spogit> createSpogit() async {
    final credentials = await AuthRetriever().getCredentials();
    final spotify = SpotifyApi.fromClient(Client(credentials));
    return Spogit._(credentials, spotify, await spotify.users.me());
  }

  void startDaemon(Directory path) {
    final watcher = FileWatcher(path);

    /// Use the spotify API for stuff
    watcher.listenSpogit((root) {
      // Actual files changed spotify:playlist:4T8gh2JVgZoiGFutx04ErJ
      print('Spogit files have changed.');
      print(root.playlists.join('\n'));
    });

    /// Modify files to reflect the Spotify API
    watcher.listenSpotify((entities) {
      // Order changed
      for (var entity in entities) {
        print('Moved $entity to ${entity.parent}');
      }
    }, (entities) {
      // Playlists changed
      for (var entity in entities) {
        print('Modified the contents of $entity');
      }
    });
  }

  /// Creates a fresh playlist, adding it to Spotify
  void createFresh() {

  }

  /// Creates a Spogit playlist from an existing Spotify playlist. [playlistId]
  /// is the raw playlist ID.
  Future<void> createLinked(String playlistId) async {
    var playlist = await _spotify.users.playlist(me.id, playlistId);
    print('Creating a linked playlist with ${playlist.name} (${playlist.id})');
  }
}
