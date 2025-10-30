import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;

import '../models/usuario.dart';
import '../services/local_storage_service.dart';
import '../services/api_service.dart';
import '../services/sync_service.dart';

class UsuariosPage extends StatefulWidget {
  const UsuariosPage({super.key});

  @override
  State<UsuariosPage> createState() => _UsuariosPageState();
}

class _UsuariosPageState extends State<UsuariosPage> {
  List<Usuario> usuarios = [];
  Usuario? usuarioEditando;

  final idController = TextEditingController();
  final nombreController = TextEditingController();
  final correoController = TextEditingController();
  final edadController = TextEditingController();

  final LocalStorageService _localService = LocalStorageService();
  final SyncService _syncService = SyncService();

  bool modoOffline = true;
  String estadoConexion = "Desconectado";

  bool primeraSincronizacion = true;
  Timer? _autoSyncTimer;

  @override
  void initState() {
    super.initState();
    _inicializar();

    Connectivity().onConnectivityChanged.listen((_) async {
      await _verificarConexionReal();
      _resetearSincronizacionAutomatica();
    });

  }

  @override
  void dispose() {
    idController.dispose();
    nombreController.dispose();
    correoController.dispose();
    edadController.dispose();
    _autoSyncTimer?.cancel();
    super.dispose();
  }

