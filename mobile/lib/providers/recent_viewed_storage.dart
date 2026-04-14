import 'recent_viewed_storage_stub.dart'
    if (dart.library.html) 'recent_viewed_storage_web.dart' as impl;

Future<List<String>> recentViewedGetIds() => impl.recentViewedGetIds();

Future<void> recentViewedSetIds(List<String> ids) =>
    impl.recentViewedSetIds(ids);
