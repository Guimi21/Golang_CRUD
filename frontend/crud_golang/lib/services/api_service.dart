import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/usuario.dart';
import '../config/config.dart';

class ApiService {
  static Future<List<Usuario>> getUsuarios() async {
    final response = await http.get(Uri.parse('$apiBaseUrl/usuarios'));
    if (response.statusCode == 200) {
      Iterable jsonResponse = jsonDecode(response.body);
      return jsonResponse.map((u) => Usuario.fromJson(u)).toList();
    } else {
      throw Exception('Error al obtener usuarios');
    }
  }

  static Future<Usuario?> getUsuarioById(int id) async {
    final response = await http.get(Uri.parse('$apiBaseUrl/usuarios/$id'));
    if (response.statusCode == 200) {
      return Usuario.fromJson(jsonDecode(response.body));
    } else if (response.statusCode == 404) {
      return null;
    } else {
      throw Exception('Error al obtener usuario por ID');
    }
  }

  static Future<Usuario> createUsuario(Usuario usuario) async {
    final response = await http.post(
      Uri.parse('$apiBaseUrl/usuarios'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(usuario.toJson()),
    );

    if (response.statusCode == 201 || response.statusCode == 200) {
      return Usuario.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Error al crear usuario');
    }
  }

  static Future<void> updateUsuario(int id, Usuario usuario) async {
    final response = await http.put(
      Uri.parse('$apiBaseUrl/usuarios/$id'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(usuario.toJson()),
    );

    if (response.statusCode != 200) {
      throw Exception('Error al actualizar usuario');
    }
  }

  static Future<void> deleteUsuario(int id) async {
    final response = await http.delete(Uri.parse('$apiBaseUrl/usuarios/$id'));
    if (response.statusCode != 200) {
      throw Exception('Error al eliminar usuario');
    }
  }
}
