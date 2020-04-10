import 'dart:async';
import 'dart:io';

import 'package:Spogit/auth_retriever.dart';
import 'package:Spogit/url_browser.dart';
import 'package:oauth2/oauth2.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart';
import 'package:spotify/spotify.dart';
import 'utility.dart';


Future<void> authenticate() async {
  final credentials = await AuthRetriever().getCredentials();
  final spotify = SpotifyApi.fromClient(Client(credentials));

  (await spotify.playlists.me.all()).forEach((playlist) {
    print('Playlist ${playlist.id} - ${playlist.name} by ${playlist.owner.displayName}');
  });
}
