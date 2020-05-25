import 'package:Spogit/cache/album/album_resource.dart';
import 'package:Spogit/cache/cache_manager.dart';
import 'package:Spogit/cache/cache_types.dart';
import 'package:Spogit/driver/playlist_manager.dart';
import 'package:Spogit/json/album_full.dart';
import 'package:logging/logging.dart';

class AlbumResourceManager {

  final log = Logger('AlbumResourceManager');

  final PlaylistManager playlistManager;
  final CacheManager cacheManager;

  AlbumResourceManager(this.playlistManager, this.cacheManager);

  /// Gets of retrieves the album JSON with the given ID.
  Future<AlbumFull> getAlbumFromId(String albumId) async {
    albumId = albumId.parseId;

    var albums = cacheManager.getAllOfType(CacheType.ALBUM);
    var foundAlbum = albums.firstWhere((album) => album.data.id == albumId, orElse: () => null);

    if (foundAlbum != null) {
      return foundAlbum.data;
    }

    // The full album must be gotten for access for the tracks
    var fullAlbum = await playlistManager.getAlbum(albumId);

    cacheManager[albumId] = AlbumResource(albumId, fullAlbum);

    return fullAlbum;
  }

  /// Gets or retrieves the album JSON for the associated track ID.
  Future<AlbumFull> getAlbumFromTrack(String track) async {
    track = track.parseId;

    var albums = cacheManager.getAllOfType(CacheType.ALBUM);
    var foundAlbum = albums.firstWhere((album) => album.data.tracks.items.any((trackObj) => trackObj.id == track), orElse: () => null);

    if (foundAlbum != null) {
      return foundAlbum.data;
    }

    var gottenTrack = await playlistManager.getTrack(track);
    if (gottenTrack == null) {
      log.severe('Gotten track for ID "$track" is null!');
      return null;
    }

    var album = gottenTrack.album;

    // The full album must be gotten for access for the tracks
    var fullAlbum = await playlistManager.getAlbum(album.id);

    cacheManager[album.id] = AlbumResource(album.id, fullAlbum);

    return fullAlbum;
  }
}
