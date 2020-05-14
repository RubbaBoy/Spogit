import 'package:Spogit/json/artist.dart';
import 'package:Spogit/json/image.dart';
import 'package:Spogit/json/paging.dart';
import 'package:Spogit/json/sub/external_ids.dart';
import 'package:Spogit/json/sub/external_url.dart';
import 'package:Spogit/json/track_simplified.dart';

class AlbumFull {
  String albumType;
  List<Artists> artists;
  List<String> availableMarkets;
  List<Copyrights> copyrights;
  ExternalIds externalIds;
  ExternalUrls externalUrls;
  List<String> genres;
  String href;
  String id;
  List<Images> images;
  String name;
  int popularity;
  String releaseDate;
  String releaseDatePrecision;
  Paging<TrackSimplified> tracks;
  String type;
  String uri;

  AlbumFull(
      {this.albumType,
        this.artists,
        this.availableMarkets,
        this.copyrights,
        this.externalIds,
        this.externalUrls,
        this.genres,
        this.href,
        this.id,
        this.images,
        this.name,
        this.popularity,
        this.releaseDate,
        this.releaseDatePrecision,
        this.tracks,
        this.type,
        this.uri});

  AlbumFull.fromJson(Map<String, dynamic> json) {
    albumType = json['album_type'];
    if (json['artists'] != null) {
      artists = new List<Artists>();
      json['artists'].forEach((v) {
        artists.add(new Artists.fromJson(v));
      });
    }
    availableMarkets = json['available_markets'].cast<String>();
    if (json['copyrights'] != null) {
      copyrights = new List<Copyrights>();
      json['copyrights'].forEach((v) {
        copyrights.add(new Copyrights.fromJson(v));
      });
    }
    externalIds = json['external_ids'] != null
        ? new ExternalIds.fromJson(ExternalType.UPC, json['external_ids'])
        : null;
    externalUrls = json['external_urls'] != null
        ? new ExternalUrls.fromJson(json['external_urls'])
        : null;
    genres = json['genres'].cast<String>();
    href = json['href'];
    id = json['id'];
    if (json['images'] != null) {
      images = new List<Images>();
      json['images'].forEach((v) {
        images.add(new Images.fromJson(v));
      });
    }
    name = json['name'];
    popularity = json['popularity'];
    releaseDate = json['release_date'];
    releaseDatePrecision = json['release_date_precision'];
    tracks = Paging.fromJson(json['tracks'], TrackSimplified.jsonConverter);
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
    if (this.copyrights != null) {
      data['copyrights'] = this.copyrights.map((v) => v.toJson()).toList();
    }
    if (this.externalIds != null) {
      data['external_ids'] = this.externalIds.toJson();
    }
    if (this.externalUrls != null) {
      data['external_urls'] = this.externalUrls.toJson();
    }
    data['genres'] = this.genres;
    data['href'] = this.href;
    data['id'] = this.id;
    if (this.images != null) {
      data['images'] = this.images.map((v) => v.toJson()).toList();
    }
    data['name'] = this.name;
    data['popularity'] = this.popularity;
    data['release_date'] = this.releaseDate;
    data['release_date_precision'] = this.releaseDatePrecision;
    data['tracks'] = this.tracks;
    data['type'] = this.type;
    data['uri'] = this.uri;
    return data;
  }
}

class Copyrights {
  String text;
  String type;

  Copyrights({this.text, this.type});

  Copyrights.fromJson(Map<String, dynamic> json) {
    text = json['text'];
    type = json['type'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['text'] = this.text;
    data['type'] = this.type;
    return data;
  }
}
