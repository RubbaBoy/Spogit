import 'package:Spogit/json/artist.dart';
import 'package:Spogit/json/image.dart';
import 'package:Spogit/json/sub/external_url.dart';

class AlbumSimplified {
  String albumType;
  List<Artists> artists;
  List<String> availableMarkets;
  ExternalUrls externalUrls;
  String href;
  String id;
  List<Images> images;
  String name;
  String releaseDate;
  String releaseDatePrecision;
  String type;
  String uri;

  AlbumSimplified(
      {this.albumType,
        this.artists,
        this.availableMarkets,
        this.externalUrls,
        this.href,
        this.id,
        this.images,
        this.name,
        this.releaseDate,
        this.releaseDatePrecision,
        this.type,
        this.uri});

  AlbumSimplified.fromJson(Map<String, dynamic> json) {
    albumType = json['album_type'];
    if (json['artists'] != null) {
      artists = new List<Artists>();
      json['artists'].forEach((v) {
        artists.add(new Artists.fromJson(v));
      });
    }
    availableMarkets = json['available_markets'].cast<String>();
    externalUrls = json['external_urls'] != null
        ? new ExternalUrls.fromJson(json['external_urls'])
        : null;
    href = json['href'];
    id = json['id'];
    if (json['images'] != null) {
      images = new List<Images>();
      json['images'].forEach((v) {
        images.add(new Images.fromJson(v));
      });
    }
    name = json['name'];
    releaseDate = json['release_date'];
    releaseDatePrecision = json['release_date_precision'];
    type = json['type'];
    uri = json['uri'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['album_type'] = this.albumType;
    if (this.artists != null) {
      data['artists'] = this.artists.map((v) => v.toJson()).toList();
    }
    data['available_markets'] = this.availableMarkets;
    if (this.externalUrls != null) {
      data['external_urls'] = this.externalUrls.toJson();
    }
    data['href'] = this.href;
    data['id'] = this.id;
    if (this.images != null) {
      data['images'] = this.images.map((v) => v.toJson()).toList();
    }
    data['name'] = this.name;
    data['release_date'] = this.releaseDate;
    data['release_date_precision'] = this.releaseDatePrecision;
    data['type'] = this.type;
    data['uri'] = this.uri;
    return data;
  }
}
