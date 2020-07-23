import 'package:Spogit/json/album_simplified.dart';
import 'package:Spogit/json/artist.dart';
import 'package:Spogit/json/image.dart';
import 'package:Spogit/json/paging.dart';
import 'package:Spogit/json/sub/external_ids.dart';
import 'package:Spogit/json/sub/external_url.dart';
import 'package:Spogit/json/track_simplified.dart';

class AlbumFull extends AlbumSimplified {
  List<Copyrights> copyrights;
  ExternalIds externalIds;
  List<String> genres;
  int popularity;
  Paging<TrackSimplified> tracks;

  AlbumFull(
      {String albumType,
      List<Artists> artists,
      List<String> availableMarkets,
      this.copyrights,
      this.externalIds,
      ExternalUrls externalUrls,
      this.genres,
      String href,
      String id,
      List<Images> images,
      String name,
      this.popularity,
      String releaseDate,
      String releaseDatePrecision,
      this.tracks,
      String type,
      String uri})
      : super(
            albumType: albumType,
            artists: artists,
            availableMarkets: availableMarkets,
            externalUrls: externalUrls,
            href: href,
            id: id,
            images: images,
            name: name,
            releaseDate: releaseDate,
            releaseDatePrecision: releaseDatePrecision,
            type: type,
            uri: uri);

  AlbumFull.fromJson(Map<String, dynamic> json) : super.fromJson(json) {
    if (json['copyrights'] != null) {
      copyrights = <Copyrights>[];
      json['copyrights'].forEach((v) {
        copyrights.add(Copyrights.fromJson(v));
      });
    }
    externalIds = json['external_ids'] != null
        ? ExternalIds.fromJson(ExternalType.UPC, json['external_ids'])
        : null;
    genres = json['genres']?.cast<String>();
    popularity = json['popularity'];
    tracks = Paging.fromJson(json['tracks'] ?? {}, TrackSimplified.jsonConverter);
  }

  @override
  Map<String, dynamic> toJson() => {
        ...super.toJson(),
        if (copyrights != null) ...{
          'copyrights': copyrights.map((v) => v.toJson()).toList(),
        },
        if (externalIds != null) ...{
          'external_ids': externalIds.toJson(),
        },
        'genres': genres,
        'popularity': popularity,
        'tracks': tracks,
      };
}

class Copyrights {
  String text;
  String type;

  Copyrights({this.text, this.type});

  Copyrights.fromJson(Map<String, dynamic> json) {
    text = json['text'];
    type = json['type'];
  }

  Map<String, dynamic> toJson() => {
        'text': text,
        'type': type,
      };
}