  Future<void> _inicializar() async {
    await _verificarConexionReal(); // espera a verificar conexión
    if (!modoOffline) {
      await _syncService.syncUsuarios(); // solo sincroniza si hay conexión
    }
    await listarUsuarios();
  }
  /// Verifica si hay conexión y si el servidor está disponible
  Future<void> _verificarConexionReal() async {
    try {
      // Revisar conectividad básica
      var result = await Connectivity().checkConnectivity();
      if (result == ConnectivityResult.none) {
        setState(() {
          modoOffline = true;
          estadoConexion = "Sin conexión";
        });
        return;
      }

      // Determinar IP/host según plataforma
      String host = '192.168.0.111'; // IP del servidor en tu red local
      if (!kIsWeb) {
        host = '10.0.2.2'; // Para emulador Android
      }

      // Endpoint correcto de tu servidor
      final url = Uri.parse('http://$host:8081/usuarios');

      // Intentar conectarse al servidor
      final response = await http.get(url).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        setState(() {
          modoOffline = false;
          estadoConexion = "Conectado";
        });
        // Actualizar lista de usuarios desde servidor/local
        await listarUsuarios();
      } else {
        setState(() {
          modoOffline = true;
          estadoConexion = "Servidor no disponible";
        });
      }
    } catch (e) {
      // Captura cualquier error de conexión
      setState(() {
        modoOffline = true;
        estadoConexion = "Servidor no disponible";
      });
    }
  }


  /// Listar todos los usuarios desde almacenamiento local
  Future<void> listarUsuarios() async {
    try {
      final data = await _localService.getUsuarios();
      setState(() => usuarios = data);
    } catch (e) {
      _mostrarMensaje('Error al listar usuarios: $e', isError: true);
    }
  }

  /// Buscar usuario por ID
  Future<void> buscarUsuario() async {
    final idText = idController.text.trim();
    if (idText.isEmpty) {
      _mostrarMensaje('Ingrese un ID para buscar', isError: true);
      return;
    }

    final id = int.tryParse(idText);
    if (id == null) {
      _mostrarMensaje('ID inválido', isError: true);
      return;
    }

    try {
      Usuario? usuario;

      if (!modoOffline) {
        try {
          usuario = await ApiService.getUsuarioById(id);
          if (usuario != null) await _localService.insertUsuario(usuario);
        } catch (_) {
          _mostrarMensaje('Error con servidor, buscando localmente...', isError: true);
        }
      }

      usuario ??= await _localService.getUsuarioById(id);

      if (usuario != null) {
        setState(() => usuarios = [usuario!]);
        _mostrarMensaje('Usuario encontrado', isError: false);
      } else {
        _mostrarMensaje('Usuario no encontrado', isError: true);
      }
    } catch (e) {
      _mostrarMensaje('Error al buscar usuario: $e', isError: true);
    }
  }

  /// Agregar nuevo usuario con confirmación
  Future<void> confirmarAgregar() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar'),
        content: const Text('¿Desea guardar este usuario?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Guardar')),
        ],
      ),
    );

    if (confirm == true) {
      await agregarUsuario();
    }
  }

  Future<void> agregarUsuario() async {
    if (nombreController.text.isEmpty ||
        correoController.text.isEmpty ||
        edadController.text.isEmpty) {
      _mostrarMensaje('Complete todos los campos', isError: true);
      return;
    }

    final usuario = Usuario(
      nombre: nombreController.text,
      correo: correoController.text,
      edad: int.tryParse(edadController.text) ?? 0,
      sincronizado: 0,
    );

    try {
      await _localService.insertUsuario(usuario);

      if (!modoOffline) {
        final u = await ApiService.createUsuario(usuario);
        await _localService.updateUsuario(u);
      }

      _mostrarMensaje('Usuario agregado', isError: false);
      listarUsuarios();
      limpiarCampos();
    } catch (e) {
      _mostrarMensaje('Error al agregar usuario: $e', isError: true);
    }
  }

  /// Actualizar usuario con confirmación
  Future<void> confirmarActualizar() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar'),
        content: const Text('¿Desea actualizar este usuario?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Actualizar')),
        ],
      ),
    );

    if (confirm == true) {
      await actualizarUsuario();
    }
  }

  Future<void> actualizarUsuario() async {
    if (usuarioEditando == null) {
      _mostrarMensaje('Seleccione un usuario', isError: true);
      return;
    }

    usuarioEditando!
      ..nombre = nombreController.text
      ..correo = correoController.text
      ..edad = int.tryParse(edadController.text) ?? 0
      ..sincronizado = 0;

    try {
      await _localService.updateUsuario(usuarioEditando!);

      if (!modoOffline) {
        await ApiService.updateUsuario(usuarioEditando!.id!, usuarioEditando!);
        usuarioEditando!.sincronizado = 1;
        await _localService.updateUsuario(usuarioEditando!);
      }

      _mostrarMensaje('Usuario actualizado', isError: false);
      usuarioEditando = null;
      listarUsuarios();
      limpiarCampos();
    } catch (e) {
      _mostrarMensaje('Error al actualizar usuario: $e', isError: true);
    }
  }

  /// Confirmar eliminación
  Future<void> confirmarEliminar(Usuario u) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar eliminación'),
        content: Text('¿Desea eliminar al usuario ${u.nombre}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Eliminar')),
        ],
      ),
    );

    if (confirm == true) {
      await eliminarUsuarioOffline(u);
    }
  }

  /// Eliminar usuario (soft delete)
  Future<void> eliminarUsuarioOffline(Usuario u) async {
    u.sincronizado = -1;
    await _localService.updateUsuario(u);
    _mostrarMensaje('Usuario marcado para eliminación', isError: false);

    if (!modoOffline) {
      await ApiService.deleteUsuario(u.id!);
      await _localService.deleteUsuario(u.id!);
      _mostrarMensaje('Usuario eliminado en servidor', isError: false);
    }

    listarUsuarios();
  }

  /// Restaurar usuario eliminado
  void restaurarUsuario(Usuario u) async {
    u.sincronizado = 0;
    await _localService.updateUsuario(u);
    _mostrarMensaje('Usuario restaurado', isError: false);
    listarUsuarios();
  }

  void limpiarCampos() {
    idController.clear();
    nombreController.clear();
    correoController.clear();
    edadController.clear();
    usuarioEditando = null;
  }

  void seleccionarUsuario(Usuario u) {
    setState(() {
      usuarioEditando = u;
      idController.text = u.id?.toString() ?? '';
      nombreController.text = u.nombre;
      correoController.text = u.correo;
      edadController.text = u.edad.toString();
    });
  }

  void _mostrarMensaje(String mensaje, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _resetearSincronizacionAutomatica() {
    _autoSyncTimer?.cancel();
    if (!modoOffline && !primeraSincronizacion) {
      _autoSyncTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
        if (!modoOffline) {
          await _syncService.syncUsuarios();
          listarUsuarios();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CRUD Golang & Flutter'),
        backgroundColor: modoOffline ? Colors.red : Colors.green,
        actions: [
          IconButton(
            icon: const Icon(Icons.sync),
            onPressed: () async {
              _mostrarMensaje('Sincronizando...', isError: false);
              try {
                await _syncService.syncUsuarios();
                await listarUsuarios();
                _mostrarMensaje('Sincronización completada', isError: false);
              } catch (e) {
                _mostrarMensaje('Error al sincronizar: $e', isError: true);
              }
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Icon(
                  modoOffline ? Icons.signal_wifi_off : Icons.wifi,
                  color: modoOffline ? Colors.red : Colors.green,
                ),
                const SizedBox(width: 8),
                Text(
                  estadoConexion,
                  style: TextStyle(
                    color: modoOffline ? Colors.red : Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: idController,
              decoration: const InputDecoration(labelText: 'ID (buscar/editar)'),
              keyboardType: TextInputType.number,
            ),
            TextField(
              controller: nombreController,
              decoration: const InputDecoration(labelText: 'Nombre'),
            ),
            TextField(
              controller: correoController,
              decoration: const InputDecoration(labelText: 'Correo'),
            ),
            TextField(
              controller: edadController,
              decoration: const InputDecoration(labelText: 'Edad'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                ElevatedButton(onPressed: listarUsuarios, child: const Text('Listar')),
                ElevatedButton(onPressed: buscarUsuario, child: const Text('Buscar')),
                ElevatedButton(onPressed: confirmarAgregar, child: const Text('Agregar')),
                ElevatedButton(onPressed: confirmarActualizar, child: const Text('Actualizar')),
              ],
            ),
            const SizedBox(height: 20),
            Expanded(
              child: usuarios.isEmpty
                  ? const Center(child: Text('No hay usuarios'))
                  : ListView.builder(
                itemCount: usuarios.length,
                itemBuilder: (context, index) {
                  final u = usuarios[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 5),
                    child: ListTile(
                      title: Text(u.nombre),
                      subtitle: Text('${u.correo} | Edad: ${u.edad}'),
                      leading: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(u.id?.toString() ?? ''),
                          if (u.sincronizado == -1)
                            const Icon(Icons.delete_forever, color: Colors.orange, size: 16)
                          else if (u.sincronizado == 0)
                            const Icon(Icons.sync_problem, color: Colors.orange, size: 16)
                          else
                            const Icon(Icons.check_circle, color: Colors.green, size: 16),
                        ],
                      ),
                      trailing: Wrap(
                        spacing: 8,
                        children: [
                          if (u.sincronizado == -1)
                            IconButton(
                              icon: const Icon(Icons.restore, color: Colors.blue),
                              onPressed: () => restaurarUsuario(u),
                            )
                          else ...[
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              onPressed: () => seleccionarUsuario(u),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => confirmarEliminar(u),
                            ),
                          ]
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
