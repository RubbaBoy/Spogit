import 'dart:typed_data';

import 'package:Spogit/cache/cache_types.dart';
import 'package:Spogit/cache/cached_resource.dart';
import 'package:Spogit/utility.dart';

class PlaylistCoverResource extends CachedResource<PlaylistCoverData> {
  PlaylistCoverResource(String id, PlaylistCoverData data)
      : super(id, CacheType.PLAYLIST_COVER, now, data);

  PlaylistCoverResource.fromPacked(Map map)
    : super(map['id'], CacheType.PLAYLIST_COVER, now, PlaylistCoverData(map['image'], map['url']));

  @override
  Map pack() => {'image': data.image.buffer.asByteData(), 'url': data.url};
}

class PlaylistCoverData {
  final Uint8List image;
  final String url;

  PlaylistCoverData(this.image, this.url);
}
