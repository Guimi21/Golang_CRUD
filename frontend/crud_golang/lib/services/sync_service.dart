import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/usuario.dart';
import 'local_storage_service.dart';
import '../config/config.dart';

class SyncService {
  final LocalStorageService _localService = LocalStorageService();

  /// Sincroniza usuarios locales con el servidor
  Future<bool> syncUsuarios() async {
    bool success = true;

    try {
      // 1️⃣ Eliminar usuarios marcados localmente (-1)
      final usuariosEliminados = (await _localService.getUsuarios())
          .where((u) => u.sincronizado == -1)
          .toList();

      for (var u in usuariosEliminados) {
        try {
          if (u.id != null) {
            final response = await http.delete(
              Uri.parse('$apiBaseUrl/usuarios/${u.id}'),
            );
            if (response.statusCode == 200 || response.statusCode == 204) {
              await _localService.deleteUsuario(u.id!);
            } else {
              print('❌ Error eliminando usuario ${u.id} en servidor: ${response.statusCode}');
              success = false;
            }
          } else {
            // Usuario sin ID (creado offline y luego eliminado sin sincronizar)
            await _localService.deleteUsuario(u.id!);
          }
        } catch (e) {
          print('❌ Error eliminando usuario ${u.id} en servidor: $e');
          success = false;
        }
      }

      // 2️⃣ Obtener usuarios pendientes (sincronizado != 1)
      final usuariosPendientes = await _localService.getUsuariosNoSincronizados();

      // 3️⃣ Obtener lista actual de usuarios del servidor
      final remoteUsuarios = await _fetchRemoteUsuarios();

      // 4️⃣ Subir cambios locales (crear/actualizar)
      for (var local in usuariosPendientes) {
        try {
          if (local.id != null && local.id != 0) {
            // Usuario existente → buscar si está en remoto
            final remote = remoteUsuarios.firstWhere(
                  (r) => r.id == local.id,
              orElse: () => Usuario(id: 0, nombre: '', correo: '', edad: 0),
            );

            if (remote.id != 0) {
              // Existe → actualizar si hay diferencias
              if (_isDifferent(local, remote)) {
                await _updateUsuarioBackend(local);
              } else {
                local.sincronizado = 1;
                await _localService.updateUsuario(local);
              }
            } else {
              // No existe en remoto → crearlo
              await _createUsuarioBackend(local);
            }
          } else {
            // Usuario nuevo creado offline
            await _createUsuarioBackend(local);
          }
        } catch (e) {
          print('❌ Error sincronizando usuario ${local.nombre}: $e');
          success = false;
        }
      }

      // 5️⃣ Descargar lista remota actualizada
      final listaServidor = await _fetchRemoteUsuarios();

      // 6️⃣ Limpiar base local y reemplazar con datos actualizados
      await _localService.clearUsuarios();
      for (var remote in listaServidor) {
        remote.sincronizado = 1;
        await _localService.insertUsuario(remote);
      }

    } catch (e) {
      print('⚠️ Error general de sincronización: $e');
      success = false;
    }

    return success;
  }

  /// Obtiene usuarios del servidor
  Future<List<Usuario>> _fetchRemoteUsuarios() async {
    try {
      final response = await http.get(Uri.parse('$apiBaseUrl/usuarios'));
      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        return data.map((json) => Usuario.fromJson(json)).toList();
      } else {
        print('⚠️ Error obteniendo usuarios remotos: ${response.statusCode}');
      }
    } catch (e) {
      print('⚠️ Error obteniendo usuarios remotos: $e');
    }
    return [];
  }

  /// Crear un usuario en el backend
  Future<void> _createUsuarioBackend(Usuario u) async {
    try {
      final response = await http.post(
        Uri.parse('$apiBaseUrl/usuarios'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(u.toJson()),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final created = Usuario.fromJson(jsonDecode(response.body));
        u.id = created.id;
        u.sincronizado = 1;
        await _localService.updateUsuario(u);
      } else {
        print('❌ Error creando usuario en servidor: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error creando usuario en servidor: $e');
    }
  }

  /// Actualizar un usuario existente en el backend
  Future<void> _updateUsuarioBackend(Usuario u) async {
    try {
      final response = await http.put(
        Uri.parse('$apiBaseUrl/usuarios/${u.id}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(u.toJson()),
      );

      if (response.statusCode == 200) {
        u.sincronizado = 1;
        await _localService.updateUsuario(u);
      } else {
        print('❌ Error actualizando usuario ${u.id} en servidor: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error actualizando usuario ${u.id} en servidor: $e');
    }
  }

  /// Compara campos relevantes para detectar diferencias
  bool _isDifferent(Usuario local, Usuario remote) {
    return local.nombre != remote.nombre ||
        local.correo != remote.correo ||
        local.edad != remote.edad;
  }
}
