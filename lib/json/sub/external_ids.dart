class ExternalType {
  static const ISRC =
      ExternalType('isrc'); // International Standard Recording Code
  static const EAN = ExternalType('ean'); // International Article Number
  static const UPC = ExternalType('upc'); // Universal Product Code

  final String name;

  const ExternalType(this.name);
}

class ExternalIds {
  final String data;
  final ExternalType type;

  ExternalIds(this.type, {this.data});

  ExternalIds.fromJson(this.type, Map<String, dynamic> json)
      : data = json[type.name];

  Map<String, dynamic> toJson() => {type.name: data};
}
