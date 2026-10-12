from django.db import connection, transaction
from django.contrib import messages
from django.shortcuts import get_object_or_404, redirect, render
from .forms import BeneficiarioForm, PersonaForm, AgregarBeneficiarioForm
from .models import Beneficiario

#Función que permite obtener la ip del usuario actual, decuelve la direccion ip
#del usuarioa partir del request en formato de string o 0.0.0.0 por default si no se
#logra determinar
def obtener_ip(request):
    x_forwarded_for = request.META.get('HTTP_X_FORWARDED_FOR')
    if x_forwarded_for:
        ip = x_forwarded_for.split(',')[0].strip()
    else:
        ip = request.META.get('REMOTE_ADDR', '0.0.0.0')
    return ip

#función de inicio de sesion, recibe el request para obtener el metodo
def iniciar_sesion(request):

    #si el metodo es post
    if request.method == "POST":

        #obtiene los valores el usuario y contrasena indicados, asi como la ip a traves de la
        #funcion auxiliar
        usuario = request.POST.get('username')
        contrasena = request.POST.get('password')
        ip_cliente = obtener_ip(request)

        #ejecuta el procedimiento almacenado con los parametros, se le pasa la ip
        #para que ese SP puede pasarselo al de registro en bitacora
        with connection.cursor() as cursor:
            cursor.execute(
                'EXEC dbo.sp_IniciarSesion @in_Username = %s, @in_Pass = %s, @in_IP = %s',
                [usuario, contrasena, ip_cliente]
            )

            #almacena lo que retorna el sp
            fila = cursor.fetchone()

            #si es admin fila[0] tiene valor de 1 si no es 0
            es_admin = fila[0] if fila and fila[0] is not None else 0

            #si coincidieron las credenciales el codigo es 0 si no 1
            codigo = fila[1] if fila and fila[1] is not None else 1

            #inicio sesion correctamente, redirige a la lista de beneficiarios
            if codigo == 0:
                request.session['username'] = usuario
                request.session['es_admin'] = es_admin
                return redirect('lista_beneficiarios') 
            #si no, envia mensaje de error para ser mostrado, vuelve al login
            else:
                messages.error(request, "Credenciales inválidas, intente nuevamente")
                return redirect('login')
    #si no es metodo post vuelve al login
    return render(request, 'login.html')

#funcion para cerrar la sesion de un usuario
def cerrar_sesion(request):

    #verificar que haya sesion activa, obtener usuario y la ip para poder registrarla en bitacora
    if 'username' in request.session:
        usuario_actual = request.session['username']
        ip_cliente = obtener_ip(request)

        #ejecucion del sp de cierre de sesion pasandole los parametros de usuaio e ip para llevar a cabo el registro
        with connection.cursor() as cursor:
            cursor.execute("EXEC dbo.sp_CerrarSesion @in_Username = %s, @in_IP = %s", [usuario_actual, ip_cliente])
        request.session.flush() #cierre de sesion
    return redirect('login') #devuelve al login

#funcion para obtener la lista de beneficiarios
def lista_beneficiarios(request):

    #verificar que haya sesion activa y obtener usuario
    if 'username' not in request.session:
        return redirect('login') #si no hay sesion va al login

    usuario_actual = request.session['username']

    #llamado al sp que consulta los beneficiarios dado un usuario
    with connection.cursor() as cursor:
        cursor.execute("EXEC dbo.sp_ObtenerBeneficiarios @in_Username = %s", [usuario_actual])

        #se obtienen los nombres de lascolumnas de lo que retorne el sp, las para a minuscula
        columnas = [col[0].lower() for col in cursor.description]

        #se optienen los beneficiarios en tuplas de nombre de columna, fila
        beneficiarios = [dict(zip(columnas, fila)) for fila in cursor.fetchall()]

        #este for recorre los beneficiarios que se han obtenido uno a uno
        for b in beneficiarios:
            #obtiene el id del beneficiario por el que va
            beneficiario_id = b.get('beneficiarioid') 
            if beneficiario_id:
                #esto nos permite ejecutar el procedimiento almacenado de calcular los porcentajes dado un id de beneficiario
                with connection.cursor() as cursor_suma:
                    cursor_suma.execute("EXEC dbo.sp_CalcularPorcentajes @in_BeneficiarioId = %s", [beneficiario_id])
                    
                    #devuelve una lista con el valor de la suma de los porcentajes de la cuenta
                    lista_suma = cursor_suma.fetchone()
                    suma_total = lista_suma[1] if lista_suma and lista_suma[1] is not None else 100

                    #si la suma es diferente de 100, muestra un mensaje de advertencia
                    if suma_total != 100:
                        messages.warning(request, "La suma de los porcentajes de sus beneficiarios en una o más de sus cuentas no suma 100, favor corregir y cancelar la edición")
                        break #rompe el ciclo porque basta que con uno se imcumpla para la alerta

    #renderiza la lista de beneficiarios y se le pasa la lista como parametro para que el html los pueda desplegar
    return render(request, 'lista_beneficiarios.html', {'beneficiarios': beneficiarios})

