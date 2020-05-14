import 'dart:convert';
import 'dart:io';

import 'package:Spogit/utility.dart';

abstract class LocalStorage {
  final File _file;
  final Map<String, dynamic> _json;
  bool modified = false;

  LocalStorage(this._file) : _json = {...tryJsonDecode(_file.tryReadSync())} {
    print('LocalStorage[${_file.path}] = $_json');
  }

  void saveFile() {
    if (modified) {
      modified = false;
      print('Saving ${_file.path} = ${jsonEncode(_json)}');
      _file.tryCreateSync();
      _file.writeAsStringSync(jsonEncode(_json));
    }
  }

  dynamic operator [](key) {
    return _json[key];
  }

  void operator []=(key, value) {
    if (_json[key] != value) {
      modified = true;
      _json[key] = value;
    }
  }
}
