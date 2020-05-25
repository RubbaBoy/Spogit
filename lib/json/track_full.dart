import 'package:Spogit/json/album_simplified.dart';
import 'package:Spogit/json/artist.dart';
import 'package:Spogit/json/json.dart';
import 'package:Spogit/json/sub/external_ids.dart';
import 'package:Spogit/json/sub/external_url.dart';

class TrackFull with Jsonable {
  AlbumSimplified album;
  List<Artists> artists;
  List<String> availableMarkets;
  int discNumber;
  int durationMs;
  bool explicit;
  ExternalIds externalIds;
  ExternalUrls externalUrls;
  String href;
  String id;
  bool isLocal;
  String name;
  int popularity;
  String previewUrl;
  int trackNumber;
  String type;
  String uri;

  TrackFull(
      {this.album,
        this.artists,
        this.availableMarkets,
        this.discNumber,
        this.durationMs,
        this.explicit,
        this.externalIds,
        this.externalUrls,
        this.href,
        this.id,
        this.isLocal,
        this.name,
        this.popularity,
        this.previewUrl,
        this.trackNumber,
        this.type,
        this.uri});

  static TrackFull jsonConverter(Map<String, dynamic> json) => json == null ? null : TrackFull.fromJson(json);

  TrackFull.fromJson(Map<String, dynamic> json) {
    album = json['album'] != null ? AlbumSimplified.fromJson(json['album']) : null;
    if (json['artists'] != null) {
      artists = <Artists>[];
      json['artists'].forEach((v) {
        artists.add(Artists.fromJson(v));
      });
    }
    availableMarkets = json['available_markets']?.cast<String>();
    discNumber = json['disc_number'];
    durationMs = json['duration_ms'];
    explicit = json['explicit'];
    externalIds = json['external_ids'] != null
        ? ExternalIds.fromJson(ExternalType.ISRC, json['external_ids'])
        : null;
    externalUrls = json['external_urls'] != null
        ? ExternalUrls.fromJson(json['external_urls'])
        : null;
    href = json['href'];
    id = json['id'];
    isLocal = json['is_local'];
    name = json['name'];
    popularity = json['popularity'];
    previewUrl = json['preview_url'];
    trackNumber = json['track_number'];
    type = json['type'];
    uri = json['uri'];
  }

  @override
  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    if (this.album != null) {
      data['album'] = this.album.toJson();
    }
    if (this.artists != null) {
      data['artists'] = this.artists.map((v) => v.toJson()).toList();
    }
    data['available_markets'] = this.availableMarkets;
    data['disc_number'] = this.discNumber;
    data['duration_ms'] = this.durationMs;
    data['explicit'] = this.explicit;
    if (this.externalIds != null) {
      data['external_ids'] = this.externalIds.toJson();
    }
    if (this.externalUrls != null) {
      data['external_urls'] = this.externalUrls.toJson();
    }
    data['href'] = this.href;
    data['id'] = this.id;
    data['is_local'] = this.isLocal;
    data['name'] = this.name;
    data['popularity'] = this.popularity;
    data['preview_url'] = this.previewUrl;
    data['track_number'] = this.trackNumber;
    data['type'] = this.type;
    data['uri'] = this.uri;
    return data;
  }
}
