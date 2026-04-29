import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../models/media_asset.dart';
import 'api_client.dart';
import 'media_service.dart';

enum UploadStatus { pending, uploading, uploaded, failed }

class UploadQueueItem with ChangeNotifier {
  final XFile file;
  UploadStatus status;
  double progress;
  String? errorMessage;
  int attemptCount = 0;
  CancelToken? cancelToken;

  UploadQueueItem({
    required this.file,
    this.status = UploadStatus.pending,
    this.progress = 0.0,
    this.errorMessage,
  });

  void updateStatus(UploadStatus newStatus, {String? error}) {
    status = newStatus;
    if (error != null) errorMessage = error;
    notifyListeners();
  }

  void updateProgress(double newProgress) {
    progress = newProgress;
    notifyListeners();
  }

  void incrementAttempt() {
    attemptCount++;
    notifyListeners();
  }
}

class UploadQueueNotifier extends StateNotifier<List<UploadQueueItem>> {
  final ApiClient _apiClient;
  final MediaNotifier _mediaNotifier;
  final int _maxConcurrentUploads = 1;
  bool _isProcessing = false;
  bool _isCancelled = false;

  UploadQueueNotifier(this._apiClient, this._mediaNotifier) : super([]);

  void addFilesToQueue(List<XFile> files) {
    _isCancelled = false;
    final newItems = files.map((f) => UploadQueueItem(file: f)).toList();
    state = [...state, ...newItems];
    _processQueue();
  }
  
  void retryFile(UploadQueueItem item) {
    _isCancelled = false;
    item.updateStatus(UploadStatus.pending, error: null);
    item.attemptCount = 0;
    _processQueue();
  }

  void retryAllFailed() {
    _isCancelled = false;
    for (final item in state) {
      if (item.status == UploadStatus.failed) {
        item.updateStatus(UploadStatus.pending, error: null);
        item.attemptCount = 0;
      }
    }
    _processQueue();
  }

  void removeFile(UploadQueueItem item) {
    item.cancelToken?.cancel('Removed from queue');
    state = state.where((i) => i != item).toList();
  }

  void cancelAll() {
    _isCancelled = true;
    for (final item in state) {
      if (item.status == UploadStatus.uploading || item.status == UploadStatus.pending) {
        item.cancelToken?.cancel('Cancelled by user');
        if (item.status == UploadStatus.pending) {
           // We'll leave pending as is, or we could mark them as something else.
        }
      }
    }
  }

  void clearCompleted() {
    state = state.where((item) => item.status != UploadStatus.uploaded).toList();
  }

  Future<void> _processQueue() async {
    if (_isProcessing) return;
    _isProcessing = true;

    try {
      while (!_isCancelled) {
        final pendingItems = state.where((item) => item.status == UploadStatus.pending).toList();
        if (pendingItems.isEmpty) break;
        
        final uploadingCount = state.where((item) => item.status == UploadStatus.uploading).length;
        if (uploadingCount >= _maxConcurrentUploads) {
          // Wait for some uploads to finish
          await Future.delayed(const Duration(milliseconds: 500));
          continue;
        }

        final itemsToStart = pendingItems.take(_maxConcurrentUploads - uploadingCount);
        for (final item in itemsToStart) {
          _uploadItemWithRetry(item);
        }
        
        // Small delay to avoid tight loop
        await Future.delayed(const Duration(milliseconds: 200));
      }
    } finally {
      _isProcessing = false;
      if (state.every((item) => item.status == UploadStatus.uploaded || item.status == UploadStatus.failed)) {
        _mediaNotifier.refresh();
      }
    }
  }

  Future<void> _uploadItemWithRetry(UploadQueueItem item) async {
    const maxRetries = 3;
    const retryDelays = [2, 5, 10]; // seconds

    while (item.attemptCount < maxRetries && !_isCancelled) {
      item.incrementAttempt();
      item.updateStatus(UploadStatus.uploading, error: null);
      item.cancelToken = CancelToken();

      debugPrint('UPLOAD START: ${item.file.name} | Attempt: ${item.attemptCount}');

      try {
        final responseData = await _apiClient.uploadImage(
          item.file,
          cancelToken: item.cancelToken,
          onSendProgress: (sent, total) {
            if (total > 0) {
              item.updateProgress(sent / total);
            }
          },
        );

        debugPrint('UPLOAD SUCCESS: ${item.file.name} | Response: $responseData');
        
        final newAsset = MediaAsset.fromUploadResponse(responseData);
        await _mediaNotifier.addAssetToBox(newAsset);
        
        item.updateStatus(UploadStatus.uploaded);
        return; // Success, exit retry loop
      } on DioException catch (e) {
        final statusCode = e.response?.statusCode;
        final errorMsg = _getErrorMessage(e);
        
        debugPrint('UPLOAD DIO ERROR: ${item.file.name} | Status: $statusCode | Error: $errorMsg');

        bool shouldRetry = _isRetryableError(e);

        if (shouldRetry && item.attemptCount < maxRetries && !_isCancelled) {
          final delay = retryDelays[item.attemptCount - 1];
          item.updateStatus(UploadStatus.uploading, error: 'Retrying in $delay seconds... ($errorMsg)');
          await Future.delayed(Duration(seconds: delay));
        } else {
          item.updateStatus(UploadStatus.failed, error: errorMsg);
          return;
        }
      } catch (e) {
        debugPrint('UPLOAD UNKNOWN ERROR: ${item.file.name} | Error: $e');
        item.updateStatus(UploadStatus.failed, error: e.toString());
        return;
      }
    }
  }

  String _getErrorMessage(DioException e) {
    if (e.type == DioExceptionType.cancel) return 'Upload cancelled';
    
    final response = e.response;
    if (response != null) {
      if (response.statusCode == 502) {
        return 'Server error during upload. The file will be retried automatically.';
      }
      if (response.data != null) {
        if (response.data is Map) {
          return response.data['error'] ?? response.data['message'] ?? 'Status: ${response.statusCode}';
        }
        return response.data.toString();
      }
      return 'HTTP Error ${response.statusCode}';
    }
    
    switch (e.type) {
      case DioExceptionType.connectionTimeout: return 'Connection timeout';
      case DioExceptionType.sendTimeout: return 'Send timeout';
      case DioExceptionType.receiveTimeout: return 'Receive timeout';
      case DioExceptionType.connectionError: return 'Connection error';
      default: return e.message ?? 'Unknown network error';
    }
  }

  bool _isRetryableError(DioException e) {
    if (e.type == DioExceptionType.cancel) return false;
    
    final statusCode = e.response?.statusCode;
    if (statusCode != null) {
      // 502 Bad Gateway, 503 Service Unavailable, 504 Gateway Timeout
      return statusCode == 502 || statusCode == 503 || statusCode == 504;
    }
    
    // Timeouts and connection errors are usually retryable
    return e.type == DioExceptionType.connectionTimeout ||
           e.type == DioExceptionType.sendTimeout ||
           e.type == DioExceptionType.receiveTimeout ||
           e.type == DioExceptionType.connectionError;
  }
}

final uploadQueueProvider = StateNotifierProvider<UploadQueueNotifier, List<UploadQueueItem>>((ref) {
  return UploadQueueNotifier(ref.watch(apiClientProvider), ref.watch(mediaProvider.notifier));
});