#función para realizar la edicion de beneficiarios
def editar_beneficiarios(request, pk):

    #se verigica que haya una sesion activa y si no redirige al login
    if 'username' not in request.session:
        return redirect('login')

    #si hay se sion se obtiene usuario y su ip
    usuario_actual = request.session['username']
    ip_cliente = obtener_ip(request)

    #se obtiene el beneficiario asociado a la pk y que su estado sea activo
    beneficiario = get_object_or_404(Beneficiario.objects.select_related('persona'), pk=pk, activo = True)
    #se obtiene la entidad persona asociada a ese beneficiario
    persona = beneficiario.persona

    #si se llama con el metodo post
    if request.method == 'POST':

        #se crean los formularios con los datos que se hayan reciidos
        form_persona = PersonaForm(request.POST, instance=persona)
        form_beneficiario = BeneficiarioForm(request.POST, instance=beneficiario)

        #verificar que los formularios sean correctos
        if form_persona.is_valid() and form_beneficiario.is_valid():

            #si son validos, se extraen los datos ingresados en los formularios
            nuevo_nombre = form_persona.cleaned_data['nombre']
            nuevo_parentesco = form_beneficiario.cleaned_data['parentesco'].id
            nuevo_porcentaje = form_beneficiario.cleaned_data['porcentaje']

            #llamado al sp de actualizar un beneficiario,se le pasa la ip para poder hacer el registro en bitacora
            with connection.cursor() as cursor:
                cursor.execute(
                    "EXEC dbo.sp_ActualizarBeneficiario @in_Username = %s, @in_BeneficiarioId = %s, @in_NombrePersona = %s, @in_IdParentezco = %s, @in_Porcentaje = %s, @in_IP = %s",
                    [usuario_actual, pk, nuevo_nombre, nuevo_parentesco, nuevo_porcentaje, ip_cliente]
                )

                #aca se guarda la fila que devuelve el sp
                row = None
                while True:
                    if cursor.description is not None:
                        row = cursor.fetchone() #si tiene valores validos revuelve la fila, de lo contrario no
                        if row is not None:
                            break
                    try:
                        if not cursor.nextset():
                            break
                    except Exception:
                        break

                #se obtienen el codigo y el mensaje de lo que haya retornado el SP
                codigo_respuesta = row[0] if row and row[0] is not None else 2
                mensaje_respuesta = row[1] if row and row[1] is not None else "Error al editar beneficiario"

            #codigo 0 de exito
            if codigo_respuesta == 0:
                messages.success(request, mensaje_respuesta)
                return redirect('lista_beneficiarios')

            #codigo de error
            elif codigo_respuesta == 1:
                messages.error(request, mensaje_respuesta)
                return redirect('lista_beneficiarios')
            else:
                messages.error(request, "Error: " + str(mensaje_respuesta))
    else:
        #si no es metodo post, se muestran los formularios con los datos actuales del beneficiario
        form_beneficiario = BeneficiarioForm(instance=beneficiario)
        form_persona = PersonaForm(instance=persona)

    #Se renderiza el template enviando el beneficiario y los formularios
    return render(request, 'editar_beneficiarios.html', {
        'beneficiario' : beneficiario,
        'form_persona' : form_persona,
        'form_beneficiario' : form_beneficiario
    })

