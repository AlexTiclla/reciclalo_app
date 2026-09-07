Para complementar los flujos de publicación y recolección a domicilio de tu aplicación de reciclaje, el tercer flujo esencial debe enfocarse en la **fidelización, trazabilidad e incentivos (Gamificación y Economía Circular)**. Esto cierra el ciclo para el usuario generador y asegura la sostenibilidad del modelo.

### Flujo 3: Acumulación de Puntos, Recompensas e Impacto Ambiental (Gamificación)

* **Paso 1 (Validación y Pesaje):** Una vez que el reciclador pasa a recoger el producto (Flujo 2), este confirma en su aplicación el tipo de material entregado y el peso exacto (o volumen).
* **Paso 2 (Acreditación de Beneficios):** El sistema calcula automáticamente la equivalencia y abona puntos (ej. *EcoPuntos*) o saldo digital en la billetera del usuario.
* **Paso 3 (Canje de Incentivos):** El usuario ingresa a la sección de "Recompensas" de la app para canjear sus puntos por descuentos en comercios aliados, pago de servicios o productos eco-amigables.
* **Paso 4 (Métricas de Impacto y Racha de Constancia):** El usuario visualiza en su perfil un panel de control con su huella de carbono evitada (ej. *"Has ahorrado X kg de CO2 y Y litros de agua este mes"*), fomentando el hábito y la compartición en redes sociales. En el mismo panel se muestra su **racha de constancia**: semanas consecutivas en las que tuvo actividad real de reciclaje, junto a sus protectores de racha disponibles y su racha máxima histórica.

### Mecánica de racha y protectores

La racha aplica **por rol**, de forma independiente: un mismo usuario que participa como Ciudadano y como Recolector acumula dos rachas separadas, cada una con sus propios protectores.

* **Unidad de la racha:** semana calendario (lunes a domingo). Una semana cuenta como "cumplida" si:
  * **Ciudadano:** tuvo al menos una `SolicitudRetiro` propia marcada `completada` en esa semana.
  * **Recolector:** completó (acción `completar`) al menos una `AsignacionRetiro` en esa semana.
* **Racha actual:** número de semanas cumplidas consecutivas hasta la semana en curso. Se recomienda calcularla bajo demanda a partir de las fechas de `completada`, no como contador acumulado, para que nunca quede desincronizada del historial real.
* **Racha máxima:** la racha más alta que el usuario haya alcanzado alguna vez; se conserva aunque la racha actual se reinicie, y se muestra como logro permanente.
* **Protectores de racha:** cada usuario recibe **2 protectores por rol al inicio de cada mes calendario**. No se pueden comprar ni canjear con EcoPuntos, y **no se acumulan de un mes a otro** — cada mes vuelve a partir de 2, sin importar cuántos quedaron sin usar.
* **Consumo automático:** si una semana termina sin actividad y quedan protectores disponibles, el sistema consume uno automáticamente (sin acción del usuario) y la racha no se rompe. Se notifica al usuario, ej. *"Usamos un protector de racha esta semana 🛡️"*. Si la semana termina vacía y no quedan protectores, la racha actual vuelve a 0 (la racha máxima no se ve afectada).

### Hitos de racha y EcoPuntos

Alcanzar ciertas rachas otorga un bono único de EcoPuntos (no repetible dentro de la misma racha), acreditado igual que en el Paso 2 pero con un tipo de transacción distinto (ej. `bono_racha`) para diferenciarlo en el historial de puntos de las recompensas por peso/material reciclado.

Un Recolector completa retiros con mucha más frecuencia que un Ciudadano publica y recibe recolecciones, así que "cumplir la semana" le resulta más fácil. Para no inflar la economía de puntos, el Recolector usa una tabla propia con bonos más bajos por hito; el Ciudadano conserva la tabla original:

#### Tabla Ciudadano

| Racha alcanzada | Bono EcoPuntos |
| --- | --- |
| 2 semanas seguidas | +10 |
| 4 semanas (≈1 mes) | +25 |
| 8 semanas | +50 |
| 12 semanas | +75 |
| 26 semanas | +150 |
| 52 semanas | +300 |

#### Tabla Recolector

| Racha alcanzada | Bono EcoPuntos |
| --- | --- |
| 2 semanas seguidas | +5 |
| 4 semanas (≈1 mes) | +12 |
| 8 semanas | +25 |
| 12 semanas | +40 |
| 26 semanas | +75 |
| 52 semanas | +150 |

Estos bonos se suman al saldo de EcoPuntos canjeable en el Paso 3 (Canje de Incentivos), que también está disponible para el Recolector — ambos roles acumulan y canjean EcoPuntos por descuentos en comercios aliados, pago de servicios o productos eco-amigables.

### Notificación del hito

El modal **no** aparece cada semana que se extiende la racha — eso saturaría al usuario, porque una racha activa suma una semana casi todo el tiempo. Aparece únicamente cuando la racha cruza uno de los umbrales de la tabla de hitos (2, 4, 8, 12, 26 o 52 semanas). Una semana que solo extiende la racha sin llegar a un hito se refleja de forma silenciosa en el contador del panel de Paso 4, sin interrumpir al usuario.

Al alcanzarse un hito, la app muestra el modal en el momento en que se detecta el cumplimiento (por ejemplo, al abrir la app o al completarse la acción que cierra esa semana), con la racha alcanzada, el bono de EcoPuntos otorgado y un llamado a la acción hacia "Recompensas" (Paso 3) para canjearlo.
