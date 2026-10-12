from django.urls import path
from . import views

urlpatterns = [
    path('', views.redireccion_inicio, name = 'inicio'),
    path('login/', views.iniciar_sesion, name = 'login'),
    path('logout/', views.cerrar_sesion, name = 'logout'),
    path('beneficiarios/', views.lista_beneficiarios, name = 'lista_beneficiarios'),
    path('beneficiarios/agregar/', views.agregar_beneficiario, name = 'agregar_beneficiario'),
    path('beneficiarios/<int:pk>/eliminar/', views.eliminar_beneficiario, name = 'eliminar_beneficiario'),
    path('beneficiarios/<int:pk>/editar/', views.editar_beneficiarios, name = 'editar_beneficiarios'),
    path('estados-de-cuenta/', views.lista_estados_cuenta, name='lista_estados_cuenta'),
]