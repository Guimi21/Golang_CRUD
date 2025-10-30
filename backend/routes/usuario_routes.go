package routes

import (
	"github.com/gin-gonic/gin"
	"github.com/Guimi21/Golang_CRUD/controllers"
	"github.com/Guimi21/Golang_CRUD/repositories"
)

func UsuarioRoutes(router *gin.Engine) {
	// 1️⃣ Crear instancia del repositorio
	repo := repositories.NewUsuarioRepositoryGorm()

	// 2️⃣ Crear instancia del controlador con el repositorio
	ctrl := controllers.NewUsuarioController(repo)

	// 3️⃣ Definir rutas
	router.GET("/usuarios", ctrl.GetUsuarios)
	router.GET("/usuarios/:id", ctrl.GetUsuario)
	router.POST("/usuarios", ctrl.CreateUsuario)
	router.PUT("/usuarios/:id", ctrl.UpdateUsuario)
	router.DELETE("/usuarios/:id", ctrl.DeleteUsuario)
}
