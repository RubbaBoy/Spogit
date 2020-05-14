import 'package:Spogit/cache/cache_types.dart';
import 'package:Spogit/cache/cached_resource.dart';
import 'package:Spogit/utility.dart';

/// Stores the associated name with an ID, weather it be a track, playlist, or
/// folder.
class IdResource extends CachedResource<String> {
  IdResource(String id, String name)
      : super(id.customHash, CacheType.ID, now, name);

  IdResource.fromPacked(int id, Map map)
      : super(id, CacheType.ID, now, map['data']['name']);

  @override
  Map pack() => {'name': data};

  @override
  String toString() => 'IdResource{id = $id, name = $data}';
}
