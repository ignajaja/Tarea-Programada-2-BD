from django import forms
from .models import Beneficiario, Persona
from django.core.validators import RegexValidator

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


class AgregarBeneficiarioForm(forms.Form):
    numero_cuenta = forms.ChoiceField(label='Cuenta')
    nombre = forms.CharField(max_length=64, label='Nombre')
    tipo_documento = forms.ChoiceField(label='Tipo de documento de identidad')
    valor_documento = forms.CharField(
        max_length=32,
        label='Valor del documento de identidad',
        validators=[RegexValidator(r'^\d+$', 'El documento debe contener solo números.')]
    )
    fecha_nacimiento = forms.DateField(
        label='Fecha de nacimiento',
        widget=forms.DateInput(attrs={'type': 'date'}, format='%Y-%m-%d')
    )
    email = forms.EmailField(max_length=256, label='Email')
    telefono1 = forms.CharField(max_length=16, label='Teléfono 1')
    telefono2 = forms.CharField(max_length=16, label='Teléfono 2')
    parentesco = forms.ChoiceField(label='Parentesco')
    porcentaje = forms.IntegerField(min_value=0, max_value=100, label='Porcentaje de beneficio')

    def __init__(self, *args, cuentas, tipos_documento, parentescos, **kwargs):
        super().__init__(*args, **kwargs)
        vacio = [('', 'Seleccione...')]
        self.fields['numero_cuenta'].choices = vacio + [(c, c) for c in cuentas]
        self.fields['tipo_documento'].choices = vacio + list(tipos_documento)
        self.fields['parentesco'].choices = vacio + list(parentescos)
