import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/usuario.dart';
import 'local_storage_service.dart';
import '../config/config.dart';

/// Servicio encargado de sincronizar los datos de usuarios
/// entre la base de datos local y el servidor remoto.
class SyncService {
  final LocalStorageService _localService = LocalStorageService();

  /// 🔄 Sincroniza usuarios locales con el servidor
  ///
  /// Este proceso incluye:
  /// 1️⃣ Eliminar usuarios marcados para eliminación local.
  /// 2️⃣ Subir usuarios nuevos o modificados.
  /// 3️⃣ Descargar la lista más reciente del servidor.
  /// 4️⃣ Reemplazar los datos locales con la versión actualizada.
  ///
  /// Retorna `true` si la sincronización fue exitosa, `false` en caso contrario.
  Future<bool> syncUsuarios() async {
    bool success = true; // Indica si toda la sincronización fue exitosa

    try {
      // 1️⃣ ELIMINAR USUARIOS MARCADOS LOCALMENTE COMO ELIMINADOS (-1)
      final usuariosEliminados = (await _localService.getUsuarios())
          .where((u) => u.sincronizado == -1)
          .toList();

      for (var u in usuariosEliminados) {
        try {
          if (u.id != null) {
            // Si el usuario tiene un ID remoto → eliminar también en el servidor
            final response = await http.delete(
              Uri.parse('$apiBaseUrl/usuarios/${u.id}'),
            );

            // Si se eliminó correctamente en el servidor
            if (response.statusCode == 200 || response.statusCode == 204) {
              await _localService.deleteUsuario(u.id!);
            } else {
              // Si ocurre un error HTTP
              print('❌ Error eliminando usuario ${u.id} en servidor: ${response.statusCode}');
              success = false;
            }
          } else {
            // Si no tiene ID → se creó offline y se eliminó antes de sincronizar
            await _localService.deleteUsuario(u.id!);
          }
        } catch (e) {
          print('❌ Error eliminando usuario ${u.id} en servidor: $e');
          success = false;
        }
      }

      // 2️⃣ OBTENER USUARIOS PENDIENTES DE SINCRONIZAR (sincronizado != 1)
      final usuariosPendientes = await _localService.getUsuariosNoSincronizados();

      // 3️⃣ DESCARGAR LA LISTA ACTUAL DE USUARIOS DEL SERVIDOR
      final remoteUsuarios = await _fetchRemoteUsuarios();

      // 4️⃣ SUBIR CAMBIOS LOCALES AL SERVIDOR (crear o actualizar)
      for (var local in usuariosPendientes) {
        try {
          if (local.id != null && local.id != 0) {
            // Si el usuario tiene un ID → verificar si existe en el servidor
            final remote = remoteUsuarios.firstWhere(
                  (r) => r.id == local.id,
              orElse: () => Usuario(id: 0, nombre: '', correo: '', edad: 0),
            );

            if (remote.id != 0) {
              // Existe en remoto → verificar si los datos son diferentes
              if (_isDifferent(local, remote)) {
                // Si hay diferencias → actualizar en el servidor
                await _updateUsuarioBackend(local);
              } else {
                // Si son iguales → marcar como sincronizado
                local.sincronizado = 1;
                await _localService.updateUsuario(local);
              }
            } else {
              // No existe en el servidor → crearlo (posible desincronización previa)
              await _createUsuarioBackend(local);
            }
          } else {
            // Usuario nuevo sin ID (creado offline)
            await _createUsuarioBackend(local);
          }
        } catch (e) {
          print('❌ Error sincronizando usuario ${local.nombre}: $e');
          success = false;
        }
      }

      // 5️⃣ DESCARGAR LA LISTA REMOTA ACTUALIZADA TRAS LA SINCRONIZACIÓN
      final listaServidor = await _fetchRemoteUsuarios();

      // 6️⃣ REEMPLAZAR COMPLETAMENTE LA BASE LOCAL CON LOS DATOS DEL SERVIDOR
      await _localService.clearUsuarios();
      for (var remote in listaServidor) {
        remote.sincronizado = 1; // Marcar todos como sincronizados
        await _localService.insertUsuario(remote);
      }

    } catch (e) {
      // Captura de cualquier error inesperado
      print('⚠️ Error general de sincronización: $e');
      success = false;
    }

    return success;
  }

  /// 🌐 Obtiene la lista completa de usuarios del servidor
  ///
  /// Retorna una lista de objetos `Usuario` si la conexión es exitosa,
  /// o una lista vacía si ocurre un error o falla la conexión.
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

  /// 📤 Crea un usuario en el servidor a partir de datos locales
  Future<void> _createUsuarioBackend(Usuario u) async {
    try {
      final response = await http.post(
        Uri.parse('$apiBaseUrl/usuarios'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(u.toJson()),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        // Si se creó correctamente → actualizar el usuario local con el nuevo ID
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

  /// 🔁 Actualiza un usuario existente en el servidor
  Future<void> _updateUsuarioBackend(Usuario u) async {
    try {
      final response = await http.put(
        Uri.parse('$apiBaseUrl/usuarios/${u.id}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(u.toJson()),
      );

      if (response.statusCode == 200) {
        // Si se actualizó correctamente → marcar como sincronizado
        u.sincronizado = 1;
        await _localService.updateUsuario(u);
      } else {
        print('❌ Error actualizando usuario ${u.id} en servidor: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error actualizando usuario ${u.id} en servidor: $e');
    }
  }

  /// 🧩 Compara dos usuarios (local vs remoto) para detectar diferencias
  ///
  /// Retorna `true` si hay cambios en nombre, correo o edad.
  bool _isDifferent(Usuario local, Usuario remote) {
    return local.nombre != remote.nombre ||
        local.correo != remote.correo ||
        local.edad != remote.edad;
  }
}
