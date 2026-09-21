# Reciclalo (EcoRecicla)
## Documentación del Proyecto

**Universidad Autónoma Gabriel René Moreno**
Facultad de Ingeniería en Ciencias de la Computación y Telecomunicaciones

**Docente:** Ing. Brando

**Integrantes:**
- Juan Carlos Laura Cespedes — 209022892
- Alex Ticlla Choque — 222010029

**Modalidad de implementación:** Proyecto con IA / Ingeniería de IA / VibeCoding

**Fecha:** 20 de septiembre de 2026

---

## 1. Antecedentes

La gestión de residuos reciclables en contextos urbanos como Santa Cruz de la Sierra enfrenta un problema estructural: la falta de un canal directo y geolocalizado entre quienes generan material reciclable (vecinos y comercios) y quienes lo recolectan. Los vecinos separan en casa botellas PET, latas, cartón y vidrio, pero no cuentan con transporte ni con información sobre horarios o rutas de los recolectores informales que operan en su zona. Como consecuencia, buena parte de ese material reciclable termina mezclado con la basura común y es enviado al vertedero, pese a que existe tanto la voluntad del generador de separarlo como la demanda de recolectores dispuestos a retirarlo.

Del lado de la oferta, los recolectores y operadores de reciclaje dependen hoy de recorridos fijos o de referencias informales para encontrar material disponible, sin visibilidad de qué solicitudes existen cerca de su posición en un momento dado. Esta desconexión logística eleva el costo de coordinación para ambas partes: el generador no tiene certeza de cuándo pasará alguien a retirar su material, y el recolector no tiene certeza de que el viaje a un punto determinado será productivo.

A esto se suma que las soluciones existentes en el mercado (aplicaciones de gestión de residuos municipales, plataformas de compra-venta de material reciclable) suelen requerir integración con sistemas municipales o modelos de pago complejos, lo que las vuelve poco accesibles para una implementación ágil orientada a un caso de uso barrial y de pequeño comercio.

Sobre esta base, se plantea el desarrollo de **Reciclalo** (marca de producto: **EcoRecicla**), una aplicación tipo SaaS para la coordinación geolocalizada y en tiempo real del retiro de residuos reciclables, que conecta a dos roles de usuario — el Ciudadano/Comercio que genera el material y el Recolector/Operador que lo retira — sin depender de pagos digitales, clasificación automática por inteligencia artificial, ni integración con sistemas municipales, dejando esos aspectos deliberadamente fuera de alcance para esta primera versión del producto.

---

## 2. Solución

Reciclalo se implementó como una aplicación móvil (Flutter) con un backend REST (Django + PostgreSQL), organizada en dos roles claramente diferenciados por vista: Ciudadano/Comercio y Recolector/Operador, cada uno con su propio recorrido dentro de la misma base de código. La construcción del producto siguió un proceso de **desarrollo asistido por IA (VibeCoding)**: por cada flujo funcional se generó primero un documento de diseño (design prompt) que definía las pantallas, el contexto de usuario y los tokens visuales del sistema de diseño (`EcoColors`, `EcoSpacing`, `EcoRadius` de `app_theme.dart`); ese documento se usó para producir prototipos de interfaz (mediante Google Stitch o Figma, según el flujo); y a partir de ambos se redactó un plan de implementación técnico que especificaba modelos de datos, endpoints de la API y la estructura del código Flutter correspondiente, antes de escribir la implementación final.

A continuación se documenta el proceso de desarrollo seguido en cada uno de los cinco flujos construidos.

### 2.1 Flujo 1 — Ciudadano: publicación de una solicitud de retiro

Este fue el primer flujo desarrollado y estableció la base del producto: la vista del Ciudadano/Comercio (Generador), dejando fuera de alcance, de manera intencional, la vista del Recolector y el ciclo de vida completo de una solicitud (aceptar, marcar en camino, completar), que se resolverían en un flujo posterior.

El proceso de diseño partió de un prompt dirigido a Google Stitch, construido a partir del perfil de usuario objetivo (un vecino de Santa Cruz que separa material reciclable pero no tiene forma simple de avisar a un recolector) y del mapa de pantallas ya definido en la documentación de producto. A partir de ese prompt se generaron seis pantallas conectadas como flujo navegable: ingreso rápido, pantalla principal con "Mis Solicitudes Activas", formulario de publicación de retiro en tres pasos (tipo de material, foto, ubicación GPS), pantalla de confirmación ("Buscando recolector cercano"), detalle de solicitud e historial de retiros completados.

Sobre esa base visual se redactó el plan de implementación técnico. En el backend, se creó la app de Django `solicitudes` con el modelo `SolicitudRetiro` (material, foto, coordenadas, estado y usuario) y una API REST mínima construida con Django REST Framework: creación de solicitudes, listado de solicitudes activas y completadas, y detalle por identificador, autenticada mediante `TokenAuthentication`. En el frontend, se estructuró el proyecto Flutter en las carpetas `screens/`, `widgets/`, `models/` y `services/`, y se implementaron las seis pantallas en el orden del flujo (login → home → formulario de retiro → confirmación → detalle → historial), integrando `image_picker` para la foto del material y `geolocator` para la confirmación de ubicación GPS, y conectando cada pantalla a los endpoints reales del backend en reemplazo de datos de prueba.

