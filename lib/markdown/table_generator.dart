import 'dart:math';

import 'package:Spogit/markdown/md_generator.dart';
import 'package:Spogit/utility.dart';

class TableGenerator extends MarkdownGenerator {
  final List<String> data;
  final int columns;

  String get _rowString => ('%|' * columns) - 1;

  String get _divider => (':--:|' * columns) - 1;

  TableGenerator(this.data, {int columns = 3, bool formFitting = true})
      : columns = formFitting ? min(data.length, columns) : columns;

  @override
  String generate() {
    final rowTemplate =
        Template.construct('${_rowString}\n', duplicateAppend: true);

    data.take(columns).forEach(rowTemplate.insertPlaceholder);
    rowTemplate.appendString('$_divider');
    data.skip(columns).forEach(rowTemplate.insertPlaceholder);

    return rowTemplate.build('<a/>');
  }
}
