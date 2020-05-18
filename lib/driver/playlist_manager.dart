import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:Spogit/driver/driver_request.dart';
import 'package:Spogit/driver/js_communication.dart';
import 'package:Spogit/json/album_full.dart';
import 'package:Spogit/json/playlist_full.dart';
import 'package:Spogit/json/playlist_simplified.dart';
import 'package:Spogit/json/track_full.dart';
import 'package:Spogit/json/track_simplified.dart';
import 'package:Spogit/utility.dart';
import 'package:http/http.dart';
import 'package:logging/logging.dart';
import 'package:webdriver/sync_io.dart';

class PlaylistManager {
  final log = Logger('PlaylistManager');

  final WebDriver _driver;
  final RequestManager _requestManager;

  static const apiBase = 'https://api.spotify.com/v1';

  String get rootlistUrl =>
      'https://spclient.wg.spotify.com/playlist/v2/user/${_requestManager.personalData.id}/rootlist';

  String get apiUrl => '$apiBase/users/${_requestManager.personalData.id}';

  PlaylistManager._(this._driver, this._requestManager);

  static Future<PlaylistManager> createPlaylistManager(WebDriver driver,
          RequestManager requestManager, JSCommunication communication) async =>
      PlaylistManager._(driver, requestManager);

  /// Gets all of a user's playlist IDs and their corresponding snapshot IDs.
  Future<Map<String, String>> getPlaylistSnapshots() => DriverRequest(
              method: RequestMethod.Get,
              token: _requestManager.authToken,
              uri: Uri.parse('$apiUrl/playlists'))
          .sendPaging(PlaylistSimplified.jsonConverter, all: true)
          .then((response) {
        var res = <String, String>{};
        for (var item in response) {
          res[item.id] = item.snapshotId;
        }
        return res;
      });

  /// Gets the ETag of the base revision to detect if any playlist order has
  /// changed yet.
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

  /// Gets a revision of the users' Spotify playlist data.
  Future<BaseRevision> analyzeBaseRevision() async {
    var response = await DriverRequest(
      method: RequestMethod.Get,
      token: _requestManager.authToken,
      uri: Uri.parse(rootlistUrl).replace(queryParameters: {
        'decorate': 'revision,length,attributes,timestamp,owner',
        'market': 'from_token',
      }),
    ).send();

    if (response.statusCode != 200) {
      throw 'Status ${response.statusCode}: ${response.json['error']['message']}';
    }

    return BaseRevision.fromJson(response.json);
  }

  /// Makes a request without the boilerplate. [makeRequest] should return a
  /// response via something like [DriverRequest#send()]. If [useBase] is true,
  /// [#analyzeBaseRevision()] is invoked and given as an argument to
  /// [makeRequest]. If false, null is given as an argument. Parsed JSON is
  /// returned as a response.
  Future<Map<String, dynamic>> basedRequest(
      FutureOr<Response> Function(BaseRevision) makeRequest,
      [bool useBase = true]) async {
    var response =
        await makeRequest(useBase ? await analyzeBaseRevision() : null);

    if (response.statusCode >= 300) {
      throw 'Status ${response.statusCode}: ${response.body}';
    }

    return response.json;
  }

  /// Gets an album by its ID.
  /// Returns an Album JSON object.
  /// <br><br>See [Get an Album](https://developer.spotify.com/documentation/web-api/reference/albums/get-album/)
  Future<AlbumFull> getAlbum(String id) => basedRequest(
          (_) => DriverRequest(
                  method: RequestMethod.Get,
                  uri: Uri.parse('$apiBase/albums/$id')
                      .replace(queryParameters: {'id': id}),
                  token: _requestManager.authToken)
              .send(),
          false)
      .then((json) => AlbumFull.fromJson(json));

  /// Gets an album's tracks by its ID. If [all] is true, it will get all
  /// tracks. If false, it will only return the first 50.
  /// <br><br>See [Get an Album](https://developer.spotify.com/documentation/web-api/reference/albums/get-album/)
  Future<List<TrackSimplified>> getAlbumTracks(String id, [bool all = false]) =>
      DriverRequest(
              method: RequestMethod.Get,
              uri: Uri.parse('$apiBase/albums/$id/tracks')
                  .replace(queryParameters: {'id': id}),
              token: _requestManager.authToken)
          .sendPaging(TrackSimplified.jsonConverter, all: all);

