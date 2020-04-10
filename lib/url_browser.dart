import 'dart:io';

void browseUrl(String url) {
  var result = {
    Platform.isMacOS: ['open', [url]],
    Platform.isLinux: ['xdg-open', [url]],
    Platform.isWindows: ['cmd', ['/c', 'start', url]],
  }[true];

  Process.start(result[0], result[1]);
}
