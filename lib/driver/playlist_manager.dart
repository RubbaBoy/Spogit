import 'dart:convert';

import 'package:Spogit/driver/driver_request.dart';
import 'package:Spogit/driver/js_communication.dart';
import 'package:webdriver/sync_io.dart';

class PlaylistManager {
  final WebDriver _driver;
  final RequestManager _requestManager;
  BaseRevision baseRevision;

  PlaylistManager._(this._driver, this._requestManager);

  static Future<PlaylistManager> createPlaylistManager(WebDriver driver,
      RequestManager requestManager, JSCommunication communication) async {
    print('Listening to shit');

    communication.stream.listen((message) {
      if (message.type == 'auth') {
        if (message.value.startsWith('Bearer ')) {
          requestManager.authToken = message.value.substring(7);
        }
      }
    });

    driver.execute('''
        const authSocket = new WebSocket(`ws://localhost:6979`);
        constantMock = window.fetch;
        window.fetch = function() {
            if (arguments.length === 2) {
                if (arguments[0].startsWith('https://api.spotify.com/')) {
                    let headers = arguments[1].headers || {};
                    let auth = headers.authorization;
                    if (auth != null) {
                        authSocket.send(JSON.stringify({'type': 'auth', 'value': auth}));
                    }
                }
            }
            return constantMock.apply(this, arguments)
        }
    ''', []);

    return PlaylistManager._(driver, requestManager);
  }

  Future<BaseRevision> analyzeBaseRevision() async {
    var response = await _requestManager.makeRequest(DriverRequest(
      method: 'GET',
      uri: Uri.parse(
          'https://spclient.wg.spotify.com/playlist/v2/user/rubbaboy/rootlist?decorate=revision%2Clength%2Cattributes%2Ctimestamp%2Cowner&market=from_token'),
    ));

    if (response.status != 200) {
      throw 'Status ${response.status}: ${response.body['error']['message']}';
    }

    return BaseRevision.fromJson(response.body);
  }

  Future<String> movePlaylist(String moving,
      {String toGroup, int offset = 0, int absolutePosition}) async {
    var baseRevision = await analyzeBaseRevision();

    absolutePosition ??= baseRevision.getIndexOf(toGroup) + offset;
    var fromIndex = baseRevision.getIndexOf(moving);

    var body = {
      'baseRevision': baseRevision.revision,
      'deltas': [
        {
          'ops': [
            {
              'kind': 'MOV',
              'mov': {
                'fromIndex': fromIndex,
                'toIndex': absolutePosition,
                'length': 1
              }
            }
          ],
          'info': {
            'source': {'client': 'WEBPLAYER'}
          }
        }
      ]
    };

    print('body = ${jsonEncode(body)}');

    var response = await _requestManager.makeRequest(DriverRequest(
      uri: Uri.parse(
          'https://spclient.wg.spotify.com/playlist/v2/user/rubbaboy/rootlist/changes'),
      body: body,
    ));

    if (response.status != 200) {
      throw 'Status ${response.status}: ${response.body['error']['message']}';
    }

    var rev = response.body['revision'];
    print('Current base revision: $rev');
    return rev;
  }
}

class BaseRevision {
  final String revision;
  final List<RevisionElement> elements;

  BaseRevision.fromJson(Map<String, dynamic> json)
      : revision = json['revision'],
        elements = List<RevisionElement>.from(json['contents']['items']
            .asMap()
            .map((i, elem) => MapEntry(i, RevisionElement.fromJson(i, Map<String, dynamic>.from(elem))))
            .values);

  // The element will be inserted BEFORE the given ID. So if you want to add
  // something before the playlist at index 1, you would give it index 1.

  int getIndexOf(String id) {
    id = RevisionElement.parseId(id);
    return elements
          .firstWhere((revision) => revision.id == id, orElse: () => null)
          ?.index ??
      0;
  }
}

class RevisionElement {
  final int index;
  final int timestamp;
  final bool public;
  final String id;
  final ElementType type;

  const RevisionElement._(
      this.index, this.timestamp, this.public, this.id, this.type);

  RevisionElement.fromJson(this.index, Map<String, dynamic> json)
      : timestamp = int.parse(json['attributes']['timestamp']),
        public = json['attributes']['public'] ?? false,
        id = parseId(json['uri']),
        type = parseElementType(json['uri']);

  static String parseId(String uri) => uri.split(':')[2];

  static ElementType parseElementType(String uri) =>
      uri.split(':')[1] == 'playlist'
          ? ElementType.Playlist
          : ElementType.Folder;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RevisionElement &&
          runtimeType == other.runtimeType &&
          index == other.index;

  @override
  int get hashCode => index.hashCode;
}

enum ElementType { Folder, Playlist }
