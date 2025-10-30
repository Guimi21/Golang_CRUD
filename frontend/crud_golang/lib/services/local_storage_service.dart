import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/usuario.dart';

class LocalStorageService {
  static final LocalStorageService _instance = LocalStorageService._internal();
  factory LocalStorageService() => _instance;
  LocalStorageService._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    final dbPath = await getDatabasesPath();
    _database = await openDatabase(
      join(dbPath, 'usuarios_local.db'),
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE usuarios(
            id INTEGER PRIMARY KEY, 
            nombre TEXT NOT NULL,
            correo TEXT NOT NULL,
            edad INTEGER NOT NULL,
            sincronizado INTEGER NOT NULL DEFAULT 0
          )
        ''');
      },
    );
    return _database!;
  }

  Future<List<Usuario>> getUsuarios() async {
    final db = await database;
    final result = await db.query('usuarios');
    return result.map((json) => Usuario.fromJson(json)).toList();
  }

  Future<List<Usuario>> getUsuariosNoSincronizados() async {
    final db = await database;
    final result = await db.query('usuarios', where: 'sincronizado = 0');
    return result.map((json) => Usuario.fromJson(json)).toList();
  }

  Future<Usuario?> getUsuarioById(int id) async {
    final db = await database;
    final result = await db.query('usuarios', where: 'id = ?', whereArgs: [id]);
    if (result.isNotEmpty) return Usuario.fromJson(result.first);
    return null;
  }

  Future<void> insertUsuario(Usuario u) async {
    final db = await database;
    await db.insert('usuarios', u.toJson(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateUsuario(Usuario u) async {
    final db = await database;
    await db.update('usuarios', u.toJson(), where: 'id = ?', whereArgs: [u.id]);
  }

  Future<void> deleteUsuario(int id) async {
    final db = await database;
    await db.delete('usuarios', where: 'id = ?', whereArgs: [id]);
  }
}
