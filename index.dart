import 'package:shinga_plugin_sdk/shinga_plugin_sdk.dart';

/// Provides source content through the Shinga plugin API v1.
final class SourceProvider extends SourceProviderBase {
  /// Declares the source's search filters and sorting options.
  @override
  Future<SourceSearchSchema> getSearchSchema() async {
    // Required: the search capabilities exposed by this source.
    throw UnimplementedError('getSearchSchema');
  }

  /// Returns one page matching the query, selections and continuation.
  @override
  Future<SourceSearchResult> search(SourceSearchRequest request) async {
    // Required: source results and the next continuation, if available.
    throw UnimplementedError('search');
  }

  /// Returns full metadata for a stable source-local title ID.
  @override
  Future<SourceTitleDetails> getTitle(SourceTitleId id) async {
    // Required: metadata for the requested title.
    throw UnimplementedError('getTitle');
  }

  /// Returns home sections when the source supports them.
  @override
  Future<SourceHome> getHome() async {
    // Optional: unsupported until this source provides home content.
    throw const SourceUnsupportedException();
  }

  /// Returns the initial reading URL when the source supports it.
  @override
  Future<Uri> getInitialReadUrl(SourceTitleId id) async {
    // Optional: unsupported until this source provides a reading URL.
    throw const SourceUnsupportedException();
  }
}
