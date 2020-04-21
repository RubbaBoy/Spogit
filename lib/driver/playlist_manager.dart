import 'dart:async';

import 'package:Spogit/driver/driver_request.dart';
import 'package:Spogit/driver/js_communication.dart';
import 'package:Spogit/utility.dart';
import 'package:http/http.dart';
import 'package:webdriver/sync_io.dart';

class PlaylistManager {
  final WebDriver _driver;
  final RequestManager _requestManager;
  BaseRevision baseRevision;

  static const apiBase = 'https://api.spotify.com/v1';

  String get rootlistUrl =>
      'https://spclient.wg.spotify.com/playlist/v2/user/${_requestManager.personalData.id}/rootlist';

  String get apiUrl => '$apiBase/users/${_requestManager.personalData.id}';

  PlaylistManager._(this._driver, this._requestManager);

  static Future<PlaylistManager> createPlaylistManager(WebDriver driver,
      RequestManager requestManager, JSCommunication communication) async {
    return PlaylistManager._(driver, requestManager);
  }

  Future<String> baseRevisionETag() async {
    var response = await DriverRequest(
      method: RequestMethod.Head,
      token: _requestManager.authToken,
      uri: Uri.parse(rootlistUrl).replace(queryParameters: {
        'decorate': 'revision,length,attributes,timestamp,owner',
        'market': 'from_token'
      }),
    ).send();

    return response.headers['etag'];
  }

  Future<BaseRevision> analyzeBaseRevision() async {
    var response = await DriverRequest(
      method: RequestMethod.Get,
      token: _requestManager.authToken,
      uri: Uri.parse(rootlistUrl)
          .replace(queryParameters: {
        'decorate': 'revision,length,attributes,timestamp,owner',
        'market': 'from_token'
      }),
    ).send();

    if (response.statusCode != 200) {
      throw 'Status ${response.statusCode}: ${response.json['error']['message']}';
    }

    return BaseRevision.fromJson(response.json);
  }

  Future<Map<String, dynamic>> basedRequest(
      FutureOr<Response> Function(BaseRevision) makeRequest,
      [bool useBase = true]) async {
    var response =
        await makeRequest(useBase ? await analyzeBaseRevision() : null);

    if (response.statusCode >= 300) {
      print('code = ${response.statusCode}');
      throw 'Status ${response.statusCode}: ${response.json['error']['message']}';
    }

    return response.json;
  }

  Future<Map<String, dynamic>> movePlaylist(String moving,
      {String toGroup, int offset = 0, int absolutePosition}) async {
    return basedRequest((baseRevision) {
      var movingElement = baseRevision.getElement(moving);

      absolutePosition ??= baseRevision.getIndexOf(toGroup) + offset + 1;
      var fromIndex = movingElement.index;

      return DriverRequest(
        uri: Uri.parse('$rootlistUrl/changes'),
        token: _requestManager.authToken,
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
                    'length': movingElement.moveCount,
                  }
                }
              ],
              'info': {
                'source': {'client': 'WEBPLAYER'}
              }
            }
          ]
        },
      ).send();
    });
  }

  Future<Map<String, dynamic>> createFolder(String name,
      {String toGroup, int offset = 0, int absolutePosition}) async {
    var id = '${randomHex(12)}000';

    return basedRequest((baseRevision) {
      absolutePosition ??= baseRevision.getIndexOf(toGroup) + offset;
      return DriverRequest(
        uri: Uri.parse('$rootlistUrl/changes'),
        token: _requestManager.authToken,
        body: {
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
        },
      ).send();
    }).then((result) => {
          ...result,
          ...{'id': id}
        });
  }

  Future<Map<String, dynamic>> addTracks(
      String playlist, List<String> trackIds) {
    return DriverRequest(
      uri: Uri.parse('$apiBase/playlists/${playlist.parseId}'),
      token: _requestManager.authToken,
      body: {'uris': trackIds.map((str) => str.parseId).toList()},
    ).send().then((res) => res.json);
  }

  Future<Map<String, dynamic>> createPlaylist(String name) async {
    return basedRequest(
        (_) => DriverRequest(
              uri: Uri.parse('$apiUrl/playlists'),
              token: _requestManager.authToken,
              body: {
                'name': name,
                'public': true,
              },
            ).send(),
        false);
  }
}

