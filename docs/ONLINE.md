# Modo online

Objetivo: que el alumnado juegue carreras entre sí en un servidor propio, con cuentas, y que el profesor administre y vea quién está conectado.

## Decisiones

- **Cliente:** el juego de escritorio (Godot) con un menú "Jugar solo" u "Online". No hay versión web del juego, para no cargar el servidor.
- **Netcode:** cada cliente simula **su** coche y envía su estado; el servidor lo retransmite y **valida** checkpoints y tiempos de meta. Los coches remotos se interpolan. Un alumno podría falsear su posición; en un aula se acepta, pero la meta y los tiempos las valida el servidor.
- **Sala:** una carrera arranca cuando hay 5 jugadores en espera.
- **Servidor:** repo aparte, `mini-bolidos-server` (Python/FastAPI, React + TypeScript con Vite, MariaDB, MongoDB, Redis, todo en Docker). Se desarrolla en local y se despliega con rsync en `75enguiem:/home/guillem/code/mini-bolidos-server`.
- **Publicación:** la gestiona el profesor (dominio `bolidos.enguillem.es`, HTTPS). El servidor solo expone el puerto del frontend (nginx), que enruta `/api` y `/ws` al backend. Las bases de datos y el backend no publican puertos.
- **MongoDB 4.4:** la VM de `75enguiem` no expone AVX y MongoDB 5+ no arranca. Se usa `mongo:4.4` (fin de vida, sin puerto publicado y solo en la red privada de Docker). Si se activa el CPU "host" en el hipervisor, basta cambiar `MONGO_IMAGE` en el `.env` del servidor.
- **Correo:** Gmail por SMTP con contraseña de aplicación en `.env` (nunca en el repo).

## Qué guarda cada base de datos

| Servicio | Para qué |
|---|---|
| MariaDB | Cuentas, tokens de activación y recuperación, carreras, resultados y estadísticas |
| Redis | Sesiones revocables, presencia (quién está conectado), límites de intentos de login, colas y salas |
| MongoDB | Registro de auditoría de acciones de administración; telemetría y repeticiones de carreras (M9) |

## Reglas de seguridad

- Contraseñas con Argon2. Nunca se guardan ni se registran en claro.
- La cuenta no entra hasta activar el correo.
- Los tokens de activación y recuperación se guardan con hash y caducan.
- Límite de intentos en registro y login (por IP y por usuario).
- Sesiones en Redis: el administrador puede expulsar a un usuario revocando su sesión.
- Secretos solo en `.env` (permisos 600) fuera de git.

## Privacidad

Se guardan nombre de usuario, correo y resultados de alumnado, a veces menor de edad. Antes de abrirlo al grupo hay que revisarlo con el centro (consentimiento, plazo de conservación, derecho de borrado). Hay un endpoint para borrar la propia cuenta.

## Protocolo (borrador, se concreta en M9)

WebSocket único `/ws?token=…` por usuario. Mensajes JSON `{"t": "<tipo>", ...}`:

- cliente → servidor: `queue_join`, `queue_leave`, `state` (posición, ángulo, velocidad, checkpoint), `finish`
- servidor → cliente: `lobby` (jugadores en espera), `start` (semilla, pista, parrilla, cuenta atrás), `states` (estado de todos), `results`
