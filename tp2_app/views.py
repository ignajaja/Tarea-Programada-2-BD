from django.db import connection, transaction
from django.contrib import messages
from django.shortcuts import get_object_or_404, redirect, render
from .forms import BeneficiarioForm, PersonaForm
from .models import Beneficiario

def iniciar_sesion(request):
    if request.method == "POST":
        usuario = request.POST.get('username')
        contrasena = request.POST.get('password')
        
        with connection.cursor() as cursor:

            cursor.execute(
                'EXEC dbo.sp_IniciarSesion @in_Username = ?, @in_Pass = ?, @out_EsAdministrador = ?, @out_CodigoRespuesta = ?',
                [usuario, contrasena]
            )
            fila = cursor.fetchdone()
            
            es_admin = fila[0] if fila and fila[0] is not None else 0
            codigo = fila[1] if fila and fila[1] is not None else 1
            
            if codigo == 0:
                request.session['username'] = usuario
                request.session['es_admin'] = es_admin
                return redirect('lista_beneficiarios') 
            else:
                messages.error(request, "Credenciales inválidas, intente nuevamente")
                return redirect('login')
                

    return render(request, 'login.html')

def cerrar_sesion(request):
    if 'username' in request.session:
        usuario_actual = request.session['username']
        with connection.cursor() as cursor:
            cursor.execute("EXEC dbo.sp_CerrarSesion @in_Username = %s", [usuario_actual])
        request.session.flush()
    return redirect('login')

def lista_beneficiarios(request):
    if 'username' not in request.session:
        return redirect('login')

    usuario_actual = request.session['username']

    with connection.cursor() as cursor:
        cursor.execute("EXEC dbo.sp_ObtenerBeneficiarios @in_Username = %s", [usuario_actual])
        columnas = [col[0].lower() for col in cursor.description]
        beneficiarios = [dict(zip(columnas, fila)) for fila in cursor.fetchall()]

    return render(request, 'lista_beneficiarios.html', {'beneficiarios':beneficiarios})


def editar_beneficiarios(request, pk):
    if 'username' not in request.session:
        return redirect('login')
    
    usuario_actual = request.session['username']

    beneficiario = get_object_or_404(Beneficiario.objects.select_related('persona'), pk=pk, activo = True)
    persona = beneficiario.persona

    if request.method == 'POST':
        form_persona = PersonaForm(request.POST, instance=persona)
        form_beneficiario = BeneficiarioForm(request.POST, instance=beneficiario)

        if form_persona.is_valid() and form_beneficiario.is_valid():
            nuevo_nombre = form_persona.cleaned_data['nombre']
            nuevo_parentesco = form_beneficiario.cleaned_data['parentesco'].id
            nuevo_porcentaje = form_beneficiario.cleaned_data['porcentaje']

            with connection.cursor() as cursor:
        
                
                cursor.execute(
                    "EXEC dbo.sp_ActualizarBeneficiario @in_Username = ?, @in_BeneficiarioId = ?, @in_NombrePersona = ?, @in_IdParentezco, @in_Porcentaje = ?",
                    [usuario_actual, pk, nuevo_nombre, nuevo_parentesco, nuevo_porcentaje]
                )
                fila = cursor.fetchdone()
                codigo_respuesta = fila[0] if fila and fila[0] is not None else 2
                mensaje_respuesta = fila[1] if fila and fila[1] is not None else "Error al editar beneficiario"

            if codigo_respuesta == 0:
                messages.success(request, mensaje_respuesta)
                return redirect('lista_beneficiarios')
            elif codigo_respuesta == 1:
                messages.error(request, mensaje_respuesta)
            else:
                messages.error(request, "Error: " + str(mensaje_respuesta))
    else:
        form_beneficiario = BeneficiarioForm(instance=beneficiario)
        form_persona = PersonaForm(instance=persona)

    return render(request, 'editar_beneficiarios.html', {
        'beneficiario' : beneficiario,
        'form_persona' : form_persona,
        'form_beneficiario' : form_beneficiario
    })


def redireccion_inicio(request):
    if 'username' in request.session:
        return redirect('lista_beneficiarios')
    return redirect('login')


