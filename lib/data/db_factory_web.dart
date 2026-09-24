import 'package:sembast_web/sembast_web.dart';

/// Nel browser: IndexedDB, cioè una memoria del telefono riservata a questa app web.
DatabaseFactory get appDatabaseFactory => databaseFactoryWeb;
