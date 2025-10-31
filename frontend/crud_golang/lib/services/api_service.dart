// Importa la librería para convertir objetos a JSON y viceversa
import 'dart:convert';
// Importa el paquete HTTP para hacer peticiones al servidor (GET, POST, PUT, DELETE)
import 'package:http/http.dart' as http;
// Importa el modelo Usuario para convertir los datos JSON en objetos de Dart
import '../models/usuario.dart';
// Importa la configuración base de la API (por ejemplo, la URL base del servidor)
import '../config/config.dart';

// Esta clase maneja todas las operaciones HTTP (API REST) con el backend.
// Contiene métodos estáticos para listar, obtener, crear, actualizar y eliminar usuarios.
class ApiService {

  // 📥 OBTENER TODOS LOS USUARIOS (GET /usuarios)
  static Future<List<Usuario>> getUsuarios() async {
    // Realiza una solicitud GET al endpoint /usuarios
    final response = await http.get(Uri.parse('$apiBaseUrl/usuarios'));

    // Si la respuesta del servidor es exitosa (200 OK)
    if (response.statusCode == 200) {
      // Decodifica el cuerpo de la respuesta JSON en una lista dinámica
      Iterable jsonResponse = jsonDecode(response.body);

      // Convierte cada elemento JSON en un objeto Usuario
      return jsonResponse.map((u) => Usuario.fromJson(u)).toList();
    } else {
      // Si ocurre un error, lanza una excepción
      throw Exception('Error al obtener usuarios');
    }
  }

  // 📥 OBTENER UN USUARIO POR ID (GET /usuarios/{id})
  static Future<Usuario?> getUsuarioById(int id) async {
    // Hace una solicitud GET a la API con el ID proporcionado
    final response = await http.get(Uri.parse('$apiBaseUrl/usuarios/$id'));

    if (response.statusCode == 200) {
      // Si la respuesta es correcta, convierte el JSON en un objeto Usuario
      return Usuario.fromJson(jsonDecode(response.body));
    } else if (response.statusCode == 404) {
      // Si no se encuentra el usuario, devuelve null (no lanza error)
      return null;
    } else {
      // Para otros códigos de error, lanza una excepción
      throw Exception('Error al obtener usuario por ID');
    }
  }

  // 📤 CREAR UN NUEVO USUARIO (POST /usuarios)
  static Future<Usuario> createUsuario(Usuario usuario) async {
    // Envía una solicitud POST con los datos del usuario en formato JSON
    final response = await http.post(
      Uri.parse('$apiBaseUrl/usuarios'),
      headers: {'Content-Type': 'application/json'}, // Encabezado indicando que el cuerpo es JSON
      body: jsonEncode(usuario.toJson()),             // Convierte el objeto Usuario a JSON
    );

    // Si el servidor responde con 201 (creado) o 200 (OK)
    if (response.statusCode == 201 || response.statusCode == 200) {
      // Convierte la respuesta en un nuevo objeto Usuario
      return Usuario.fromJson(jsonDecode(response.body));
    } else {
      // Si ocurre un error, lanza una excepción
      throw Exception('Error al crear usuario');
    }
  }

  // ✏️ ACTUALIZAR UN USUARIO EXISTENTE (PUT /usuarios/{id})
  static Future<void> updateUsuario(int id, Usuario usuario) async {
    // Envía una solicitud PUT con el ID y los datos actualizados del usuario
    final response = await http.put(
      Uri.parse('$apiBaseUrl/usuarios/$id'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(usuario.toJson()),
    );

    // Si la respuesta no es 200, significa que algo falló
    if (response.statusCode != 200) {
      throw Exception('Error al actualizar usuario');
    }
  }

  // 🗑️ ELIMINAR UN USUARIO (DELETE /usuarios/{id})
  static Future<void> deleteUsuario(int id) async {
    // Realiza una solicitud DELETE al endpoint del usuario
    final response = await http.delete(Uri.parse('$apiBaseUrl/usuarios/$id'));

    // Si el código de estado no es 200, hubo un error
    if (response.statusCode != 200) {
      throw Exception('Error al eliminar usuario');
    }
  }
}
