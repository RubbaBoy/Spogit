import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:http/http.dart' as http;

final env = Platform.environment;

final listEquals = ListEquality().equals;

final mapEquals = MapEquality().equals;

final random = Random();

String get userHome => {
      Platform.isMacOS: env['HOME'],
      Platform.isLinux: env['HOME'],
      Platform.isWindows: env['UserProfile'],
    }[true];

Directory get userHomeDir => Directory(userHome);

String get separator => Platform.pathSeparator;

int get now => DateTime.now().millisecondsSinceEpoch;

void syncPeriodic(Duration duration, Function callback) {
  callback();
  Timer(duration, () async => await syncPeriodic(duration, callback));
}

String randomHex(int length) {
  var res = '';
  for (var i = 0; i < length / 2; i++) {
    res += random.nextInt(0xFF).toRadixString(16);
  }
  return res;
}

Uint8List fromMatcher(List data) => Uint8List.fromList(List<int>.of(
        data.map((value) => value is String ? value.codeUnitAt(0) : value))
    .toList());

void printConsole(Object obj) => print(obj);

V access<K, V>(Map<K, V> map, K key, [V def]) {
  if (map == null) {
    return def;
  }

  var val = map[key];
  return val ?? def;
}

// Json utils

Map<String, dynamic> jsonify(Map<dynamic, dynamic> map) =>
    Map<String, dynamic>.from(map);

Map<String, dynamic> tryJsonDecode(String json,
    [dynamic def = const <String, dynamic>{}]) {
  try {
    return jsonDecode(json);
  } on FormatException catch (e) {
    return def;
  }
}

// Extensions

extension StringUtils on String {
  int parseInt() => int.parse(this);

  double parseDouble() => double.parse(this);

  String get separatorFix =>
      (startsWith('~') ? '$userHome${substring(1, length)}' : this)
          .replaceAll('/', separator);

  File get file => File(separatorFix);

  Directory get directory => Directory(separatorFix);

  Uri get uri => Uri.tryParse(this);
}

extension NumUtil on int {
  String fixedLeftPad(int totalLength, [String padding = '0']) {
    var str = toString();
    return '${padding * (totalLength - str.length)}$str';
  }

  int add(int num) => this + num;

  int sub(int num) => this - num;
}

extension PathUtils on List<dynamic> {
  String get separatorFix =>
      map((e) => (e is File || e is Directory ? e.path : e) as String)
          .where((str) => str.isNotEmpty)
          .join(separator);

  File get file => File(separatorFix);

  Directory get directory => Directory(separatorFix);
}

extension SafeUtils<T> on List<T> {
  T get safeLast => isNotEmpty ? last : null;

  T get safeFirst => isNotEmpty ? first : null;
}

extension ASCIIShit on int {
  bool get isASCII => (this == 10 || this == 13 || (this >= 32 && this <= 126));

  bool get isNotASCII => !isASCII;
}

extension PrintStuff<T> on T {
  T print() {
    printConsole(this);
    return this;
  }
}

extension ResponseUtils on http.Response {
  Map<String, dynamic> get json => tryJsonDecode(body);
}

extension UriUtils on Uri {
  String get realName {
    if (pathSegments.length > 1 && pathSegments.last.isEmpty) {
      return ([...pathSegments]..removeLast()).last;
    }

    return pathSegments.last;
  }
}
