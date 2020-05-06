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
  final Map<int, CachedResource Function(Map)> functionGenerator = {};

  /// The resource ID as the key, and the [CachedResource] as the value.
  final Map<int, CachedResource> cache = {};

  /// The time in seconds cache may live by default. This may be overridden by
  /// a [CachedResource].
  final int cacheLife;

  bool modified = false;

  CacheManager(this.cacheFile, {this.cacheLife = 3600});

  void registerType(
          CacheType resourceType, CachedResource Function(Map) cacheGenerator) =>
      functionGenerator[resourceType.id] = cacheGenerator;

  /// Reads caches from the file into memory.
  Future<void> readCache() async {
    if (!(await cacheFile.exists())) {
      return;
    }

    var unpacked = msgpack.deserialize(await cacheFile.readAsBytes()) as Map;
    for (var id in unpacked.keys) {
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

      var resource = generator.call(data);

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
    var file = await cacheFile.writeAsBytes(msgpack.serialize(cache.map((id, cache) =>
        MapEntry(id, {
          'type': cache.type,
          'createdAt': cache.createdAt,
          'data': cache.pack()
        }))));
    print('Cache file is ${file.lengthSync()} bytes');
  }

  /// Schedules writes for the given [Duration], or by default every 10 seconds
  /// only if the cache has been updated.
  void scheduleWrites([Duration duration = const Duration(seconds: 10)]) =>
      Timer.periodic(duration, (_) async => await writeCache());

  /// Gets a resource from an [id] which may be anything, as it is transformed
  /// via [customHash]. If it is not found or expired, [resourceGenerator] is
  /// invoked and set to the [id].
  ///
  /// If [forceUpdate] is set, it should return a boolean for if the
  /// [resourceGenerator] should be invoked regardless of expiration level.
  /// This is used for things like comparing internal data values of the
  /// resource.
  FutureOr<T> getOr<T extends CachedResource>(
      dynamic id, FutureOr<CachedResource> Function() resourceGenerator,
      {bool Function(CachedResource) forceUpdate}) async {
    id = id is int ? id : CustomHash(id).customHash;
    var cached = cache[id];
    if ((cached?.isExpired() ?? true) || (forceUpdate?.call(cached) ?? false)) {
      modified = true;
      return cache[id] = await resourceGenerator() as T;
    }
    return cached as T;
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
