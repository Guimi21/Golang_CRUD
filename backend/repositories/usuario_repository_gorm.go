package repositories

import (
	"github.com/Guimi21/Golang_CRUD/config"
	"github.com/Guimi21/Golang_CRUD/models"
)

type UsuarioRepositoryGorm struct{}

func NewUsuarioRepositoryGorm() UsuarioRepository {
	return &UsuarioRepositoryGorm{}
}

func (r *UsuarioRepositoryGorm) FindAll() ([]models.Usuario, error) {
	var usuarios []models.Usuario
	err := config.DB.Find(&usuarios).Error
	return usuarios, err
}

func (r *UsuarioRepositoryGorm) FindByID(id string) (models.Usuario, error) {
	var usuario models.Usuario
	err := config.DB.First(&usuario, id).Error
	return usuario, err
}

func (r *UsuarioRepositoryGorm) Create(usuario models.Usuario) (models.Usuario, error) {
	err := config.DB.Create(&usuario).Error
	return usuario, err
}

func (r *UsuarioRepositoryGorm) Update(id string, data models.Usuario) (models.Usuario, error) {
	var usuario models.Usuario
	if err := config.DB.First(&usuario, id).Error; err != nil {
		return usuario, err
	}

	usuario.Nombre = data.Nombre
	usuario.Correo = data.Correo
	usuario.Edad = data.Edad

	err := config.DB.Save(&usuario).Error
	return usuario, err
}

func (r *UsuarioRepositoryGorm) Delete(id string) error {
	var usuario models.Usuario
	if err := config.DB.First(&usuario, id).Error; err != nil {
		return err
	}
	return config.DB.Delete(&usuario).Error
}
