from django.shortcuts import render, redirect
from django.db import connection
from django.contrib import messages

def login_view(request):
    if request.method == "POST":

        #Agarra los valores dados en el formulario
        usuario = request.POST.get('username')
        contrasena = request.POST.get('password')

        with connection.cursor() as cursor:
            ## Ejecuta el SP
            cursor.execute('EXEC dbo.sp_IniciarSesion @in_Username=%s, @in_Pass=%s', [usuario, contrasena])

            fila = cursor.fetchone()

            es_admin = fila[0] if fila else 0
            codigo = fila[1] if fila else 1

            #Guardar la sesion
            if codigo == 0:
                request.session['username'] = usuario
                request.session['es_admin'] = es_admin
                return redirect ('dashboard')
            else:
                messages.error (request, "Credenciales inválidas, intente nuevamente")
                return redirect('login')
        return render(request, 'login.html')

def editar_beneficiarios(request):
    #logica editar beneficiarios
    return render(request, 'editar_beneficiarios.html')



