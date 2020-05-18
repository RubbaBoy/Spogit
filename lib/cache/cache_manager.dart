import 'dart:async';
import 'dart:io';

import 'package:Spogit/cache/cache_types.dart';
import 'package:Spogit/cache/cached_resource.dart';
import 'package:Spogit/utility.dart';
import 'package:logging/logging.dart';
import 'package:msgpack2/msgpack2.dart' as msgpack;

/// Manages caches for arbitrary resources such as playlist images.
class CacheManager {
  final log = Logger('CacheManager');

  final File cacheFile;

  /// The resource type as the key, and the generator from unpacked data.
  final Map<int, CachedResource Function(int, Map)> functionGenerator = {};

  /// The resource ID as the key, and the [CachedResource] as the value.
  final Map<int, CachedResource> cache = {};

  /// The time in seconds cache may live by default. This may be overridden by
  /// a [CachedResource].
  final int cacheLife;

  bool modified = false;

  CacheManager(this.cacheFile, {this.cacheLife = 3600});

  void registerType(CacheType resourceType,
      CachedResource Function(int, Map) cacheGenerator) =>
      functionGenerator[resourceType.id] = cacheGenerator;

  /// Reads caches from the file into memory.
  Future<void> readCache() async {
    if (!(await cacheFile.exists())) {
      return;
    }

    var unpacked = msgpack.deserialize(await cacheFile.readAsBytes()) as Map;
    for (int id in unpacked.keys) {
      /*
      12345678: { // The ID
        'type': 1,
        'data': { /* specific to type */ }
      }
       */

      var data = unpacked[id];
      var type = data['type'];
      var generator = functionGenerator[type];

      if (generator == null) {
        log.warning('No generator found for resource type $type');
        continue;
      }

      var resource = generator.call(id, data);

      if (resource == null) {
        log.warning('Null resource created');
        continue;
      }

      cache[id] = resource;
    }
  }

  /// Writes all caches to the cache file if they have been modified.
  Future<void> writeCache() async {
    if (!modified) {
      return;
    }

    print('Writing caches...');
    modified = false;
    var file = await cacheFile.writeAsBytes(
        msgpack.serialize(cache.map((id, cache) =>
            MapEntry(id, {
              'type': cache.type.id,
              'createdAt': cache.createdAt,
              'data': cache.pack()
            })).print()));
    print('Cache file is ${file.lengthSync()} bytes');
  }

  /// Removes all cache elements with an ID in the given [keys] list.
  void clearCacheFor(List<dynamic> keys) {
    for (var key in keys) {
      cache.remove(customHash(key));
    }
  }

  /// Schedules writes for the given [Duration], or by default every 10 seconds
  /// only if the cache has been updated.
  void scheduleWrites([Duration duration = const Duration(seconds: 10)]) =>
      Timer.periodic(duration, (_) async => await writeCache());

  /// Gets if the cache contains the key.
  bool containsKey(dynamic id) => cache.containsKey(id.customHash);

  /// Gets all cache values of the given [type].
  List<T> getAllOfType<T extends CachedResource>(CacheType<T> type) =>
      cache.values.whereType<T>().toList();

  /// Identical to [getOr] but for always-synchronous [resourceGenerator]s.
  GetOrResult<T> getOrSync<T extends CachedResource>(dynamic id,
      CachedResource Function() resourceGenerator,
      {bool Function(CachedResource) forceUpdate}) {
    var handled = _handleGetOr(id, forceUpdate);
    return GetOrResult((handled[0] ?? (cache[handled[1]] = resourceGenerator())) as T, handled[2]);
  }

  /// Gets a resource from an [id] which may be anything, as it is transformed
  /// via [customHash]. If it is not found or expired, [resourceGenerator] is
  /// invoked and set to the [id].
  ///
  /// If [forceUpdate] is set, it should return a boolean for if the
  /// [resourceGenerator] should be invoked regardless of expiration level.
  /// This is used for things like comparing internal data values of the
  /// resource.
  Future<GetOrResult<T>> getOr<T extends CachedResource>(dynamic id,
      FutureOr<CachedResource> Function() resourceGenerator,
      {bool Function(CachedResource) forceUpdate}) async {
    var handled = _handleGetOr(id, forceUpdate);
    return GetOrResult(handled[0] ?? (cache[handled[1]] = await resourceGenerator()), handled[2]);
  }

  /// Handles `getOr` methods. Returns the cached variable or null. In the case
  /// of returning null
  List _handleGetOr<T extends CachedResource>(dynamic id,
      bool Function(CachedResource) forceUpdate) {
    id = id is int ? id : CustomHash(id).customHash;
    var cached = cache[id];
    if ((cached?.isExpired() ?? true) || (forceUpdate?.call(cached) ?? false)) {
      modified = true;
      return [null, id, true];
    }
    return [cached, null, false];
  }

  /// Gets a resource from an [id] which may be anything, as it is transformed
  /// via [customHash]. Returns an instance of [CachedResource].
  CachedResource operator [](dynamic id) {
    id = id is int ? id : CustomHash(id).customHash;
    return cache[id];
  }

  /// Sets a resource to a given [id] which may be anything, as it is
  /// transformed via [customHash].
  operator []=(dynamic id, CachedResource resource) {
    id = id is int ? id : CustomHash(id).customHash;
    cache[id] = resource;
    modified = true;
  }
}

class GetOrResult<T extends CachedResource> {
  final T resource;
  final bool generated;

  GetOrResult(this.resource, this.generated);
}
