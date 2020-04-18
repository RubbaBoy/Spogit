import 'dart:async';
import 'dart:convert';

import 'package:Spogit/driver/driver_request.dart';
import 'package:Spogit/driver/js_communication.dart';
import 'package:Spogit/utility.dart';
import 'package:webdriver/sync_io.dart';

class PlaylistManager {
  final WebDriver _driver;
  final RequestManager _requestManager;
  BaseRevision baseRevision;

  String get rootlistUrl =>
      'https://spclient.wg.spotify.com/playlist/v2/user/${_requestManager.personalData.id}/rootlist';

  String get apiUrl =>
      'https://api.spotify.com/v1/users/${_requestManager.personalData.id}';

  PlaylistManager._(this._driver, this._requestManager);

  static Future<PlaylistManager> createPlaylistManager(WebDriver driver,
      RequestManager requestManager, JSCommunication communication) async {
    return PlaylistManager._(driver, requestManager);
  }

  Future<BaseRevision> analyzeBaseRevision([String revision]) async {
    var response = await _requestManager.makeRequest(DriverRequest(
      method: 'GET',
      uri: Uri.parse(
          '$rootlistUrl?decorate=revision%2Clength%2Cattributes%2Ctimestamp%2Cowner&market=from_token').replace(queryParameters: {
        'decorate': 'revision,length,attributes,timestamp,owner',
        if (revision != null) ...{'revision': revision}
      }),
    ));

    if (response.status != 200) {
      throw 'Status ${response.status}: ${response.body['error']['message']}';
    }

    print('FULLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLL BODYYYYYYYYYYYYYYYYYY');

    print(jsonEncode(response.body));

    return BaseRevision.fromJson(response.body);
  }

  Future<Map<String, dynamic>> basedRequest(
      FutureOr<DriverResponse> Function(BaseRevision) makeRequest,
      [bool useBase = true]) async {
    var response =
        await makeRequest(useBase ? await analyzeBaseRevision() : null);

    if (response.status >= 300) {
      print('code = ${response.status}');
      throw 'Status ${response.status}: ${response.body['error']['message']}';
    }

    return response.body;
  }

  Future<Map<String, dynamic>> movePlaylist(String moving,
      {String toGroup, int offset = 0, int absolutePosition}) async {
    return basedRequest((baseRevision) {
      absolutePosition ??= baseRevision.getIndexOf(toGroup) + offset + 1;
      var fromIndex = baseRevision.getIndexOf(moving);

      print('from: $fromIndex toIndex (abs): $absolutePosition');

      return _requestManager.makeRequest(DriverRequest(
        uri: Uri.parse('$rootlistUrl/changes'),
        body: {
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
        },
      ));
    });
  }

  Future<Map<String, dynamic>> createFolder(String name,
      {String toGroup, int offset = 0, int absolutePosition}) async {
    var id = '${randomHex(12)}000';

    return basedRequest((baseRevision) {
      absolutePosition ??= baseRevision.getIndexOf(toGroup) + offset;
      return _requestManager.makeRequest(
          DriverRequest(uri: Uri.parse('$rootlistUrl/changes'), body: {
        'baseRevision': '${baseRevision.revision}',
        'deltas': [
          {
            'ops': [
              {
                'kind': 'ADD',
                'add': {
                  'fromIndex': absolutePosition,
                  'items': [
                    {
                      'attributes': {'timestamp': now},
                      'uri':
                          'spotify:start-group:$id:${Uri.encodeComponent(name)}'
                    }
                  ]
                }
              },
              {
                'kind': 'ADD',
                'add': {
                  'fromIndex': absolutePosition + 1,
                  'items': [
                    {
                      'attributes': {'timestamp': now},
                      'uri': 'spotify:end-group:$id'
                    }
                  ]
                }
              }
            ],
            'info': {
              'source': {'client': 'WEBPLAYER'}
            }
          }
        ]
      }));
    }).then((result) => {...result, ...{'id': id}});
  }

  Future<Map<String, dynamic>> createPlaylist(String name) async {
    return basedRequest(
        (_) => _requestManager.makeRequest(DriverRequest(
              uri: Uri.parse('$apiUrl/playlists'),
              body: {
                'name': name,
                'public': true,
              },
            )),
        false);
  }
}

class BaseRevision {
  final String revision;
  final List<RevisionElement> elements;

  BaseRevision.fromJson(Map<String, dynamic> json)
      : revision = json['revision'],
        elements = List<RevisionElement>.from(json['contents']['items']
                ?.asMap()
                ?.map((i, elem) => MapEntry(
                    i,
                    RevisionElement.fromJson(
                        i, Map<String, dynamic>.from(elem))))
                ?.values ??
            {});

  // The element will be inserted BEFORE the given ID. So if you want to add
  // something before the playlist at index 1, you would give it index 1.

  int getIndexOf(String id) {
    id = RevisionElement.parseId(id);
    print('idddddd = $id');
    print('elements = $elements');
    print(elements
        .firstWhere((revision) => revision.id == id, orElse: () => null));
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

  static String parseId(String uri) => uri.contains(':') ? uri.split(':')[2] : uri;

  static ElementType parseElementType(String uri) =>
      (uri.contains(':') ? uri.split(':')[1] : uri) == 'playlist'
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

  @override
  String toString() {
    return 'RevisionElement{index: $index, timestamp: $timestamp, public: $public, id: $id, type: $type}';
  }
}

enum ElementType { Folder, Playlist }
