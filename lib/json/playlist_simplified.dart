import 'package:Spogit/json/artist.dart';
import 'package:Spogit/json/image.dart';
import 'package:Spogit/json/json.dart';
import 'package:Spogit/json/paging.dart';
import 'package:Spogit/json/playlist_full.dart';
import 'package:Spogit/json/sub/external_url.dart';

/// [T] is the type of the [tracks] object. In most cases, this should be a
/// [Paging<PlaylistTrack>], however in some instances such as listing playlists,
/// this should be a [TracksObject].
class PlaylistSimplified<T extends Jsonable> with Jsonable {
  bool collaborative;
  ExternalUrls externalUrls;
  String href;
  String id;
  List<Images> images;
  String name;
  Artists owner;
  bool public;
  String snapshotId;
  T tracks;
  String type;
  String uri;

  PlaylistSimplified(
      {this.collaborative,
      this.externalUrls,
      this.href,
      this.id,
      this.images,
      this.name,
      this.owner,
      this.public,
      this.snapshotId,
      this.tracks,
      this.type,
      this.uri});

  static PlaylistSimplified jsonConverter<T extends Jsonable>(Map<String, dynamic> json) =>
      PlaylistSimplified<T>.fromJson(json);

  PlaylistSimplified.fromJson(Map<String, dynamic> json) {
    collaborative = json['collaborative'];
    externalUrls = json['external_urls'] != null
        ? ExternalUrls.fromJson(json['external_urls'])
        : null;
    href = json['href'];
    id = json['id'];
    if (json['images'] != null) {
      images = <Images>[];
      json['images'].forEach((v) {
        images.add(Images.fromJson(v));
      });
    }
    name = json['name'];
    owner = json['owner'] != null ? Artists.fromJson(json['owner']) : null;
    public = json['public'];
    snapshotId = json['snapshot_id'];

    if (T == Paging) {
      tracks = (json['tracks'] != null
          ? Paging<PlaylistTrack>.fromJson(
              json['tracks'], PlaylistTrack.jsonConverter)
          : null) as T;
    } else if (T == TracksObject) {
      tracks = TracksObject.fromJson(json['tracks']) as T;
    } else {
      print('Setting as else!!!!');
    }

    type = json['type'];
    uri = json['uri'];
  }

  @override
  Map<String, dynamic> toJson() => {
        'collaborative': collaborative,
        if (externalUrls != null) ...{
          'external_urls': externalUrls.toJson(),
        },
        'href': href,
        'id': id,
        if (images != null) ...{
          'images': images.map((v) => v.toJson()).toList(),
        },
        'name': name,
        if (owner != null) ...{
          'owner': owner.toJson(),
        },
        'public': public,
        'snapshot_id': snapshotId,
        if (tracks != null) ...{
          'tracks': tracks.toJson(),
        },
        'type': type,
        'uri': uri,
      };
}

class TracksObject with Jsonable {
  String href;
  int total;

  TracksObject(this.href, this.total);

  TracksObject.fromJson(Map<String, dynamic> json)
      : href = json['href'],
        total = json['total'];

  @override
  Map<String, dynamic> toJson() => {
        'href': href,
        'total': total,
      };
}
