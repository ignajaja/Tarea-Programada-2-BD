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
            cursor.execute('EXEC dbo.sp_IniciarSesion @in_Username=%s, @in_Pass=%s', [usuario, contrasena])
            fila = cursor.fetchone()
            
            es_admin = fila[0] if fila else 0
            codigo = fila[1] if fila else 1
            
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


def editar_beneficiarios(request, pk):
    beneficiario = get_object_or_404(Beneficiario.objects.select_related('persona'), pk=pk, activo=True)
    persona = beneficiario.persona

    if request.method == 'POST':
        form_persona = PersonaForm(request.POST, instance=persona)
        form_beneficiario = BeneficiarioForm(request.POST, instance=beneficiario)
        if form_persona.is_valid() and form_beneficiario.is_valid():
            # ACID, se salva todo o nada
            with transaction.atomic():
                form_persona.save()
                form_beneficiario.save()

            messages.success(request, 'Se actualizó correctamente')
            return redirect('lista_beneficiarios')

    else:
        form_beneficiario = BeneficiarioForm(instance=beneficiario)
        form_persona = PersonaForm(instance=persona)

    return render(request, 'editar_beneficiarios.html', {'beneficiario': beneficiario, 'form_persona': form_persona, 'form_beneficiario': form_beneficiario})


