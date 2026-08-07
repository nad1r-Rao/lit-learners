import 'package:sqflite/sqflite.dart' show databaseFactory;
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

/// Web database factory setup.
///
/// sqflite has no native web implementation, so the local cache is backed by
/// the sqlite3 WASM build running in a shared web worker instead.
Future<void> configureDatabaseFactory() async {
  databaseFactory = databaseFactoryFfiWeb;
}
