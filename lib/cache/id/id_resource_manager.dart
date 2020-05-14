import 'dart:async';

import 'package:Spogit/cache/cache_manager.dart';
import 'package:Spogit/cache/id/id_resource.dart';
import 'package:Spogit/driver/driver_api.dart';
import 'package:Spogit/driver/playlist_manager.dart';
import 'package:Spogit/utility.dart';

class IdResourceManager {
  final REQUEST_ORDER = const <ResourceType>[
    ResourceType.Track,
    ResourceType.Playlist,
    ResourceType.Folder
  ];

  final PlaylistManager playlistManager;
  final CacheManager cacheManager;

  IdResourceManager(this.playlistManager, this.cacheManager);

  /// Gets or retrieves the name of a 22-character Spotify resource ID. If the
  /// ID is already is already in the cache the prefixing `spotify:whatever` is
  /// not relevant, however when fetching it is more efficient to have it given
  /// as it will not have to potentially make multiple requests per ID.
  /// The order of requests is defined by the constant [REQUEST_ORDER] but by
  /// default is:
  /// - Track
  /// - Playlist
  /// - Folder
  Future<String> getName(String id, [ResourceType type]) =>
      cacheManager.getOr<IdResource>(id, () async {
        type ??= getResourceType(id);
        var parsed = id.parseId;
        String name;
        if (type != null) {
          name = await tryRequest(parsed, type);
        } else {
          for (var orderType in REQUEST_ORDER) {
            var requested = await tryRequest(parsed, orderType);
            if (requested != null) {
              name = requested;
              break;
            }
          }
        }
        return IdResource(parsed, name);
      }, forceUpdate: (prev) => prev.data == null).then(
          (res) => res.resource.data);

  FutureOr<String> tryRequest(String id, ResourceType resource) {
    switch (resource) {
      case ResourceType.Track:
        return playlistManager.getTrack(id).then((json) => json.print().name);
        break;
      case ResourceType.Playlist:
        return playlistManager.getPlaylistInfo(id).then((json) => json.print()['name']);
      case ResourceType.Folder:
        return id.startsWith('spotify:start-group') ? id.replaceFirst('spotify:start-group:', '').safeSubstring(22)?.replaceAll('+', '') : null;
    }

    return null;
  }

  ResourceType getResourceType(String id) {
    var start = id.replaceFirst('spotify:', '');
    if (start.startsWith('track')) {
      return ResourceType.Track;
    } else if (start.startsWith('playlist')) {
      return ResourceType.Playlist;
    } else if (start.startsWith('start-group') ||
        start.startsWith('end-group')) {
      return ResourceType.Folder;
    }

    return null;
  }
}

enum ResourceType { Track, Playlist, Folder }
