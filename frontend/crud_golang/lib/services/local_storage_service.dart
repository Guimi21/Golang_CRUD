import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:sqflite/sqflite.dart';
import 'package:sembast/sembast.dart' as sembast;
import 'package:sembast_web/sembast_web.dart' as sembast_web;

import '../models/usuario.dart';
import '../database_local/app_database.dart';

class LocalStorageService {
  static final LocalStorageService _instance = LocalStorageService._internal();
  factory LocalStorageService() => _instance;
  LocalStorageService._internal();

  // --- Configuración Web ---
  final _store = sembast.intMapStoreFactory.store('usuarios');
  sembast.DatabaseFactory? _sembastFactory;
  sembast.Database? _sembastDb;

  Future<void> _initWebDb() async {
    if (_sembastDb != null) return;
    _sembastFactory ??= sembast_web.databaseFactoryWeb;
    _sembastDb = await _sembastFactory!.openDatabase('usuarios_web.db');
  }

  // --- Configuración SQLite ---
  Future<Database> get database async => await AppDatabase().database; // ✅ getter público

  // --- Obtener todos los usuarios ---
  Future<List<Usuario>> getUsuarios() async {
    if (kIsWeb) {
      await _initWebDb();
      final records = await _store.find(_sembastDb!);
      return records.map((e) => Usuario.fromJson(e.value)).toList();
    } else {
      final db = await database; // ahora sí existe
      final result = await db.query('usuarios');
      return result.map((json) => Usuario.fromJson(json)).toList();
    }
  }

  Future<List<Usuario>> getUsuariosNoSincronizados() async {
    if (kIsWeb) {
      await _initWebDb();
      final finder = sembast.Finder(filter: sembast.Filter.equals('sincronizado', 0));
      final records = await _store.find(_sembastDb!, finder: finder);
      return records.map((e) => Usuario.fromJson(e.value)).toList();
    } else {
      final db = await database;
      final result = await db.query('usuarios', where: 'sincronizado = 0');
      return result.map((json) => Usuario.fromJson(json)).toList();
    }
  }

  Future<Usuario?> getUsuarioById(int id) async {
    if (kIsWeb) {
      await _initWebDb();
      final finder = sembast.Finder(filter: sembast.Filter.equals('id', id));
      final record = await _store.findFirst(_sembastDb!, finder: finder);
      return record != null ? Usuario.fromJson(record.value) : null;
    } else {
      final db = await database;
      final result = await db.query('usuarios', where: 'id = ?', whereArgs: [id]);
      return result.isNotEmpty ? Usuario.fromJson(result.first) : null;
    }
  }

  Future<void> insertUsuario(Usuario u) async {
    if (kIsWeb) {
      await _initWebDb();
      await _store.add(_sembastDb!, u.toJson());
    } else {
      final db = await database;
      await db.insert('usuarios', u.toJson(), conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  Future<void> updateUsuario(Usuario u) async {
    if (kIsWeb) {
      await _initWebDb();
      final finder = sembast.Finder(filter: sembast.Filter.equals('id', u.id));
      await _store.update(_sembastDb!, u.toJson(), finder: finder);
    } else {
      final db = await database;
      await db.update('usuarios', u.toJson(), where: 'id = ?', whereArgs: [u.id]);
    }
  }

  Future<void> deleteUsuario(int id) async {
    if (kIsWeb) {
      await _initWebDb();
      final finder = sembast.Finder(filter: sembast.Filter.equals('id', id));
      await _store.delete(_sembastDb!, finder: finder);
    } else {
      final db = await database;
      await db.delete('usuarios', where: 'id = ?', whereArgs: [id]);
    }
  }

  Future<void> clearUsuarios() async {
    if (kIsWeb) {
      await _initWebDb();
      await _store.delete(_sembastDb!);
    } else {
      final db = await database; // ✅ corregido
      await db.delete('usuarios');
    }
  }

  Future<void> limpiarBase() async {
    if (kIsWeb) {
      await _initWebDb();
      await _store.delete(_sembastDb!);
    } else {
      final db = await database; // ✅ corregido
      await db.delete('usuarios');
    }
  }
}
