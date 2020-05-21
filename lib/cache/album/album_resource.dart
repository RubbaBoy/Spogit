import 'package:Spogit/cache/cache_types.dart';
import 'package:Spogit/cache/cached_resource.dart';
import 'package:Spogit/json/album_full.dart';
import 'package:Spogit/utility.dart';

/// Stores the associated name with an ID, weather it be a track, playlist, or
/// folder.
class AlbumResource extends CachedResource<AlbumFull> {
  AlbumResource(String id, AlbumFull album)
      : super(id.customHash, CacheType.ID, now, album);

  AlbumResource.fromPacked(int id, Map map)
      : super(id, CacheType.ID, now, map['data']);

  @override
  Map<String, dynamic> pack() => data.toJson();

  @override
  String toString() => 'AlbumResource{id = $id, data = $data}';
}
