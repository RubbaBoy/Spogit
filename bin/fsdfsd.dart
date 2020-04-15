import 'dart:async';
import 'dart:io';

import 'dart:typed_data';

void main(List<String> args) {
//  evaluate(File(r'E:\Spogit\temp3.file'));
//    print('\n');
//    evaluate(File(r'E:\Spogit\temp2.file'));

readForPlaylists(Directory(r'C:\Users\RubbaBoy\AppData\Local\Spotify\Storage'));
}

const show0x = true;
final int SINGLE = '%'.codeUnitAt(0);
final int ANY = '+'.codeUnitAt(0);

void evaluate(File file) {
//  var show0x = true;
//  print(file.readAsBytesSync().map((b) => (b == 10 || b == 13 || (b >= 32 && b <= 126)) ? String.fromCharCode(b) : '${show0x ? ' 0x' : ' '}${b.toRadixString(16).toUpperCase()} ').join());

//  0x9 % Name 0x9  0x10 & 0xEF  0xBF  0xBD v! 0xEF  0xBF  0xBD ]Hr 0xEF  0xBF  0xBD  0xEF  0xBF  0xBD ?zJ 0xEF  0xBF  0xBD h 0x6  0x8  0xEF  0xBF  0xBD  0x1  0x8

  prettyPrint(matchWith(file.readAsBytesSync(), fromMatcher([ /* <editor-fold desc="Song Matcher"> */
    0x9,
    SINGLE,
    ANY,
    0x9,
    0x10,
    '&',
    0xEF,
    0xBF,
    0xBD,
    'v',
    '!',
    0xEF,
    0xBF,
    0xBD,
    ']',
    'H',
    'r',
    0xEF,
    0xBF,
    0xBD,
    0xEF,
    0xBF,
    0xBD,
    '?',
    'z',
    'J',
    0xEF,
    0xBF,
    0xBD,
    'h',
    0x6,
    0x8,
    0xEF,
    0xBF,
    0xBD,
    0x1,
    0x8
    /* </editor-fold> */ ])));
}

void readForPlaylists(Directory cacheDirectory) {
  cacheDirectory.list(recursive: true).listen((entity) {
    try {
      if (entity is File) {
        var data = entity.readAsBytesSync();
        var checked = checkData(data, fromMatcher([0x11, ANY, 0x19]));
        if (checked.isNotEmpty) {
          print(checked);
          var string = String.fromCharCodes(checked[0]);
          print('FOUND IT!');
          print('${entity.path} => $string)');
          Process.run(r'C:\Users\RubbaBoy\ToolboxScripts\idea.cmd', [entity.path]);
//        completer.complete([entity, data]);
//        sub.cancel();
        }
      }
    } catch (e, s) {
    }
  });
}

void prettyPrint(List<List<List<int>>> matches) {
  for (var group in matches) {

    if (group[0].length == 1) {
      continue;
    }

    print('===== Group =====');

    var index = 0;
    for (var placeholder in group) {
      print('Placholder #${index++}:');
      print(bytesToString(placeholder));
      print('');
    }

    print('----- / Group / -----');
  }
}

List<List<List<int>>> matchWith(Uint8List input, List<int> data) {
  var result = <List<List<int>>>[];
  for (var i = 0; i < input.length; i++) {
    if (input[i] != data[0]) {
      continue;
    }

//    print('${input[i]} == ${data[0]}');

    var checked = checkData(input.sublist(i), data);
    if (checked?.isNotEmpty ?? false) {
      result.add(checked);

//      if (checked[0].length == 1) {
//        continue;
//      }
//
//      print('===== Group =====');
//
//      var index = 0;
//      for (var placeholder in checked) {
//        print('Placholder #${index++}:');
//        print(bytesToString(placeholder));
//        print('');
//      }
//
//      print('----- / Group / -----');
    }
  }

  return result;
}

List<List<int>> checkData(Uint8List input, List<int> data) {
  var dataIndex = 0;
  var bufferBuffer = <int>[];
  var buffer = <List<int>>[];
  for (var b in input) {
    if (b == 10 || b == 13) continue;

    var dataVal = data[dataIndex];
    if (dataVal == SINGLE) {
      if (b.isASCII) {
        return buffer;
      }
//      buffer.add([b]);
      dataIndex++;
    } else if (dataVal == ANY) {
//      print('on any with $b');

      // If NOT ascii
      if (b.isNotASCII) {
        dataIndex++;
        if (bufferBuffer.isNotEmpty) {
          buffer.add([...bufferBuffer]);
          bufferBuffer.clear();
        }

        continue;
      }

      // If it accepts anything but the next byte matches the input, cancel the all
      if (b == data[dataIndex + 1]) {
//        print('Buffer full at ${bufferBuffer.length} because $b == ${data[dataIndex + 1]} data[${dataIndex + 1}]');
        buffer.add([...bufferBuffer]);
        bufferBuffer.clear();
        dataIndex++;
      } else {
        bufferBuffer.add(b);
      }
    } else if (b == dataVal) {
      dataIndex++;
//      bufferBuffer.add(b);
    } else {
      return buffer;
    }
  }

  print('COMPLETED!');
  return buffer;
}

String bytesToString(List<int> bytes) =>
    bytes.map((b) => b.isASCII
        ? String.fromCharCode(b)
        : '${show0x ? ' 0x' : ' '}${b.toRadixString(16).toUpperCase()} ').join();



/*

Key:
% - Can be anything, changes

0x9 % Name 0x9  0x10 & 0xEF  0xBF  0xBD v! 0xEF  0xBF  0xBD ]Hr 0xEF  0xBF  0xBD  0xEF  0xBF  0xBD ?zJ 0xEF  0xBF  0xBD h 0x6  0x8  0xEF  0xBF  0xBD  0x1  0x8



               0xEF  0xBF  0xBD  t     0xCA  0x84  0x19  0xEF  0xBF  0xBD  \     0xEF  0xBF  0xBD  0x9  0xC T-Shirt Song 0x9  0x10 & 0xEF  0xBF  0xBD v! 0xEF  0xBF  0xBD ]Hr 0xEF  0xBF  0xBD  0xEF  0xBF  0xBD ?zJ 0xEF  0xBF  0xBD h 0x6  0x8  0xEF  0xBF  0xBD  0x1
     0xEF  0xBF  0xBD  0xC3  0xA4  0xEF  0xBF  0xBD  0x1A  0xEF  0xBF  0xBD  0xEF  0xBF  0xBD 0x9  0x9  0x9 Greatness 0x9  0x10 & 0xEF  0xBF  0xBD v! 0xEF  0xBF  0xBD ]Hr 0xEF  0xBF  0xBD  0xEF  0xBF  0xBD ?zJ 0xEF  0xBF  0xBD h 0x6  0x8  0xEF  0xBF
0xEF  0xBF  0xBD  0xEF  0xBF  0xBD  /     0     0xEF  0xBF  0xBD  0x12  0xEF  0xBF  0xBD u   /     0x9  0x1B You Wanna Know - Remastered 0x9  0x10 & 0xEF  0xBF  0xBD v! 0xEF  0xBF  0xBD ]Hr 0xEF  0xBF  0xBD  0xEF  0xBF  0xBD ?zJ 0xEF  0xBF


 */

//class Format {
//  final
//}
