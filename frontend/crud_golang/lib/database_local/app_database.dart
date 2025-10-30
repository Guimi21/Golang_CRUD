import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class AppDatabase {
  static final AppDatabase _instance = AppDatabase._internal();
  factory AppDatabase() => _instance;
  AppDatabase._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('usuarios_local.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);
    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE usuarios (
            id INTEGER PRIMARY KEY, 
            nombre TEXT NOT NULL,
            correo TEXT NOT NULL,
            edad INTEGER NOT NULL,
            sincronizado INTEGER NOT NULL DEFAULT 0
          )
        ''');
      },
    );
  }

  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
    }
  }
}
