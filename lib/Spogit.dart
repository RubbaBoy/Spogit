import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:Spogit/auth_retriever.dart';
import 'package:Spogit/file_watcher.dart';
import 'package:Spogit/url_browser.dart';
import 'package:oauth2/oauth2.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart';
import 'package:spotify/spotify.dart';
import 'utility.dart';
import 'package:http/http.dart' as http;
import 'package:Spogit/fs/playlist_tree_parser.dart';

Future<void> startDaemon(Directory path) async {
  final credentials = await AuthRetriever().getCredentials();
  final spotify = SpotifyApi.fromClient(Client(credentials));

//  (await spotify.playlists.createPlaylist(auserId, playlistName)).
//
//  final watcher = FileWatcher(path);
//
//  watcher.listenChange((root) {
//    print('Creates playlist!');
//  });

  var me = await spotify.users.me();

  print('me = $me');

  print('rubbaboy = ${me.id} or maybe ${me.displayName}');

  getFolders().listen((entities) {
    print('\n\n\nUPDATE! ==============================');
    for (var value in entities) {
      print(value);
    }
    print('--- ============================== ---');
  });



//  print('Watching $path');
//  path.watch(recursive: true).listen((event) {
//    var dir = event.path.directory;
//
//
//
//    print('[${event.path}] ${event.type}');
//  });

//  (await spotify.playlists.me.all()).forEach((playlist) {
//    print('Playlist ${playlist.id} - ${playlist.name} by ${playlist.owner.displayName}');
//  });
}
