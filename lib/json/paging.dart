import 'package:Spogit/json/json.dart';

class Paging<T extends Jsonable> with Jsonable {
  final String href;
  final List<T> items;
  final int limit;
  final String next;
  final int offset;
  final String previous;
  final int total;

  Paging(this.href, this.items, this.limit, this.next, this.offset,
      this.previous, this.total);

  Paging.fromJson(Map<String, dynamic> json,
      [T Function(Map<String, dynamic>) pagingConvert])
      : href = json['href'],
        items = ((List<Map<String, dynamic>> list) => pagingConvert == null
            ? list
            : list
                .map(pagingConvert)
                .toList())(List<Map<String, dynamic>>.from(json['items'])),
        limit = json['limit'],
        next = json['next'],
        offset = json['offset'],
        previous = json['previous'],
        total = json['total'];

  @override
  Map<String, dynamic> toJson() => {
    'href': href,
    'items': items.map((item) => item.toJson()).toList(),
    'limit': limit,
    'next': next,
    'offset': offset,
    'previous': previous,
    'total': total,
  };
}