class BaseRevision {
  final String revision;
  final List<RevisionElement> elements;

  BaseRevision.fromJson(Map<String, dynamic> json)
      : revision = json['revision'],
        elements = parseElements(jsonify(json['contents']));

  static List<RevisionElement> parseElements(Map<String, dynamic> json) {
    var children = analyzeChildren(json);
    var meta = json['metaItems'];
    return List<RevisionElement>.from(json['items'].asMap()?.map((i, elem) {
          var metaVal = jsonify(meta[i]);
          var itemVal = elem;

          var attributes = metaVal.isNotEmpty
              ? jsonify({...metaVal['attributes'], ...itemVal['attributes']})
              : itemVal['attributes'];
          metaVal.remove('attributes');
          itemVal.remove('attributes');

          var uri = itemVal['uri'] as String;
          var id = uri.parseId;
          var type = uri.parseElementType;
          var name = type == ElementType.FolderStart
              ? Uri.decodeComponent(uri.split(':')[3].replaceAll('+', ' '))
              : null;

          return MapEntry(
              i,
              RevisionElement.fromJson(
                  i,
                  type == ElementType.FolderStart ? children[id] : 0,
                  jsonify({...metaVal, ...itemVal, ...attributes}),
                  name: name,
                  id: id,
                  type: type));
        })?.values ??
        {});
  }

  static Map<String, int> analyzeChildren(Map<String, dynamic> json) {
    // A list of items like [start-group, myspotifyid] and [end-group, someid] to be parsed
    var ids = List<List<String>>.from(json['items']
        .map((entry) => entry['uri'].split(':').skip(1).take(2).toList()));

    var result = <String, int>{};

    var currentlyIn = <String, int>{};

    for (var value in ids) {
      var id = value[1];
      var type = value[0]; // playlist, start-group, end-group

      for (var curr in currentlyIn.keys) {
        currentlyIn[curr]++;
      }

      if (type == 'start-group') {
        currentlyIn[id] = 0;
      } else if (type == 'end-group') {
        result[id] = currentlyIn.remove(id) - 1;
      }
    }

    result.addAll(currentlyIn);

    return result;
  }

  RevisionElement getElement(String id) {
    id = id.parseId;
    return elements.firstWhere((revision) => revision.id == id,
        orElse: () => null);
  }

  int getIndexOf(String id) => getElement(id)?.index ?? 0;

  int getTrackCountOf(String id) => getElement(id)?.length ?? 0;
}

class RevisionElement {
  final int index;
  final String name;

  /// The amount of tracks in a playlist. Will be null if this is not a playlist.
  final int length;

  /// The amount of children this item has, not including itself (e.g. Empty
  /// folders will be 0).
  final int children;
  final int timestamp;
  final bool public;
  final String id;
  final ElementType type;

  /// Gets the amount of items to move if this were to be moved. On playlists
  /// this is one, for groups/folders this is the [children] plus two. This
  /// two is for the group start and end to move as well.
  int get moveCount => type == ElementType.Playlist ? 1 : children + 2;

  RevisionElement.fromJson(this.index, this.children, Map<String, dynamic> json,
      {String name, String id, ElementType type})
      : name = name ?? json['name'],
        length = json['length'],
        timestamp = (json['timestamp'] as String).parseInt(),
        public = json['public'] ?? false,
        id = id ?? (json['uri'] as String).parseId,
        type = type ?? (json['uri'] as String).parseElementType;

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
    return 'RevisionElement{index: $index, name: $name, length: $length, children: $children, timestamp: $timestamp, public: $public, id: $id, type: $type}';
  }
}

enum ElementType { FolderStart, FolderEnd, Playlist }

extension ParsingUtils on String {
  String splitOrThis(Pattern pattern, int index) {
    if (!contains(pattern)) {
      return this;
    }

    var arr = split(pattern);
    return index >= arr.length ? this : arr[index];
  }

  String get parseId => splitOrThis(':', 2);

  ElementType get parseElementType => const {
        'playlist': ElementType.Playlist,
        'start-group': ElementType.FolderStart,
        'end-group': ElementType.FolderEnd
      }[splitOrThis(':', 1)];
}
