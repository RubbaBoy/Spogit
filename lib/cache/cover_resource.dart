import 'package:Spogit/cache/cache_types.dart';
import 'package:Spogit/cache/cached_resource.dart';
import 'package:Spogit/utility.dart';

class PlaylistCoverResource extends CachedResource<String> {
  PlaylistCoverResource(String id, String url)
      : super(id.customHash, CacheType.PLAYLIST_COVER, now, url);

  PlaylistCoverResource.fromPacked(int id, Map map)
      : super(id, CacheType.PLAYLIST_COVER, now, map['data']['url']);

  @override
  Map<String, dynamic> pack() => {'url': data};

  @override
  String toString() => 'PlaylistCoverResource{id = $id, url = $data}';
}
