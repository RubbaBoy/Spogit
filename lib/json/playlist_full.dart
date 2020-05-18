import 'package:Spogit/json/artist.dart';
import 'package:Spogit/json/image.dart';
import 'package:Spogit/json/json.dart';
import 'package:Spogit/json/paging.dart';
import 'package:Spogit/json/playlist_simplified.dart';
import 'package:Spogit/json/sub/external_url.dart';
import 'package:Spogit/json/track_full.dart';

class PlaylistFull extends PlaylistSimplified<Paging<PlaylistTrack>> with Jsonable {
  String description;
  Followers followers;

  PlaylistFull(
      {bool collaborative,
      this.description,
      ExternalUrls externalUrls,
      this.followers,
      String href,
      String id,
      List<Images> images,
      String name,
      Artists owner,
      bool public,
      String snapshotId,
      Paging<PlaylistTrack> tracks,
      String type,
      String uri})
      : super(
          collaborative: collaborative,
          externalUrls: externalUrls,
          href: href,
          id: id,
          images: images,
          name: name,
          owner: owner,
          public: public,
          snapshotId: snapshotId,
          tracks: tracks,
          type: type,
          uri: uri,
        );

  static PlaylistFull jsonConverter(Map<String, dynamic> json) =>
      PlaylistFull.fromJson(json);

  PlaylistFull.fromJson(Map<String, dynamic> json)
      : description = json['description'],
        followers = json['followers'] != null
            ? Followers.fromJson(json['followers'])
            : null;

  @override
  Map<String, dynamic> toJson() => {
        ...super.toJson(),
        'description': description,
        if (followers != null) ...{
          'followers': followers.toJson(),
        }
      };
}

class Followers with Jsonable {
  String href;
  int total;

  Followers({this.href, this.total});

  Followers.fromJson(Map<String, dynamic> json) {
    href = json['href'];
    total = json['total'];
  }

  @override
  Map<String, dynamic> toJson() => {
        'href': href,
        'total': total,
      };
}

class PlaylistTrack with Jsonable {
  String addedAt;
  Artists addedBy;
  bool isLocal;
  TrackFull track;

  PlaylistTrack({this.addedAt, this.addedBy, this.isLocal, this.track});

  static PlaylistTrack jsonConverter(Map<String, dynamic> json) =>
      PlaylistTrack.fromJson(json);

  PlaylistTrack.fromJson(Map<String, dynamic> json) {
    addedAt = json['added_at'];
    addedBy =
        json['added_by'] != null ? Artists.fromJson(json['added_by']) : null;
    isLocal = json['is_local'];
    track = json['track'] != null ? TrackFull.fromJson(json['track']) : null;
  }

  @override
  Map<String, dynamic> toJson() => {
        'added_at': addedAt,
        if (addedBy != null) ...{
          'added_by': addedBy.toJson(),
        },
        'is_local': isLocal,
        if (track != null) ...{
          'track': track.toJson(),
        }
      };
}
