import 'package:sembast/sembast_memory.dart';

/// Fuori dal browser (test) l'archivio è in memoria. Per un'app Android/iOS vera andrà
/// usato `sembast_io` in una cartella dell'app.
DatabaseFactory get appDatabaseFactory => databaseFactoryMemory;
