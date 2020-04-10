import 'dart:async';
import 'dart:isolate';

import 'package:Spogit/auth/auth_store.dart';
import 'package:Spogit/auth/tracked_credentials.dart';
import 'package:Spogit/url_browser.dart';
import 'package:oauth2/oauth2.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart';

import 'utility.dart';

final tokenUrl = Uri.parse('https://accounts.spotify.com/api/token');

class AuthRetriever {

  final AuthStore authStore = AuthStore('~/Spogit/creds.json'.file);
  final int port;

  AuthRetriever([this.port = 8085]);

  Future<Credentials> getCredentials() async =>
      authStore.readData()?.toCredentials() ?? _fetchCredentials();

  Future<Credentials> _fetchCredentials() async {
    print('Manually retrieving credentials');

    var url = 'http://localhost:8080/login?p=${port.fixedLeftPad(5)}';

    browseUrl(url);

    print('If a browser has not been opened, go to:\n$url');

    var creds = await _listenForCreds(port);

    return TrackedCredentials(creds['access_token'],
        creds['refresh_token'],
        int.parse(creds['expires_in']),
        tokenUrl,
        creds['scope'].split(' '), (cred) {
          print('Token refreshed!');
          cred.saveCredentials(authStore);
        })..saveCredentials(authStore);
  }

  Future<Map<String, String>> _listenForCreds(int port) async {
    final completer = Completer<Map<String, String>>();

    var server;
    server = await serve(
        Pipeline().addHandler((request) {
          completer.complete(request.requestedUri.queryParameters);
          server.close();
          return Response.ok('You may close this tab');
        }),
        'localhost',
        port);

    return completer.future;
  }
}