import 'dart:math';

abstract class MarkdownGenerator {
  String generate();
}

class Template {
  final List<Placeholder> _pieces;
  final Template Function() _overflowAppend;
  String _resulting = '';

  Template._(List<Placeholder> pieces, [this._overflowAppend])
      : _pieces = [...pieces];

  /// Constructs a template from the given [template] string, using
  /// [placeholder] as a placeholder for where data will be inserted.
  /// Is [staticOverflowAppend] is ser, the given [Template] will be appended
  /// when data is inserted and there is no space for it. Similarly,
  /// [overflowAppend] is invoked to create a [Template] in the same scenario.
  /// If [duplicateAppend] is true and [overflowAppend] is unset, the Template
  /// will duplicate its initial self and add it to the end, useful for things
  /// like tables or lists.
  factory Template.construct(String template,
      {Template staticOverflowAppend,
        Template Function() overflowAppend,
        bool duplicateAppend = false,
        String placeholder = '%'}) {
    var placeholding = <Placeholder>[];

    var iterator = template.split(placeholder).iterator;
    if (iterator.moveNext()) {
      placeholding.add(Placeholder(iterator.current));

      while (iterator.moveNext()) {
        placeholding.add(const Placeholder());
        placeholding.add(Placeholder(iterator.current));
      }
    }

    if (duplicateAppend) {
      overflowAppend ??= () => Template._(placeholding);
    } else {
      overflowAppend ??= () => staticOverflowAppend;
    }

    return Template._(placeholding, overflowAppend);
  }

  void insertPlaceholder(String data) {
    void handle(String str) => _resulting += str;

    var filledAny = false;
    int clearPieces() {
      for (var i = 0; i < _pieces.length; i++) {
        var curr = _pieces[i];
        if (curr.type == PlaceholderType.Empty) {
          filledAny = true;
          handle(data);
          return i + 1;
        } else {
          handle(curr.data);
        }
      }
      return _pieces.length;
    }

    _pieces.removeRange(0, clearPieces());

    if (!filledAny) {
      if (_pieces.isEmpty) {
        if (_overflowAppend == null) {
          return;
        }

        _pieces.addAll([..._overflowAppend()._pieces]);
      }

      _pieces.removeRange(0, clearPieces());
    }
  }

  void appendString(String data) => _pieces.add(Placeholder(data));

  String build([String remainingPlaceholders = '']) =>
      '${_resulting}${_pieces.map((place) => place.type == PlaceholderType.Empty ? remainingPlaceholders : place.data).join()}';
}

class Placeholder {
  final PlaceholderType type;

  /// Constant data if [type] is [PlaceholderType.Constant].
  final String data;

  const Placeholder([this.data])
      : type = data == null ? PlaceholderType.Empty : PlaceholderType.Constant;
}

enum PlaceholderType { Constant, Empty }
