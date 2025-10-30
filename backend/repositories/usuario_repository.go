package repositories

import "github.com/Guimi21/Golang_CRUD/models"

type UsuarioRepository interface {
	FindAll() ([]models.Usuario, error)
	FindByID(id string) (models.Usuario, error)
	Create(usuario models.Usuario) (models.Usuario, error)
	Update(id string, usuario models.Usuario) (models.Usuario, error)
	Delete(id string) error
}
