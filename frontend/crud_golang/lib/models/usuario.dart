// Clase que representa un Usuario dentro de la aplicación
// Se usa tanto para manejar datos locales (SQLite) como datos del servidor (API REST)
class Usuario {
  int? id;        // ID del usuario (puede ser nulo si aún no se ha sincronizado con el servidor)
  String nombre;  // Nombre del usuario
  String correo;  // Correo electrónico del usuario
  int edad;       // Edad del usuario
  int sincronizado; // Estado de sincronización: 0 = no sincronizado (solo local), 1 = sincronizado (en servidor)

  // Constructor principal de la clase
  Usuario({
    this.id,                          // opcional, porque un usuario nuevo aún no tiene ID del servidor
    required this.nombre,             // nombre obligatorio
    required this.correo,             // correo obligatorio
    required this.edad,               // edad obligatoria
    this.sincronizado = 0,            // por defecto 0, porque los nuevos registros se crean localmente
  });

  // Fábrica para crear una instancia de Usuario desde un JSON (por ejemplo, desde la API REST)
  factory Usuario.fromJson(Map<String, dynamic> json) => Usuario(
    id: json['id'],                   // Asigna el id directamente
    nombre: json['nombre'] ?? '',     // Si 'nombre' no viene, asigna una cadena vacía
    correo: json['correo'] ?? '',     // Si 'correo' no viene, asigna una cadena vacía
    // Verifica el tipo del campo 'edad' porque puede venir como int o string
    edad: json['edad'] is int
        ? json['edad']
        : int.tryParse(json['edad']?.toString() ?? '0') ?? 0,
    // Si viene del servidor, asumimos que ya está sincronizado
    sincronizado: json['sincronizado'] ?? 1,
  );

  // Convierte la instancia actual de Usuario en un mapa JSON (para enviar al servidor o guardar localmente)
  Map<String, dynamic> toJson() => {
    'id': id,
    'nombre': nombre,
    'correo': correo,
    'edad': edad,
    'sincronizado': sincronizado,
  };

  // Fábrica para crear un Usuario desde un Map (por ejemplo, desde SQLite)
  factory Usuario.fromMap(Map<String, dynamic> map) => Usuario(
    id: map['id'],                     // ID que viene de la base de datos local
    nombre: map['nombre'] ?? '',       // Si no hay nombre, usar vacío
    correo: map['correo'] ?? '',       // Si no hay correo, usar vacío
    edad: map['edad'] ?? 0,            // Si no hay edad, usar 0
    sincronizado: map['sincronizado'] ?? 0, // Por defecto, se asume no sincronizado (local)
  );

  // Convierte el objeto en un mapa (igual que toJson, útil para guardar en SQLite)
  Map<String, dynamic> toMap() => toJson();
}