#funcion para obtener los estados de cuenta
def lista_estados_cuenta(request):

    #revisa que haya sesion si no la hay va al login
    if 'username' not in request.session:
        return redirect('login')

    #si hay sesion se obtiene usuario y la ip
    usuario_actual = request.session['username']
    ip_cliente = obtener_ip(request)

    #llamado al sp de consulta de estados de cuenta, se le pasa la ip para poder hacer el registro en la bitacora
    with connection.cursor() as cursor:
        cursor.execute("EXEC dbo.sp_ConsultarEstadosDeCuenta @in_Username = %s, @in_IP = %s", [usuario_actual, ip_cliente])

        #se devuelven los nombres de las columnas y los valores un una tupla de columnas, fila
        columnas = [col[0].lower() for col in cursor.description]
        estados_cuenta = [dict(zip(columnas, fila)) for fila in cursor.fetchall()]

    #renderiza la plantilla pasandole la lista de estados de cuenta del usuario y pueda mostrar los datos
    return render(request, 'lista_estados_cuenta.html', {'estados_cuenta': estados_cuenta})

#función que permite conocer si hay una sesion activa para cuando se ingresa a la app sin ninguna url
#si hay sesion va a la lista de beneficiarios, sino al login
def redireccion_inicio(request):
    if 'username' in request.session:
        return redirect('lista_beneficiarios')
    return redirect('login')



def obtener_filas(sql, parametros=None):
    with connection.cursor() as cursor:
        cursor.execute(sql, parametros or [])
        columnas = [col[0].lower() for col in cursor.description]
        return [dict(zip(columnas, fila)) for fila in cursor.fetchall()]

def agregar_beneficiario(request):

    if 'username' not in request.session:
        return redirect('login')

    usuario_actual = request.session['username']
    ip_cliente = obtener_ip(request)

    cuentas = [f['numerocuenta'] for f in obtener_filas("EXEC dbo.sp_ObtenerCuentasUsuario @in_Username = %s", [usuario_actual])]

    # cuentas = [f['numerocuenta'] for f in obtener_filas("EXEC dbo.sp_ObtenerCuentasUsuario @in_Username = %s", [usuario_actual])]
    tipos_documento = [(f['id'], f['nombre']) for f in obtener_filas("EXEC dbo.sp_ObtenerTiposDocumento")]
    parentescos = [(f['id'], f['nombre']) for f in obtener_filas("EXEC dbo.sp_ObtenerParentescos")]

    if request.method == 'POST':
        form = AgregarBeneficiarioForm(request.POST, cuentas = cuentas, tipos_documento=tipos_documento, parentescos = parentescos)
        if form.is_valid():
            datos = form.cleaned_data

            with connection.cursor() as cursor:
                cursor.execute(
                    "EXEC dbo.sp_AgregarBeneficiario @in_Username = %s, @in_NumeroCuenta = %s, @in_TipoDoc = %s, "
                    "@in_NombrePersona = %s, @in_ValorDoc = %s, @in_FechaNac = %s, @in_Email = %s, @in_Tel1 = %s, "
                    "@in_Tel2 = %s, @in_IdParentezco = %s, @in_Porcentaje = %s, @in_IP = %s",
                    [usuario_actual, int(datos['numero_cuenta']), int(datos['tipo_documento']), datos['nombre'],
                     datos['valor_documento'], datos['fecha_nacimiento'], datos['email'], datos['telefono1'],
                     datos['telefono2'], int(datos['parentesco']), datos['porcentaje'], ip_cliente]
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
                mensaje_respuesta = row[1] if row and row[1] is not None else "Error al agregar beneficiario"

            if codigo_respuesta == 0:
                messages.success(request, mensaje_respuesta)
                return redirect('lista_beneficiarios')

            messages.error(request, mensaje_respuesta)
    else:
        form = AgregarBeneficiarioForm(cuentas=cuentas, tipos_documento=tipos_documento, parentescos=parentescos)

    return render(request, 'agregar_beneficiarios.html', {'form':form})

