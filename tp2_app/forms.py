from django import forms
from .models import Beneficiario, Persona

class PersonaForm(forms.ModelForm):
    class Meta:
        model = Persona
        fields = [
            'nombre', 'tipo_documento', 'valor_documento', 'fecha_nacimiento', 'email', 'telefono1', 'telefono2'

        ]
        labels = {
            'tipo_documento': 'Tipo de documento de identidad',
            'valor_documento': 'Valor del documento de identidad',
            'fecha_nacimiento': 'Fecha de nacimiento',
            'telefono1': 'Teléfono1',
            'telefono2': 'Teléfono2'

        }

# esto es para hacerlo de manera que ingresar la fecha sea sencillo
        widgets = {
            'fecha_nacimiento': forms.DateInput(attrs={'type': 'date'}, format='%Y-%m-%d'),
        }



    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.fields['valor_documento'].disabled = True




class BeneficiarioForm(forms.ModelForm):
    class Meta:
        model = Beneficiario
        fields = ['parentesco', 'porcentaje']
        labels = {'porcentaje': 'Porcentaje de beneficio'}

