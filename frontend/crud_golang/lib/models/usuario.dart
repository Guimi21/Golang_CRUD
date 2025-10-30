class Usuario {
  int? id;        // ID del servidor
  String nombre;
  String correo;
  int edad;
  int sincronizado; // 0 = no sincronizado, 1 = sincronizado

  Usuario({
    this.id,
    required this.nombre,
    required this.correo,
    required this.edad,
    this.sincronizado = 0,
  });

  factory Usuario.fromJson(Map<String, dynamic> json) => Usuario(
    id: json['id'],
    nombre: json['nombre'],
    correo: json['correo'],
    edad: json['edad'] ?? 0,
    sincronizado: json['sincronizado'] ?? 1, // asumimos que del servidor siempre viene sincronizado
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'nombre': nombre,
    'correo': correo,
    'edad': edad,
    'sincronizado': sincronizado,
  };

  Map<String, dynamic> toMap() => {
    'id': id,
    'nombre': nombre,
    'correo': correo,
    'edad': edad,
    'sincronizado': sincronizado,
  };

  factory Usuario.fromMap(Map<String, dynamic> map) => Usuario(
    id: map['id'],
    nombre: map['nombre'],
    correo: map['correo'],
    edad: map['edad'],
    sincronizado: map['sincronizado'] ?? 0,
  );
}
