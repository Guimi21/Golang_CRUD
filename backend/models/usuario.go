package models

import "gorm.io/gorm"

type Usuario struct {
	gorm.Model
	Id          int    `json:"id"`
	Nombre      string `json:"nombre"`
	Correo      string `json:"correo"`
	Edad        int    `json:"edad"`
	Sincronizado int   `json:"sincronizado"` // true = sincronizado, false = no sincronizado
}
