package main

import (
	"github.com/gin-gonic/gin"
	"github.com/gin-contrib/cors" // << importar CORS
	"github.com/Guimi21/Golang_CRUD/config"
	"github.com/Guimi21/Golang_CRUD/routes"
	"github.com/Guimi21/Golang_CRUD/models"
)

func main() {
	// Conectar a la base de datos
	config.ConnectDB()

	// Crear tablas automáticamente
	config.DB.AutoMigrate(&models.Usuario{})

	// Crear router Gin
	router := gin.Default()

	// ----------------- Configurar CORS -----------------
	router.Use(cors.New(cors.Config{
		AllowOrigins:     []string{"*"}, // Permitir todas las URLs, o poner la de tu Flutter
		AllowMethods:     []string{"GET", "POST", "PUT", "DELETE"},
		AllowHeaders:     []string{"Origin", "Content-Type"},
		AllowCredentials: true,
	}))
	// ------------------------------------------------------

	// Registrar rutas
	routes.UsuarioRoutes(router)

	// Iniciar servidor
	router.Run("0.0.0.0:8081")

}
