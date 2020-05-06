class CacheType {
  static const CacheType PLAYLIST_COVER = CacheType._('PlaylistCover', 1, 315360000 /* 10 years, the max-age of the image */);

  final String name;
  final int id;
  final int ttl;

  const CacheType._(this.name, this.id, this.ttl);

  @override
  String toString() {
    return 'CacheType{name: $name, id: $id, ttl: $ttl}';
  }
}