  /// Moves the given playlist ID [moving] to a location. If [toGroup] is set,
  /// it is the group ID to move the playlist in. When that is set, [offset] is
  /// the relative offset of this set group. If neither of these are set,
  /// [absolutePosition] is the absolute position in the flat list where it is
  /// created in.
  /// <br><br>This is not available in the public API and is located in the URL
  /// `https://spclient.wg.spotify.com/playlist/v2/user/USER_ID/rootlist/changes`
  Future<Map<String, dynamic>> movePlaylist(String moving,
      {String toGroup, int offset = 0, int absolutePosition}) async {
    sleep(Duration(milliseconds: 250)); // TODO: Proper rate limiting system!!!
    return basedRequest((baseRevision) {
      var movingElement = baseRevision.getElement(moving);

      absolutePosition ??=
          (baseRevision.getIndexOf(toGroup)?.add(1) ?? 0) + offset;
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

  /// Creates a folder with the given [name]. If [toGroup] is set, it will be
  /// moved to the ID of the given group. When that is set, [offset] is the
  /// relative offset of this set group. If neither of these are set,
  /// [absolutePosition] is the absolute position in the flat list where it is
  /// created in.
  /// <br><br>This is not available in the public API and is located in the URL
  /// `https://spclient.wg.spotify.com/playlist/v2/user/USER_ID/rootlist/changes`
  Future<Map<String, dynamic>> createFolder(String name,
      {String toGroup, int offset = 0, int absolutePosition}) async {
    var id = '${randomHex(12)}000';

    return basedRequest((baseRevision) {
      absolutePosition ??=
          (baseRevision.getIndexOf(toGroup)?.add(1) ?? 0) + offset;
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

  /// Adds a list of tracks to a given [playlist] ID, by their ids [trackIds].
  /// <br><br>See [Add Items to a Playlist](https://developer.spotify.com/documentation/web-api/reference/playlists/add-tracks-to-playlist/)
  Future<Map<String, dynamic>> addTracks(
      String playlist, List<String> trackIds) {
    return DriverRequest(
      uri: Uri.parse('$apiBase/playlists/${playlist.parseId}/tracks'),
      token: _requestManager.authToken,
      body: {
        'uris': trackIds.map((str) => 'spotify:track:${str.parseId}').toList()
      },
    ).send().then((res) => res.json);
  }

  /// Creates a playlist with the given [name], and optional [description].
  /// <br><br>See [Create a Playlist](https://developer.spotify.com/documentation/web-api/reference/playlists/create-playlist/)
  Future<Map<String, dynamic>> createPlaylist(String name,
      [String description = '']) async {
    sleep(Duration(milliseconds: 250)); // TODO: Proper rate limiting system!!!
    return basedRequest(
        (_) => DriverRequest(
              uri: Uri.parse('$apiUrl/playlists'),
              token: _requestManager.authToken,
              body: {
                'name': name,
                'description': description,
              },
            ).send(),
        false);
  }

  /// Gets a playlist by its [id].
  /// <br><br>See [Get a Playlist](https://developer.spotify.com/documentation/web-api/reference/playlists/get-playlist/)
  Future<PlaylistFull> getPlaylistInfo(String id) {
    return DriverRequest(
      method: RequestMethod.Get,
      uri: Uri.parse('$apiBase/playlists/${id.parseId}')
          .replace(queryParameters: {
        'type': 'track,episode',
        'market': 'from_token',
      }),
      token: _requestManager.authToken,
    ).send().then((res) => PlaylistFull.fromJson(res.json));
  }

  /// Removes tracks from the given [playlist] ID. [trackIds] should contain a
  /// list of track IDs to remove. These do not have to be parsed IDs.
  Future<Map<String, dynamic>> removeTracks(
      String playlist, List<String> trackIds) {
    trackIds = trackIds.map((str) => str.parseId).toList();

    return getPlaylistInfo(playlist).then((info) {
      var items = info.tracks.items;

      var ids = items
          .map((track) => track.track.id)
          .map((id) => id.parseId)
          .toList()
          .asMap()
            ..removeWhere((i, id) => !trackIds.contains(id));

      return DriverRequest(
        method: RequestMethod.Delete,
        uri: Uri.parse('$apiBase/playlists/${playlist.parseId}'),
        token: _requestManager.authToken,
        body: {
          'tracks': [
            for (var index in ids.keys)
              {
                {
                  'positions': [index],
                  'uri': 'spotify:track:${ids[index]}'
                },
              }
          ]
        },
      ).send().then((res) => res.json);
    });
  }

  /// Uploads the given [file] as the playlist cover to the given [playlist] ID.
  ///
  /// TODO: As of 5/9/2020 the Spotify webapp's authorization token does NOT
  ///   allow for this method, which is strange but nothing can be done about it.
  ///   Possible fixes for this include adding a proper auth token from a normal
  ///   app instead of using the webapp (Would require more setup for the end-user
  ///   as desktop apps are not supported) or waiting until this ability is added
  ///   to Spotify.
  /// <br><br>See [Upload a Custom Playlist Cover Image](https://developer.spotify.com/documentation/web-api/reference/playlists/upload-custom-playlist-cover/)
  Future<void> uploadCover(File file, String playlist) async {
    if (!(await file.exists())) {
      return;
    }

    log.warning(
        'Unless an application authentication token is being used, setting the upload cover will not work.');

    return basedRequest(
        (_) async => DriverRequest(
              uri: Uri.parse('$apiBase/playlists/${playlist.parseId}/images'),
              method: RequestMethod.Put,
              token: _requestManager.authToken,
              headers: {
                'Content-Type': 'image/jpeg',
              },
              body: base64Encode(await file.readAsBytes()),
            ).send(),
        false);
  }

  /// Gets information on a single track by its [id].
  /// <br><br>See [Get a Track](https://developer.spotify.com/documentation/web-api/reference/tracks/get-track/)
  Future<TrackFull> getTrack(String id) => basedRequest(
          (_) => DriverRequest(
                method: RequestMethod.Get,
                uri: Uri.parse('$apiBase/tracks/${id.parseId}'),
                token: _requestManager.authToken,
              ).send(),
          false)
      .then(TrackFull.jsonConverter);

  /// Gets information on multiple tracks by their [ids].
  /// <br><br>See [Get Several Tracks](https://developer.spotify.com/documentation/web-api/reference/tracks/get-several-tracks/)
  Future<List<TrackFull>> getTracks(List<String> ids) => basedRequest(
          (_) => DriverRequest(
                  method: RequestMethod.Get,
                  uri: Uri.parse('$apiBase/tracks'),
                  token: _requestManager.authToken,
                  body: {
                    'ids': ids.map((id) => id.parseId).join(','),
                  }).send(),
          false)
      .then((json) => json['tracks'].map(TrackFull.jsonConverter).toList());
}

/// A flat, direct representation of the fetched base revision
class BaseRevision {
  /// The Spotify-generated revision ID
  final String revision;

  /// A flat list of [RevisionElements] in the current revision
  final List<RevisionElement> elements;

  BaseRevision.fromJson(Map<String, dynamic> json)
      : revision = json['revision'],
        elements = parseElements(jsonify(json['contents']));

  static List<RevisionElement> parseElements(Map<String, dynamic> json) {
    var children = analyzeChildren(json);
    var meta = json['metaItems'];
    if (meta == null) {
      return const [];
    }

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
    var ids = List<List<String>>.from((json['items'] ?? const [])
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
    id = id?.parseId;
    return elements.firstWhere((revision) => revision.id == id,
        orElse: () => null);
  }

  int getIndexOf(String id) => getElement(id)?.index;

  int getTrackCountOf(String id) => getElement(id)?.length;

  int getHash({String id, RevisionElement element}) {
    element ??= getElement(id);
    var totalHash = 0;

    void append(int number) {
      var breaking = (number.bitLength / 8).ceil();
      for (var i = 0; i < breaking; i++) {
        totalHash += number & 0xFF;
        number >>= 8;
        totalHash <<= 8;
      }
    }

    for (var i = element.index; i < element.index + element.moveCount; i++) {
      var curr = elements[i];
      switch (curr.type) {
        case ElementType.Playlist:
          append(0x00);
          append(curr.length);
          append(0x00);
          append(curr.id.hashCode);
          append(0x00);
          break;
        case ElementType.FolderStart:
          append(0x01);
          break;
        case ElementType.FolderEnd:
          append(0x02);
          break;
      }
    }

    return totalHash;
  }

  @override
  String toString() {
    return 'BaseRevision{revision: $revision, elements: $elements}';
  }
}

class RevisionElement {
  /// The index of the revision element, used for moving elements.
  final int index;

  /// (Present if folder) The name of the element.
  final String name;

  /// (Present if playlist) The amount of tracks in a playlist.
  final int length;

  /// The amount of children this item has, not including itself (e.g. Empty
  /// folders will be 0).
  final int children;

  /// The timestamp created.
  final int timestamp;

  /// (Present if playlist) If the playlist is publicly available.
  final bool public;

  /// The parsed ID of the current element. If the raw uri was
  /// `spotify:playlist:whatever` this value would be `whatever`.
  final String id;

  /// The [ElementType] of the current element.
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
          index == other.index &&
          length == other.length &&
          children == other.children &&
          timestamp == other.timestamp &&
          public == other.public &&
          id == other.id &&
          type == other.type;

  @override
  int get hashCode =>
      index.hashCode ^
      length.hashCode ^
      children.hashCode ^
      timestamp.hashCode ^
      public.hashCode ^
      id.hashCode ^
      type.hashCode;

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
