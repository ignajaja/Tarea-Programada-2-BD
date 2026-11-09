from django.db import connection, transaction
from django.contrib import messages
from django.shortcuts import get_object_or_404, redirect, render
from .forms import BeneficiarioForm, PersonaForm, AgregarBeneficiarioForm
from .models import Beneficiario, Persona

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
    if 'username' not in request.session:
        return redirect('login')

    usuario_actual = request.session['username']

    # Obtener las cuentas a las que el usuario tiene acceso
    cuentas = obtener_filas("EXEC dbo.sp_ObtenerCuentasUsuario @in_Username = %s", [usuario_actual])
    
    # Determinar qué cuenta está seleccionada (por defecto la primera si existe)
    id_cuenta_seleccionada = request.GET.get('cuenta')
    
    if not id_cuenta_seleccionada and cuentas:
        id_cuenta_seleccionada = cuentas[0]['idcuenta'] # Toma la primera cuenta por defecto

    beneficiarios = []
    if id_cuenta_seleccionada:
        with connection.cursor() as cursor:
            # Llamado al SP pasando el usuario y el ID de la cuenta específica
            cursor.execute("EXEC dbo.sp_ObtenerBeneficiarios @in_Username = %s, @in_IdCuenta = %s", [usuario_actual, id_cuenta_seleccionada])
            
            if cursor.description:
                columnas = [col[0].lower() for col in cursor.description]
                beneficiarios = [dict(zip(columnas, fila)) for fila in cursor.fetchall()]

        # Validación de la suma de porcentajes para la cuenta seleccionada
        for b in beneficiarios:
            beneficiario_id = b.get('beneficiarioid') 
            if beneficiario_id:
                with connection.cursor() as cursor_suma:
                    cursor_suma.execute("EXEC dbo.sp_CalcularPorcentajes @in_BeneficiarioId = %s", [beneficiario_id])
                    lista_suma = cursor_suma.fetchone()
                    suma_total = lista_suma[1] if lista_suma and lista_suma[1] is not None else 100

                    if suma_total != 100:
                        messages.warning(request, "La suma de los porcentajes de sus beneficiarios en esta cuenta no suma 100%, favor corregir.")
                        break

    return render(request, 'lista_beneficiarios.html', {
        'beneficiarios': beneficiarios,
        'cuentas': cuentas,
        'cuenta_seleccionada': int(id_cuenta_seleccionada) if id_cuenta_seleccionada else None
    })

#función para realizar la edicion de beneficiarios
def editar_beneficiarios(request, pk):
    if 'username' not in request.session:
        return redirect('login')

    usuario_actual = request.session['username']
    ip_cliente = obtener_ip(request)

    # Llamado  al SP para obtener datos del beneficiario y persona asociada
    datos = obtener_filas("EXEC dbo.sp_ObtenerDetalleBeneficiario @in_Username = %s, @in_BeneficiarioId = %s", [usuario_actual, pk])
    
    if not datos:
        messages.error(request, "El beneficiario no existe o está inactivo.")
        return redirect('lista_beneficiarios')

    row = datos[0]

    # Instanciar modelos para los ModelForm
    persona = Persona(
        id=row['personaid'],
        nombre=row['nombre'],
        tipo_documento_id=row['tipodocumentoid'],
        valor_documento=row['valordocumento'],
        fecha_nacimiento=row['fechanacimiento'],
        email=row['email'],
        telefono1=row['telefono1'],
        telefono2=row['telefono2']
    )
    beneficiario = Beneficiario(
        id=row['beneficiarioid'],
        persona=persona,
        parentesco_id=row['parentescoid'],  # O cámbialo por id_parentesco= si así se llama en tu models.py
        porcentaje=row['porcentaje']
    )

    if request.method == 'POST':
        form_persona = PersonaForm(request.POST, instance=persona)
        form_beneficiario = BeneficiarioForm(request.POST, instance=beneficiario)

        if form_persona.is_valid() and form_beneficiario.is_valid():
            nuevo_nombre = form_persona.cleaned_data['nombre']
            
            parentesco_val = form_beneficiario.cleaned_data['parentesco']
            nuevo_parentesco = parentesco_val.id if hasattr(parentesco_val, 'id') else parentesco_val
            
            nuevo_porcentaje = form_beneficiario.cleaned_data['porcentaje']

            # Llamado al SP de actualización
            with connection.cursor() as cursor:
                cursor.execute(
                    "EXEC dbo.sp_ActualizarBeneficiario @in_Username = %s, @in_BeneficiarioId = %s, @in_NombrePersona = %s, @in_IdParentesco = %s, @in_Porcentaje = %s, @in_IP = %s",
                    [usuario_actual, pk, nuevo_nombre, nuevo_parentesco, nuevo_porcentaje, ip_cliente]
                )

                r = None
                while True:
                    if cursor.description is not None:
                        r = cursor.fetchone()
                        if r is not None:
                            break
                    try:
                        if not cursor.nextset():
                            break
                    except Exception:
                        break

                codigo_respuesta = r[0] if r and r[0] is not None else 2
                mensaje_respuesta = r[1] if r and r[1] is not None else "Error al editar beneficiario"

            if codigo_respuesta == 0:
                messages.success(request, mensaje_respuesta)
                return redirect('lista_beneficiarios')
            else:
                messages.error(request, mensaje_respuesta)
    else:
        form_beneficiario = BeneficiarioForm(instance=beneficiario)
        form_persona = PersonaForm(instance=persona)

    return render(request, 'editar_beneficiarios.html', {
        'beneficiario': beneficiario,
        'form_persona': form_persona,
        'form_beneficiario': form_beneficiario
    })

