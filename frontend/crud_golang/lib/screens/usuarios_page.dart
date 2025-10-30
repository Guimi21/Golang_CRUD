import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
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
    _verificarConexionReal();

    Connectivity().onConnectivityChanged.listen((_) async {
      await _verificarConexionReal();
      _resetearSincronizacionAutomatica();
    });

    listarUsuarios();
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

  Future<void> _verificarConexionReal() async {
    try {
      var result = await Connectivity().checkConnectivity();
      if (result == ConnectivityResult.none) {
        setState(() {
          modoOffline = true;
          estadoConexion = "Sin conexión";
        });
        return;
      }

      final socket = await Socket.connect(
        '192.168.0.111',
        8081,
        timeout: const Duration(seconds: 2),
      );
      socket.destroy();

      setState(() {
        modoOffline = false;
        estadoConexion = "Conectado";
      });

      listarUsuarios();
    } catch (_) {
      setState(() {
        modoOffline = true;
        estadoConexion = "Servidor no disponible";
      });
    }
  }

  Future<void> listarUsuarios() async {
    try {
      final data = await _localService.getUsuarios();
      setState(() => usuarios = data);
      _mostrarMensaje('Lista cargada', isError: false);
    }
    catch (e)
    { _mostrarMensaje('Error al listar usuarios: $e', isError: true);
    }
  }

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

      // 1️⃣ Intentar buscar en el servidor primero
      try {
        usuario = await ApiService.getUsuarioById(id);

        if (usuario != null) {
          _mostrarMensaje('Usuario encontrado en el servidor', isError: false);
          // Guardar o actualizar en la base local
          await _localService.insertUsuario(usuario);
        } else {
          _mostrarMensaje('Usuario no encontrado en el servidor', isError: true);
        }
      } catch (e) {
        // Error de conexión u otro fallo de API
        _mostrarMensaje('No se pudo conectar al servidor. Buscando localmente...', isError: true);
      }

      // 2️⃣ Si no se encontró o hubo error, buscar localmente
      if (usuario == null) {
        usuario = await _localService.getUsuarioById(id);
        if (usuario != null) {
          _mostrarMensaje('Usuario encontrado localmente', isError: false);
        } else {
          _mostrarMensaje('Usuario no encontrado ni en servidor ni localmente', isError: true);
          return;
        }
      }

      // 3️⃣ Mostrar el resultado en la interfaz
      setState(() => usuarios = [usuario!]);

    } catch (e) {
      _mostrarMensaje('Error al buscar usuario: $e', isError: true);
    }
  }

  Future<void> agregarUsuario() async {
    if (nombreController.text.isEmpty ||
        correoController.text.isEmpty ||
        edadController.text.isEmpty) {
      _mostrarMensaje('Complete todos los campos', isError: true);
      return;
    }

    bool confirmar = await _confirmarAccion(
        '¿Desea agregar este usuario?');
    if (!confirmar) return;

    final usuario = Usuario(
      nombre: nombreController.text,
      correo: correoController.text,
      edad: int.parse(edadController.text),
      sincronizado: 0,
    );

    try {
      await _localService.insertUsuario(usuario);
      _mostrarMensaje('Usuario guardado localmente', isError: false);

      if (!modoOffline) {
        final u = await ApiService.createUsuario(usuario);
        await _localService.updateUsuario(u);
        _mostrarMensaje('Usuario guardado en el servidor', isError: false);

      }

      listarUsuarios();
      limpiarCampos();
    } catch (e) {
      _mostrarMensaje('Error al guardar usuario: $e', isError: true);
    }
  }

  Future<void> actualizarUsuario() async {
    if (usuarioEditando == null) {
      _mostrarMensaje('Seleccione un usuario', isError: true);
      return;
    }

    bool confirmar = await _confirmarAccion(
        '¿Desea actualizar este usuario?');
    if (!confirmar) return;

    usuarioEditando!
      ..nombre = nombreController.text
      ..correo = correoController.text
      ..edad = int.parse(edadController.text)
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

  Future<void> eliminarUsuarioOffline(Usuario u) async {
    bool confirmar = await _confirmarAccion(
        '¿Desea eliminar este usuario?');
    if (!confirmar) return;

    u.sincronizado = -1;
    await _localService.updateUsuario(u);
    _mostrarMensaje('Usuario marcado para eliminación offline', isError: false);

    if (!modoOffline) {
      await ApiService.deleteUsuario(u.id!);
      await _localService.deleteUsuario(u.id!);
      _mostrarMensaje('Usuario eliminado en el servidor', isError: false);

    }

    listarUsuarios();
  }

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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<bool> _confirmarAccion(String mensaje) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmación'),
        content: Text(mensaje),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Aceptar'),
          ),
        ],
      ),
    ) ??
        false;
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
        title: const Text('CRUD Usuarios Offline-First'),
        backgroundColor: modoOffline ? Colors.red : Colors.green,
        actions: [
          IconButton(
            icon: const Icon(Icons.sync),
            onPressed: () async {
              _mostrarMensaje('Sincronizando...', isError: false);

              try {
                await _syncService.syncUsuarios();
                // Refrescar lista **después de sincronizar**
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
                ElevatedButton(onPressed: agregarUsuario, child: const Text('Agregar')),
                ElevatedButton(onPressed: actualizarUsuario, child: const Text('Actualizar')),
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
                            const Icon(Icons.delete_forever,
                                color: Colors.orange, size: 16)
                          else if (u.sincronizado == 0)
                            const Icon(Icons.sync_problem,
                                color: Colors.orange, size: 16)
                          else
                            const Icon(Icons.check_circle,
                                color: Colors.green, size: 16),
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
                              onPressed: () => eliminarUsuarioOffline(u),
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
