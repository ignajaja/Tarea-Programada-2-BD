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
                'EXEC dbo.sp_IniciarSesion @in_Username = %s, @in_Pass = %s',
                [usuario, contrasena]
            )
            fila = cursor.fetchone()
            
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

        #Una vez obtenidos los beneficiarios se van a usar para ejecutar el sp de calcular porcentajes
        #para saber si hay alguna cuenta que no cumple con el 100%
        alerta_porcentaje = None
        for b in beneficiarios:
            beneficiario_id = b.get('beneficiarioid') 
        
            if beneficiario_id:
                with connection.cursor() as cursor_suma:
                    #Lamada al sp pasandole el id del beneficiario.
                    cursor_suma.execute("EXEC dbo.sp_CalcularPorcentajes @in_BeneficiarioId = %s", [beneficiario_id])
                    lista_suma = cursor_suma.fetchone()
                
                    suma_total = lista_suma[1] if lista_suma and lista_suma[1] is not None else 100

                    # Si alguna cuenta no suma 100% se crea la alerta
                    if suma_total != 100:
                        mensaje_alerta = "La suma de los porcentajes de sus beneficiarios en una o más de sus cuentas no suma 100, favor corregir y cancelar la edición"
                        messages.warning(request, mensaje_alerta)
                        break # con solo una que falle muestra la alerta

    return render(request, 'lista_beneficiarios.html', {'beneficiarios': beneficiarios})


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
                    "EXEC dbo.sp_ActualizarBeneficiario @in_Username = %s, @in_BeneficiarioId = %s, @in_NombrePersona = %s, @in_IdParentezco = %s, @in_Porcentaje = %s",
                    [usuario_actual, pk, nuevo_nombre, nuevo_parentesco, nuevo_porcentaje]
                )

                row = None
                while True:
                    if cursor.description is not None:
                        row = cursor.fetchone()
                        if row is not None:
                            break
                    try:
                        if not cursor.nextset():
                            break
                    except Exception:
                        break

                codigo_respuesta = row[0] if row and row[0] is not None else 2
                mensaje_respuesta = row[1] if row and row[1] is not None else "Error al editar beneficiario"

            if codigo_respuesta == 0:
                messages.success(request, mensaje_respuesta)
                return redirect('lista_beneficiarios')
            elif codigo_respuesta == 1:
                messages.error(request, mensaje_respuesta)
                return redirect('lista_beneficiarios')
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


