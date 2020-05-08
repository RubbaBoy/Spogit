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
    return jsonDecode(json) ?? def;
  } on FormatException catch (e) {
    return def;
  }
}

// Extensions

extension StringUtils on String {
  static final QUOTES_REGEX = RegExp('[^\\s"\']+|"([^"]*)"|\'([^\']*)\'');

  int parseInt() => int.parse(this);

  double parseDouble() => double.parse(this);

  String get separatorFix =>
      (startsWith('~') ? '$userHome${substring(1, length)}' : this)
          .replaceAll('/', separator);

  File get file => File(separatorFix);

  Directory get directory => Directory(separatorFix);

  Uri get uri => Uri.tryParse(this);

  List<String> splitMulti(List<String> strings) {
    var list = [this];
    for (var value in strings) {
      list = list.expand((inner) => inner.split(value)).toList();
    }
    return list;
  }

  List<String> splitQuotes() => QUOTES_REGEX
      .allMatches(this)
      .map((match) => match.group(1) ?? match.group(0))
      .toList();
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

extension ASCIIShit on int {
  bool get isASCII => (this == 10 || this == 13 || (this >= 32 && this <= 126));

  bool get isNotASCII => !isASCII;
}

extension PrintStuff<T> on T {
  T print([String leading = '', String trailing = '']) {
    printConsole('$leading${this}$trailing');
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

// Extensions meant for general safety/ease of use of stuff

extension SafeUtils<T> on List<T> {
  T get safeLast => isNotEmpty ? last : null;

  T get safeFirst => isNotEmpty ? first : null;

  /// If the current list contains all elements as the given [elements].
  bool containsAll(List<T> elements) {
    for (var value in elements) {
      if (!contains(value)) {
        return false;
      }
    }

    return true;
  }

  /// If both the current and given [elements] contains only the same elements. Order
  /// is not mandatory.
  bool elementsEqual(List<T> elements) =>
      elements.length == length &&
      containsAll(elements) &&
      elements.containsAll(this);
}

extension DirUtils on Directory {
  void tryCreateSync([bool recursive = true]) {
    if (existsSync()) {
      createSync(recursive: recursive);
    }
  }

  Future<void> tryCreate([bool recursive = true]) async =>
      exists().then((exists) async {
        if (!exists) {
          await create(recursive: recursive);
        }
      });

  /// Deletes all children synchronously, preserving the current [Directory].
  void deleteChildrenSync() =>
      listSync().forEach((entity) => entity.deleteSync());

//  /// Deletes all children asynchronously, preserving the current [Directory].
//  Future<void> deleteChildren() async =>
//      (await list().toList()).forEach((entity) async => await entity.delete());
}

extension FileUtils on File {
  void tryCreateSync([bool recursive = true]) {
    if (!existsSync()) {
      createSync(recursive: recursive);
    }
  }

  Future<void> tryCreate([bool recursive = true]) async =>
      exists().then((exists) async {
        if (!exists) {
          await create(recursive: recursive);
        }
      });

  String tryReadSync({bool create = true, String def = ''}) {
    if (existsSync()) {
      return readAsStringSync();
    } else if (create) {
      createSync(recursive: true);
    }

    return def;
  }

  Future<String> tryRead({bool create = true, String def = ''}) async {
    return exists().then((exists) async {
      if (exists) {
        return readAsString();
      } else if (create) {
        await this.create(recursive: true);
      }

      return def;
    });
  }
}

int customHash(dynamic dyn) => CustomHash(dyn).customHash;

extension CustomHash on dynamic {
  int get customHash {
    var total = 0;
    if (this is Map) {
      var map = this as Map;
      for (var key in map.keys) {
        total ^= CustomHash(key).customHash;
        total ^= CustomHash(map[key]).customHash;
      }
    } else {
      total = this.hashCode;
    }

    return total;
  }
}

extension IterableUtils<T> on Iterable<T> {
  Iterable<T> notNull() => where((value) => value != null);
}
