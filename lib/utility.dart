import 'dart:io';

final env = Platform.environment;

String get userHome => {
  Platform.isMacOS: env['HOME'],
  Platform.isLinux: env['HOME'],
  Platform.isWindows: env['UserProfile'],
}[true];

Directory get userHomeDir => Directory(userHome);

String get separator => Platform.pathSeparator;

extension PathUtil on String {
  String get separatorFix => (startsWith('~') ? '$userHome${substring(1, length)}' : this).replaceAll('/', separator);

  File get file => File(separatorFix);

  Directory get directory => Directory(separatorFix);
}

extension NumUtil on int {
  String fixedLeftPad(int totalLength, [String padding = '0']) {
    var str = toString();
    return '${padding * (totalLength - str.length)}$str';
  }
}
