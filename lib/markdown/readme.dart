
final descriptionRegex = RegExp(r'\[start\-desc\]: #\s+(.*?)\s+\[end\-desc\]: #', dotAll: true);
final linkRegex = RegExp(r'\[([^\\]*?)\]\(.*?spotify:track:([a-zA-Z0-9]{22})\)');

class Readme {
  int titleLevel;
  String title;
  String description;
  String descriptionPlaceholder;
  String content;

  Readme.createTitled({this.titleLevel = 2, this.title, this.description, this.descriptionPlaceholder = 'Replace this line with a description persistent with the repository.', this.content});

  factory Readme.parse(String content) {
    content = content.trim();

    var titleLevel = 2;
    String title;
    var contentStart = 0;

    if (content.startsWith('#')) {
      var space = content.indexOf(' ');
      var hashes = content.substring(0, space);
      contentStart = content.indexOf('\n');
      titleLevel = hashes.length;
      title = content.substring(space, contentStart).trim();
    }

    var first = descriptionRegex.firstMatch(content);

    var description = first?.group(1);
    var remaining = content.substring(first?.end ?? 0);

    return Readme.createTitled(titleLevel: titleLevel, title: title, description: description, content: remaining);
  }

  String create() => '''
${'#' * titleLevel} $title
[start-desc]: #

${description ?? '[//]: # ($descriptionPlaceholder)'}

[end-desc]: #

$content
''';
}
