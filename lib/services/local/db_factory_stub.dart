/// Default database factory setup for platforms with native sqflite support.
///
/// Android and iOS register their own factory inside the sqflite plugin, so
/// nothing has to happen here.
Future<void> configureDatabaseFactory() async {}