#funcion para obtener los estados de cuenta
def lista_estados_cuenta(request):
    if 'username' not in request.session:
        return redirect('login')

    usuario_actual = request.session['username']
    ip_cliente = obtener_ip(request)

    # Obtener las cuentas del usuario para el selector
    cuentas = obtener_filas("EXEC dbo.sp_ObtenerCuentasUsuario @in_Username = %s", [usuario_actual])
    
    id_cuenta_seleccionada = request.GET.get('cuenta')
    if not id_cuenta_seleccionada and cuentas:
        id_cuenta_seleccionada = cuentas[0]['idcuenta']

    estados_cuenta = []
    if id_cuenta_seleccionada:
        with connection.cursor() as cursor:
            # Llamado al SP pasando el usuario, la cuenta y la IP
            cursor.execute(
                "EXEC dbo.sp_ConsultarEstadosDeCuenta @in_Username = %s, @in_IdCuenta = %s, @in_IP = %s", 
                [usuario_actual, id_cuenta_seleccionada, ip_cliente]
            )
            
            if cursor.description:
                columnas = [col[0].lower() for col in cursor.description]
                estados_cuenta = [dict(zip(columnas, fila)) for fila in cursor.fetchall()]

    return render(request, 'lista_estados_cuenta.html', {
        'estados_cuenta': estados_cuenta,
        'cuentas': cuentas,
        'cuenta_seleccionada': int(id_cuenta_seleccionada) if id_cuenta_seleccionada else None
    })

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
                    "@in_Tel2 = %s, @in_IdParentesco = %s, @in_Porcentaje = %s, @out_Codigo = %s OUTPUT, @out_Mensaje = %s OUTPUT, @in_IP = %s",
                    [usuario_actual, int(datos['numero_cuenta']), int(datos['tipo_documento']), datos['nombre'],
                     datos['valor_documento'], datos['fecha_nacimiento'], datos['email'], datos['telefono1'],
                     datos['telefono2'], int(datos['parentesco']), datos['porcentaje'], None, None, ip_cliente]
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

def eliminar_beneficiario(request, pk):
    if 'username' not in request.session:
        return redirect('login')

    if request.method != 'POST':
        return redirect('lista_beneficiarios')

    usuario_actual = request.session['username']
    ip_cliente = obtener_ip(request)

    with connection.cursor() as cursor:
        cursor.execute(
            "EXEC dbo.sp_EliminarBeneficiario @in_Username = %s, @in_BeneficiarioId = %s, @in_IP = %s",
            [usuario_actual, pk, ip_cliente]

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

        codigo_respuesta = row[0] if row and row[0] is not None else 1
        mensaje_respuesta = row[1] if row and row[1] is not None else "Error al eliminar beneficiario"


    if codigo_respuesta ==0 :
        messages.success(request, mensaje_respuesta)
    else:
        messages.error(request, mensaje_respuesta)

    return redirect('lista_beneficiarios')

#funcion para ver el detalle de un estado de cuenta y sus movimientos
def detalle_estado_cuenta(request, pk):
    if 'username' not in request.session:
        return redirect('login')

    usuario_actual = request.session['username']
    ip_cliente = obtener_ip(request)

    id_cuenta = request.GET.get('cuenta')
    if not id_cuenta or not id_cuenta.isdigit():
        messages.error(request, "No se indicó la cuenta del estado de cuenta.")
        return redirect('lista_estados_cuenta')

    # datos generales: el SP los lista por cuenta, se toma el estado seleccionado
    estados = obtener_filas(
        "EXEC dbo.sp_ConsultarEstadosDeCuenta @in_Username = %s, @in_IdCuenta = %s, @in_IP = %s",
        [usuario_actual, id_cuenta, ip_cliente]
    )
    estado = next((e for e in estados if e['idestadocuenta'] == pk), None)

    if estado is None:
        messages.error(request, "El estado de cuenta no existe o no tiene permiso para verlo.")
        return redirect('lista_estados_cuenta')

    movimientos = obtener_filas(
        "EXEC dbo.sp_ConsultarMovimientosEstadoCuenta @in_Username = %s, @in_IdEstadoCuenta = %s, @in_IP = %s",
        [usuario_actual, pk, ip_cliente]
    )

    total_sinpe = (estado['cantsinpeentrantes'] or 0) + (estado['cantsinpesalientes'] or 0)

    return render(request, 'detalle_estado_de_cuenta.html', {
        'estado': estado,
        'movimientos': movimientos,
        'total_sinpe': total_sinpe,
        'cuenta_seleccionada': int(id_cuenta)
    })