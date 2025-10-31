import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:sqflite/sqflite.dart';
import 'package:sembast/sembast.dart' as sembast;
import 'package:sembast_web/sembast_web.dart' as sembast_web;

import '../models/usuario.dart';
import '../database_local/app_database.dart';

class LocalStorageService {
  // --- SINGLETON ---
  // Solo se crea una instancia global del servicio para todo el proyecto.
  static final LocalStorageService _instance = LocalStorageService._internal();
  factory LocalStorageService() => _instance;
  LocalStorageService._internal();

  // ============================================================
  //            CONFIGURACIÓN PARA WEB (SEMBAST)
  // ============================================================

  // Define una "store" (algo parecido a una tabla en SQLite)
  final _store = sembast.intMapStoreFactory.store('usuarios');

  // Fábrica y base de datos para sembast
  sembast.DatabaseFactory? _sembastFactory;
  sembast.Database? _sembastDb;

  // Inicializa la base de datos en el navegador
  Future<void> _initWebDb() async {
    if (_sembastDb != null) return; // Si ya está abierta, no la vuelve a abrir

    // Usa la implementación de sembast para web (IndexedDB)
    _sembastFactory ??= sembast_web.databaseFactoryWeb;

    // Abre o crea la base de datos local en el navegador
    _sembastDb = await _sembastFactory!.openDatabase('usuarios_web.db');
  }

  // ============================================================
  //            CONFIGURACIÓN PARA ANDROID / iOS (SQLite)
  // ============================================================

  // Usa AppDatabase() para obtener el objeto Database de SQLite
  Future<Database> get database async => await AppDatabase().database;

  // ============================================================
  //            OBTENER TODOS LOS USUARIOS
  // ============================================================
  Future<List<Usuario>> getUsuarios() async {
    if (kIsWeb) {
      // --- Web ---
      await _initWebDb();
      final records = await _store.find(_sembastDb!);
      // Convierte cada registro JSON a un objeto Usuario
      return records.map((e) => Usuario.fromJson(e.value)).toList();
    } else {
      // --- Android/iOS ---
      final db = await database;
      final result = await db.query('usuarios');
      return result.map((json) => Usuario.fromJson(json)).toList();
    }
  }

  // ============================================================
  //      OBTENER USUARIOS NO SINCRONIZADOS (sincronizado = 0)
  // ============================================================
  Future<List<Usuario>> getUsuariosNoSincronizados() async {
    if (kIsWeb) {
      await _initWebDb();
      // Filtro: solo registros donde 'sincronizado' = 0
      final finder = sembast.Finder(filter: sembast.Filter.equals('sincronizado', 0));
      final records = await _store.find(_sembastDb!, finder: finder);
      return records.map((e) => Usuario.fromJson(e.value)).toList();
    } else {
      final db = await database;
      final result = await db.query('usuarios', where: 'sincronizado = 0');
      return result.map((json) => Usuario.fromJson(json)).toList();
    }
  }

  // ============================================================
  //            BUSCAR USUARIO POR ID
  // ============================================================
  Future<Usuario?> getUsuarioById(int id) async {
    if (kIsWeb) {
      await _initWebDb();
      final finder = sembast.Finder(filter: sembast.Filter.equals('id', id));
      final record = await _store.findFirst(_sembastDb!, finder: finder);
      // Devuelve null si no existe
      return record != null ? Usuario.fromJson(record.value) : null;
    } else {
      final db = await database;
      final result = await db.query('usuarios', where: 'id = ?', whereArgs: [id]);
      return result.isNotEmpty ? Usuario.fromJson(result.first) : null;
    }
  }

  // ============================================================
  //            INSERTAR NUEVO USUARIO
  // ============================================================
  Future<void> insertUsuario(Usuario u) async {
    if (kIsWeb) {
      await _initWebDb();
      // Inserta un registro nuevo en Sembast
      await _store.add(_sembastDb!, u.toJson());
    } else {
      final db = await database;
      // Inserta o reemplaza si el ID ya existe
      await db.insert('usuarios', u.toJson(), conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  // ============================================================
  //            ACTUALIZAR USUARIO EXISTENTE
  // ============================================================
  Future<void> updateUsuario(Usuario u) async {
    if (kIsWeb) {
      await _initWebDb();
      // Encuentra el usuario por ID y lo actualiza
      final finder = sembast.Finder(filter: sembast.Filter.equals('id', u.id));
      await _store.update(_sembastDb!, u.toJson(), finder: finder);
    } else {
      final db = await database;
      await db.update('usuarios', u.toJson(), where: 'id = ?', whereArgs: [u.id]);
    }
  }

  // ============================================================
  //            ELIMINAR USUARIO POR ID
  // ============================================================
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

  // ============================================================
  //            ELIMINAR TODOS LOS USUARIOS
  // ============================================================
  Future<void> clearUsuarios() async {
    if (kIsWeb) {
      await _initWebDb();
      // Borra todos los registros del store
      await _store.delete(_sembastDb!);
    } else {
      final db = await database;
      await db.delete('usuarios');
    }
  }

  // ============================================================
  //            LIMPIAR BASE COMPLETA (equivalente a clearUsuarios)
  // ============================================================
  Future<void> limpiarBase() async {
    if (kIsWeb) {
      await _initWebDb();
      await _store.delete(_sembastDb!);
    } else {
      final db = await database;
      await db.delete('usuarios');
    }
  }
}
