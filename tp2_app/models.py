from django.db import models

from django.core.validators import MaxValueValidator, MinValueValidator

# Create your models here.


class Parentesco(models.Model):
    id = models.IntegerField(primary_key=True, db_column='Id')
    nombre = models.CharField(max_length=32, db_column='Nombre')

    class Meta:
        managed = False
        db_table = 'Parentesco'

    def __str__(self):
        return self.nombre

class TipoDoc(models.Model):
    id = models.IntegerField(primary_key=True, db_column='Id')
    nombre = models.CharField(max_length=64, db_column='Nombre')
    class Meta:
        managed = False
        db_table = 'Tipo_Doc'
        ordering = ['id']

    def __str__(self):
        return self.nombre



class Persona(models.Model):
    id = models.AutoField(primary_key=True, db_column='Id')
    tipo_documento = models.ForeignKey(TipoDoc, on_delete=models.PROTECT, db_column='TipoDocuIdentidad')
    nombre=models.CharField(max_length=64, db_column='Nombre')
    valor_documento = models.CharField(max_length=32, unique=True, db_column='ValorDocumentoIdentidad')
    fecha_nacimiento = models.DateField(db_column='FechaNacimiento')
    email = models.EmailField(db_column='Email')
    telefono1 = models.CharField(max_length=16, db_column='telefono1')
    telefono2 = models.CharField(max_length=16, db_column='telefono2')

    class Meta:
        managed = False
        db_table = 'Persona'

    def __str__(self):
        return self.nombre

class Beneficiario(models.Model):
    id = models.AutoField(primary_key=True, db_column='Id')
    numero_cuenta = models.IntegerField(db_column='NumeroCuenta')
    persona = models.ForeignKey(Persona, on_delete=models.PROTECT, to_field='valor_documento', db_column='ValorDocumentoIdentidadBeneficiario')
    parentesco = models.ForeignKey(Parentesco, on_delete=models.PROTECT, db_column='ParentezcoId')
    porcentaje = models.IntegerField(validators=[MinValueValidator(0), MaxValueValidator(100)], db_column='Porcentaje')
    activo = models.BooleanField(default=True, db_column='Activo')
    fecha_desactivacion = models.DateField(null=True, blank=True, db_column='FechaDesactivacion')

    class Meta:
        managed = False
        db_table = 'Beneficiario'


