import 'package:Spogit/json/artist.dart';
import 'package:Spogit/json/image.dart';
import 'package:Spogit/json/json.dart';
import 'package:Spogit/json/paging.dart';
import 'package:Spogit/json/sub/external_ids.dart';
import 'package:Spogit/json/sub/external_url.dart';
import 'package:Spogit/json/track_full.dart';

class PlaylistFull with Jsonable {
  bool collaborative;
  String description;
  ExternalUrls externalUrls;
  Followers followers;
  String href;
  String id;
  List<Images> images;
  String name;
  Artists owner;
  bool public;
  String snapshotId;
  Paging<PlaylistTrack> tracks;
  String type;
  String uri;

  PlaylistFull(
      {this.collaborative,
        this.description,
        this.externalUrls,
        this.followers,
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

  PlaylistFull.fromJson(Map<String, dynamic> json) {
    collaborative = json['collaborative'];
    description = json['description'];
    externalUrls = json['external_urls'] != null
        ? new ExternalUrls.fromJson(json['external_urls'])
        : null;
    followers = json['followers'] != null
        ? new Followers.fromJson(json['followers'])
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
    owner = json['owner'] != null ? Artists.fromJson(json['owner']) : null;
    public = json['public'];
    snapshotId = json['snapshot_id'];
    tracks =
    json['tracks'] != null ? Paging.fromJson(json['tracks']) : null;
    type = json['type'];
    uri = json['uri'];
  }

  @override
  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['collaborative'] = this.collaborative;
    data['description'] = this.description;
    if (this.externalUrls != null) {
      data['external_urls'] = this.externalUrls.toJson();
    }
    if (this.followers != null) {
      data['followers'] = this.followers.toJson();
    }
    data['href'] = this.href;
    data['id'] = this.id;
    if (this.images != null) {
      data['images'] = this.images.map((v) => v.toJson()).toList();
    }
    data['name'] = this.name;
    if (this.owner != null) {
      data['owner'] = this.owner.toJson();
    }
    data['public'] = this.public;
    data['snapshot_id'] = this.snapshotId;
    if (this.tracks != null) {
      data['tracks'] = this.tracks.toJson();
    }
    data['type'] = this.type;
    data['uri'] = this.uri;
    return data;
  }
}

class Followers {
  String href;
  int total;

  Followers({this.href, this.total});

  Followers.fromJson(Map<String, dynamic> json) {
    href = json['href'];
    total = json['total'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['href'] = this.href;
    data['total'] = this.total;
    return data;
  }
}

class PlaylistTrack with Jsonable {
  String addedAt;
  Artists addedBy;
  bool isLocal;
  TrackFull track;

  PlaylistTrack({this.addedAt, this.addedBy, this.isLocal, this.track});

  PlaylistTrack.fromJson(Map<String, dynamic> json) {
    addedAt = json['added_at'];
    addedBy =
    json['added_by'] != null ? new Artists.fromJson(json['added_by']) : null;
    isLocal = json['is_local'];
    track = json['track'] != null ? new TrackFull.fromJson(json['track']) : null;
  }

  @override
  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['added_at'] = this.addedAt;
    if (this.addedBy != null) {
      data['added_by'] = this.addedBy.toJson();
    }
    data['is_local'] = this.isLocal;
    if (this.track != null) {
      data['track'] = this.track.toJson();
    }
    return data;
  }
}
