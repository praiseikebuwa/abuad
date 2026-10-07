/// FirebaseStorageService has been replaced by CloudStorageService.
/// This file exists only as a compatibility shim so that any remaining
/// references continue to compile without changes.
///
/// Use CloudStorageService directly in new code.
library;
export 'cloud_storage_service.dart' show CloudStorageService;

// Alias so existing `FirebaseStorageService()` calls still resolve.
// ignore_for_file: non_constant_identifier_names
import 'cloud_storage_service.dart';

typedef FirebaseStorageService = CloudStorageService;
