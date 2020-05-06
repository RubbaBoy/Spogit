
import 'package:Spogit/cache/cache_types.dart';
import 'package:Spogit/utility.dart';

abstract class CachedResource<T> {
  final String id;
  final CacheType type;
  final int createdAt;
  final T data;

  CachedResource(this.id, this.type, this.createdAt, this.data);

  /// Packs the [data] of the resource. The [id] and [type] are already handled
  /// and should not be a factor in this packing.
  Map pack();

  /// If more seconds than the [type]'s ttl has passed.
  bool isExpired() => now - createdAt > type.ttl;
}
