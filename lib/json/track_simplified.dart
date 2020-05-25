import 'package:Spogit/json/artist.dart';
import 'package:Spogit/json/json.dart';
import 'package:Spogit/json/sub/external_url.dart';

class TrackSimplified with Jsonable {
  List<Artists> artists;
  List<String> availableMarkets;
  int discNumber;
  int durationMs;
  bool explicit;
  ExternalUrls externalUrls;
  String href;
  String id;
  String name;
  String previewUrl;
  int trackNumber;
  String type;
  String uri;

  TrackSimplified(
      {this.artists,
        this.availableMarkets,
        this.discNumber,
        this.durationMs,
        this.explicit,
        this.externalUrls,
        this.href,
        this.id,
        this.name,
        this.previewUrl,
        this.trackNumber,
        this.type,
        this.uri});

  static TrackSimplified jsonConverter(Map<String, dynamic> json) => json == null ? null : TrackSimplified.fromJson(json);

  TrackSimplified.fromJson(Map<String, dynamic> json) {
    if (json['artists'] != null) {
      artists = new List<Artists>();
      json['artists'].forEach((v) {
        artists.add(new Artists.fromJson(v));
      });
    }
    availableMarkets = json['available_markets'].cast<String>();
    discNumber = json['disc_number'];
    durationMs = json['duration_ms'];
    explicit = json['explicit'];
    externalUrls = json['external_urls'] != null
        ? new ExternalUrls.fromJson(json['external_urls'])
        : null;
    href = json['href'];
    id = json['id'];
    name = json['name'];
    previewUrl = json['preview_url'];
    trackNumber = json['track_number'];
    type = json['type'];
    uri = json['uri'];
  }

  @override
  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    if (this.artists != null) {
      data['artists'] = this.artists.map((v) => v.toJson()).toList();
    }
    data['available_markets'] = this.availableMarkets;
    data['disc_number'] = this.discNumber;
    data['duration_ms'] = this.durationMs;
    data['explicit'] = this.explicit;
    if (this.externalUrls != null) {
      data['external_urls'] = this.externalUrls.toJson();
    }
    data['href'] = this.href;
    data['id'] = this.id;
    data['name'] = this.name;
    data['preview_url'] = this.previewUrl;
    data['track_number'] = this.trackNumber;
    data['type'] = this.type;
    data['uri'] = this.uri;
    return data;
  }
}
