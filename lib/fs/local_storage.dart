import 'dart:convert';
import 'dart:io';

import 'package:Spogit/utility.dart';

abstract class LocalStorage {
  final File _file;
  Map<String, dynamic> _json;

  LocalStorage(this._file);

  void saveFile() {
    _file.tryCreateSync();
    _file.writeAsStringSync(jsonEncode(_json));
  }

  dynamic operator [](key) {
    _json ??= {...tryJsonDecode(_file.tryReadSync())};
    return _json[key];
  }

  void operator []=(key, value) {
    _json ??= {...tryJsonDecode(_file.tryReadSync())};
    _json[key] = value;
    _file.writeAsStringSync(jsonEncode(_json));
  }
}
