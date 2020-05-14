import 'package:Spogit/json/artist.dart';
import 'package:Spogit/json/image.dart';
import 'package:Spogit/json/json.dart';
import 'package:Spogit/json/sub/external_url.dart';

class AlbumSimplified with Jsonable {
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
      artists = <Artists>[];
      json['artists'].forEach((v) {
        artists.add(Artists.fromJson(v));
      });
    }
    availableMarkets = json['available_markets']?.cast<String>();
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
    releaseDate = json['release_date'];
    releaseDatePrecision = json['release_date_precision'];
    type = json['type'];
    uri = json['uri'];
  }

  @override
  Map<String, dynamic> toJson() => {
        'album_type': albumType,
        if (artists != null) ...{
          'artists': artists.map((v) => v.toJson()).toList(),
        },
        'available_markets': availableMarkets,
        if (externalUrls != null) ...{
          'external_urls': externalUrls.toJson(),
        },
        'href': href,
        'id': id,
        if (images != null) ...{
          'images': images.map((v) => v.toJson()).toList(),
        },
        'name': name,
        'release_date': releaseDate,
        'release_date_precision': releaseDatePrecision,
        'type': type,
        'uri': uri,
      };
}