El resultado de este flujo es el camino completo de publicación de una solicitud: el ciudadano selecciona el tipo de material, adjunta una foto, confirma su ubicación y publica el retiro, que queda visible en su historial de solicitudes activas.

### 2.2 Flujo 2 — Recolector: mapa y gestión de solicitudes

Este flujo incorporó el segundo rol del producto y cerró el ciclo de vida de una solicitud que el Flujo 1 había dejado abierto. El diseño definió cuatro pantallas para el Recolector/Operador: un mapa interactivo con las solicitudes disponibles cerca de su ubicación, el detalle de una solicitud puntual con la opción de aceptarla o rechazarla, un diálogo de confirmación antes de comprometerse a un retiro, y una vista posterior a la aceptación con navegación externa y marcado de retiro completado. El prompt de diseño especificó también las integraciones externas del flujo: WhatsApp para contactar al ciudadano y Google Maps para la navegación hacia el punto de retiro, evitando así construir un chat o un sistema de rutas propio.

En el backend, se extendió la app `solicitudes` con dos modelos nuevos: `Recolector`, un perfil uno-a-uno sobre el usuario que registra su ubicación actual y disponibilidad, y `AsignacionRetiro`, que guarda el historial de aceptaciones, rechazos y completados de cada solicitud — de forma que un rechazo nunca cambia el estado de la solicitud en sí, solo evita que ese recolector vuelva a recibirla como disponible. Se añadieron los endpoints de perfil, actualización de ubicación y disponibilidad del recolector, listado de solicitudes cercanas por radio (calculado con la librería `geopy` sobre distancia geodésica), y las acciones de aceptar, rechazar y completar una solicitud, protegidas con bloqueo de fila (`select_for_update`) para que dos recolectores no puedan tomar la misma solicitud simultáneamente. En el frontend, se construyeron las pantallas bajo `screens/picker/`, con un servicio dedicado (`PickerService`) para consumir estos endpoints y servicios adicionales para las integraciones externas (`MapsService`, mediante `url_launcher` hacia Google Maps y WhatsApp).

Con este flujo, el ciclo de una solicitud quedó completo de punta a punta: pendiente → aceptada → completada, con ambos roles operando sobre el mismo modelo de datos desde vistas distintas de una misma API.

### 2.3 Flujo 3 — Fidelización y gamificación: EcoPuntos, racha y recompensas

Este flujo cierra el ciclo de valor de la aplicación después de cada retiro completado, acreditando puntos al ciudadano y reforzando la constancia de ambos roles mediante una racha semanal. Es el flujo con mayor complejidad de reglas de negocio del proyecto.

El diseño definió cinco destinos visuales compartidos por ambos roles: un modal de acreditación inmediata de EcoPuntos al completarse un retiro, una pantalla de catálogo de recompensas con el saldo del usuario como elemento principal, el detalle y confirmación de canje de una recompensa, un panel de "Mi Impacto y Racha" con huella de carbono/agua evitada y el estado de la racha semanal con sus protectores, y un modal de celebración al cruzar un hito de racha (2, 4, 8, 12, 26 o 52 semanas). Todas las pantallas reutilizaron los tokens visuales ya existentes en `app_theme.dart`, sin introducir una paleta nueva para los logros.

El plan de implementación creó una app de Django independiente, `gamificacion`, desacoplada del dominio de solicitudes mediante un único punto de integración: al completar un retiro, `solicitudes` invoca un servicio de `gamificacion` que acredita los puntos, sin que la primera app conozca el modelo de puntos. Se definieron los modelos `SaldoEcoPuntos` (saldo vigente por usuario), `TransaccionEcoPuntos` (historial de movimientos, nunca editado), `Recompensa` y `Canje` (catálogo y canjes), y `ProgresoRacha` (resultado persistido y evaluado semanalmente de la racha de cada usuario por rol). La racha se calcula mediante un comando de gestión (`cerrar_semana_racha`) que se ejecuta semanalmente, evalúa si hubo actividad en la semana, consume automáticamente uno de los dos protectores mensuales si no la hubo, y acredita el bono correspondiente al cruzar un hito — con tablas de puntos distintas para Ciudadano y Recolector, siendo la de este último más baja porque completar retiros es más frecuente que generarlos. Como el ciudadano no es quien ejecuta la acción de completar un retiro, y el cierre de una racha ocurre en un proceso en segundo plano, se agregó una cola de eventos pendientes (`EventoPendiente`) que el frontend consulta al abrir la pantalla raíz de cada rol, para mostrar los modales de acreditación e hito en el momento correcto.

