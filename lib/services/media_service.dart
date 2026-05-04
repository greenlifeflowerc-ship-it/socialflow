import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/media_asset.dart';
import 'api_client.dart';

final mediaProvider = StateNotifierProvider<MediaNotifier, List<MediaAsset>>((ref) {
  return MediaNotifier(ref.watch(apiClientProvider));
});

class MediaNotifier extends StateNotifier<List<MediaAsset>> {
  final ApiClient _apiClient;
  late final Box<MediaAsset> _mediaBox;

  MediaNotifier(this._apiClient) : super([]) {
    _init();
  }

  Future<void> _init() async {
    if (!Hive.isBoxOpen('mediaLibrary')) {
      await Hive.openBox<MediaAsset>('mediaLibrary');
    }
    _mediaBox = Hive.box<MediaAsset>('mediaLibrary');
    state = _mediaBox.values.toList().reversed.toList();
    _mediaBox.listenable().addListener(_onDataChanged);
    refresh(); // Refresh from backend on init
  }

  void _onDataChanged() {
    state = _mediaBox.values.toList().reversed.toList();
  }

  Future<void> refresh() async {
    try {
      final response = await _apiClient.getMedia();
      final mediaJson = _apiClient.parseListFromAnyKey(response, ['media', 'items', 'data']);
      
      for (final item in mediaJson) {
        final asset = MediaAsset.fromUploadResponse(item as Map<String, dynamic>);
        await _mediaBox.put(asset.id, asset);
      }
    } catch (e) {
      print('Error refreshing media: $e');
    }
  }

  // Called by the Upload Service after a file is successfully uploaded
  Future<void> addAssetToBox(MediaAsset asset) async {
    await _mediaBox.put(asset.id, asset);
  }

  Future<void> deleteMedia(String assetId) async {
    // Throws on backend failure — let callers handle errors.
    await _apiClient.deleteMedia(assetId);
    await _mediaBox.delete(assetId);
  }

  Future<void> updateMedia(MediaAsset asset) async {
    await _mediaBox.put(asset.id, asset);
  }

  @override
  void dispose() {
    _mediaBox.listenable().removeListener(_onDataChanged);
    super.dispose();
  }
}
