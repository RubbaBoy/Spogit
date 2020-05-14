import 'package:Spogit/cache/album/album_resource.dart';
import 'package:Spogit/cache/cached_resource.dart';
import 'package:Spogit/cache/cover_resource.dart';
import 'package:Spogit/cache/id/id_resource.dart';

class CacheType<T extends CachedResource> {
  static const PLAYLIST_COVER = CacheType<PlaylistCoverResource>._('PlaylistCover', 1, 315360000 /* 10 years, the max-age of the image */);
  static const ID = CacheType<IdResource>._('ID', 2, 315360000 /* Shouldn't ever expire */);
  static const ALBUM = CacheType<AlbumResource>._('Album', 3, 86400 /* 1 Day */);

  final String name;
  final int id;
  final int ttl;

  const CacheType._(this.name, this.id, this.ttl);

  @override
  String toString() {
    return 'CacheType{name: $name, id: $id, ttl: $ttl}';
  }
}
