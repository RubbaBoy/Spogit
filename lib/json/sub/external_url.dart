class ExternalUrls {
  final String spotify;

  ExternalUrls({this.spotify});

  ExternalUrls.fromJson(Map<String, dynamic> json) : spotify = json['spotify'];

  Map<String, dynamic> toJson() => {'spotify': spotify};
}
