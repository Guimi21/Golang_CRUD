package controllers

import (
	"github.com/gin-gonic/gin"
	"github.com/Guimi21/Golang_CRUD/models"
	"github.com/Guimi21/Golang_CRUD/repositories"
	"net/http"
)

type UsuarioController struct {
	Repo repositories.UsuarioRepository
}

func NewUsuarioController(repo repositories.UsuarioRepository) *UsuarioController {
	return &UsuarioController{Repo: repo}
}

func (ctrl *UsuarioController) GetUsuarios(c *gin.Context) {
	usuarios, err := ctrl.Repo.FindAll()
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Error al obtener usuarios"})
		return
	}
	c.JSON(http.StatusOK, usuarios)
}

func (ctrl *UsuarioController) GetUsuario(c *gin.Context) {
	id := c.Param("id")
	usuario, err := ctrl.Repo.FindByID(id)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Usuario no encontrado"})
		return
	}
	c.JSON(http.StatusOK, usuario)
}

func (ctrl *UsuarioController) CreateUsuario(c *gin.Context) {
	var usuario models.Usuario
	if err := c.ShouldBindJSON(&usuario); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	created, err := ctrl.Repo.Create(usuario)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Error al crear usuario"})
		return
	}
	c.JSON(http.StatusCreated, created)
}

func (ctrl *UsuarioController) UpdateUsuario(c *gin.Context) {
	id := c.Param("id")
	var input models.Usuario
	if err := c.ShouldBindJSON(&input); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	updated, err := ctrl.Repo.Update(id, input)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Usuario no encontrado"})
		return
	}
	c.JSON(http.StatusOK, updated)
}

func (ctrl *UsuarioController) DeleteUsuario(c *gin.Context) {
	id := c.Param("id")
	if err := ctrl.Repo.Delete(id); err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Usuario no encontrado"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"message": "Usuario eliminado"})
}