En el frontend, se incorporaron los modelos y el servicio `GamificacionService`, las pantallas `RecompensasScreen` y `MiImpactoScreen`, y los widgets de modal reutilizables `EcoPuntosModal` y `HitoRachaModal`. Este flujo también modificó la navegación de ambos roles: la pestaña de Perfil del menú inferior fue reemplazada por Recompensas, y el acceso al perfil (y desde ahí a Mi Impacto) pasó a un ícono en la cabecera de cada pantalla principal, mediante un componente común (`EcoAppBar`).

### 2.4 Flujo 4 — Coordinación y seguimiento del retiro

Este flujo se diseñó para reducir la incertidumbre del ciudadano entre que su solicitud es aceptada y que el material efectivamente se retira, complementando el Flujo 2 (que ya resolvía la aceptación y el cierre técnico del retiro) con una experiencia de seguimiento más informativa del lado del Ciudadano.

El diseño definió cuatro pantallas: selección de una franja horaria de entrega, confirmación del retiro con los datos del recolector asignado, una vista de seguimiento con una línea de tiempo de cuatro estados (solicitud aceptada, horario confirmado, en camino, material recogido) en lugar de un rastreo GPS en tiempo real —descartado por no ser viable con el alcance del proyecto—, y una pantalla final de cierre. Esta última pantalla tuvo una iteración de diseño documentada explícitamente: la versión inicial pedía al ciudadano confirmar que el retiro se había realizado correctamente antes de acreditar los EcoPuntos: se rediseñó para eliminar ese paso de validación, dado que la acreditación ya ocurre automáticamente en el momento en que el Recolector marca el retiro como completado (Flujo 2/3). La pantalla final quedó así como una vista de cierre informativo y calificación opcional del recolector, sin ninguna acción que condicione la entrega de los puntos.

Este flujo se resolvió principalmente a nivel de diseño e interacción, reutilizando los datos y estados que ya expone la API de `solicitudes` (aceptación, estado de la asignación) y el flujo de eventos pendientes del Flujo 3 para el enlace hacia la celebración de EcoPuntos, sin requerir nuevos modelos de backend.

### 2.5 Flujo 5 — Inicio de sesión, registro y recuperación de contraseña

El último flujo desarrollado atendió un caso de uso transversal a ambos roles: qué ocurre cuando un usuario olvida su contraseña. Se optó por el estándar de la industria — un código de un solo uso (OTP) enviado por correo electrónico — en lugar de un esquema de pregunta de seguridad, evitando así requerir cambios en el formulario de registro existente más allá de asegurar que el campo de correo fuera obligatorio y único.

El diseño, esta vez producido en Figma, definió cinco pantallas: solicitud del código a partir del usuario o correo, verificación del código de seis dígitos con temporizador de expiración y reenvío, definición de la nueva contraseña, una pantalla de contingencia por WhatsApp para el caso borde de un usuario sin acceso a su correo, y una confirmación final de éxito. Un criterio de seguridad se mantuvo en todo el flujo: nunca revelar si un usuario o correo existe en el sistema, respondiendo siempre con el mismo mensaje de éxito independientemente del resultado real.

En el backend, se extendió la app `roles` (por ser parte del mismo dominio de autenticación que ya cubre el registro, sin justificar una app nueva) con el modelo `CodigoRecuperacion`, que almacena el código únicamente en forma de hash, con expiración, límite de intentos fallidos y marca de uso. El servicio de recuperación emite, tras verificar el código correctamente, un token firmado de corta duración que autoriza exclusivamente el cambio de contraseña, evitando que ese paso pueda alcanzarse sin haber pasado la verificación. Se añadió limitación de tasa (`throttling`) nativa de Django REST Framework tanto para la solicitud como para la verificación del código, y el envío de correos se configuró sobre el backend de consola de Django para el entorno de desarrollo. En el frontend, se implementó un componente reutilizable de seis casillas para el ingreso del código OTP (`OtpInput`), con avance automático de foco y soporte para pegar el código completo copiado del correo, y las cinco pantallas correspondientes bajo `screens/recuperacion/`, enlazadas desde un nuevo acceso "¿Olvidaste tu contraseña?" en la pantalla de inicio de sesión.

Durante la implementación de este flujo se identificó y corrigió una falla de seguridad que el propio plan había señalado como riesgo conocido: el token de reseteo no quedaba invalidado tras su primer uso, lo que permitía cambiar la contraseña dos veces con el mismo token dentro de su ventana de vigencia. Se corrigió agregando una marca explícita de token consumido, verificada antes de autorizar cualquier cambio de contraseña, y se cubrió el caso con una prueba automatizada específica.

---

## 3. Conclusión

El desarrollo de Reciclalo se organizó como una secuencia de cinco flujos incrementales, cada uno documentado primero como una decisión de diseño de producto (prompt de diseño y prototipo de interfaz) y luego como una decisión técnica (plan de implementación de backend y frontend), antes de escribir código de producción. Este orden permitió mantener los dos roles de la aplicación — Ciudadano/Comercio y Recolector/Operador — coherentes entre sí en todo momento, y acotar explícitamente el alcance del producto dejando fuera, de manera consciente, la clasificación automática de material, los pagos digitales, el chat interno y la integración con sistemas municipales de aseo, tal como se definió desde el planteamiento inicial del problema.
