import 'package:sqflite/sqflite.dart';
import '../models/usuario.dart';
import '../database_local/app_database.dart'; // tu clase que ya creó la DB

class LocalStorageService {
  static final LocalStorageService _instance = LocalStorageService._internal();
  factory LocalStorageService() => _instance;
  LocalStorageService._internal();

  Future<Database> get _db async => await AppDatabase().database;

  Future<List<Usuario>> getUsuarios() async {
    final db = await _db;
    final result = await db.query('usuarios');
    return result.map((json) => Usuario.fromJson(json)).toList();
  }

  Future<List<Usuario>> getUsuariosNoSincronizados() async {
    final db = await _db;
    final result = await db.query('usuarios', where: 'sincronizado = 0');
    return result.map((json) => Usuario.fromJson(json)).toList();
  }

  Future<Usuario?> getUsuarioById(int id) async {
    final db = await _db;
    final result = await db.query('usuarios', where: 'id = ?', whereArgs: [id]);
    if (result.isNotEmpty) return Usuario.fromJson(result.first);
    return null;
  }

  Future<void> insertUsuario(Usuario u) async {
    final db = await _db;
    await db.insert(
      'usuarios',
      u.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateUsuario(Usuario u) async {
    final db = await _db;
    await db.update('usuarios', u.toJson(), where: 'id = ?', whereArgs: [u.id]);
  }

  Future<void> deleteUsuario(int id) async {
    final db = await _db;
    await db.delete('usuarios', where: 'id = ?', whereArgs: [id]);
  }
}
