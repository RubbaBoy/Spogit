import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:collection/collection.dart';

final env = Platform.environment;

final listEquals = ListEquality().equals;

final mapEquals = MapEquality().equals;

String get userHome => {
      Platform.isMacOS: env['HOME'],
      Platform.isLinux: env['HOME'],
      Platform.isWindows: env['UserProfile'],
    }[true];

Directory get userHomeDir => Directory(userHome);

String get separator => Platform.pathSeparator;

int get now => DateTime.now().millisecondsSinceEpoch;

Map<String, dynamic> tryJsonDecode(String json,
    [dynamic def = const <String, dynamic>{}]) {
  try {
    return jsonDecode(json);
  } on FormatException catch (e) {
    return def;
  }
}

void syncPeriodic(Duration duration, Function callback) {
  callback();
  Timer(duration, () async => await syncPeriodic(duration, callback));
}

extension PathUtil on String {
  String get separatorFix =>
      (startsWith('~') ? '$userHome${substring(1, length)}' : this)
          .replaceAll('/', separator);

  File get file => File(separatorFix);

  Directory get directory => Directory(separatorFix);
}

extension NumUtil on int {
  String fixedLeftPad(int totalLength, [String padding = '0']) {
    var str = toString();
    return '${padding * (totalLength - str.length)}$str';
  }
}

extension PathStuff on List<dynamic> {
  String get separatorFix =>
      map((e) => (e is File || e is Directory ? e.path : e) as String)
          .where((str) => str.isNotEmpty)
          .join(separator);

  File get file => File(separatorFix);

  Directory get directory => Directory(separatorFix);
}

Uint8List fromMatcher(List data) => Uint8List.fromList(List<int>.of(
        data.map((value) => value is String ? value.codeUnitAt(0) : value))
    .toList());

extension ASCIIShit on int {
  bool get isASCII => (this == 10 || this == 13 || (this >= 32 && this <= 126));

  bool get isNotASCII => !isASCII;
}
