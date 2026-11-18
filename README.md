# Lapticon

App Android en Flutter para la API de Lapticon: quien necesita enviar algo publica una
encomienda, y quien ya va a viajar la lleva.

Backend: <https://lapticon-backend.onrender.com> ·
Docs: <https://lapticon-backend.onrender.com/api-docs/>

## Cómo correrla

Requiere Flutter 3.47 o superior y el SDK de Android.

```powershell
# Conectada al backend real
flutter run --dart-define-from-file=config/firebase.json

# Modo demo: datos en memoria, sin red ni Firebase
flutter run --dart-define=DEMO=true

# APK
flutter build apk --dart-define-from-file=config/firebase.json
```

`config/firebase.json` no se sube a git. Para crearlo, copia `config/firebase.example.json`
y pon la clave web de Firebase. Debe ser la del proyecto `lapticon-eba31`: el backend solo
acepta tokens de ese proyecto.

En este equipo el SDK está en `D:\dev\flutter`, y `tool/flutter.ps1` lo usa con las cachés en
D:, sin tocar tu configuración global:

```powershell
.\tool\flutter.ps1 run --dart-define-from-file=config/firebase.json
```

El APK queda en `build/app/outputs/flutter-apk/app-release.apk`. Cubre teléfonos de 64 bits
(`--target-platform android-arm64,android-x64`) y va firmado con la clave de desarrollo: sirve
para instalar y probar, no para publicar en Play Store.

## Pruebas

```powershell
.	oollutter.ps1 test

# Solo lectura contra el backend real. Requiere config/test_account.json
.	oollutter.ps1 test test/live_api_test.dart --dart-define=LIVE=true
```

## Estructura

```text
lib/
  config/    Variables de compilación
  core/      Texto y formato: fechas, dinero, ciudades
  data/      Cliente HTTP, endpoints, modelos, Firebase y backend demo
  state/     Sesión y estado compartido
  theme/     Colores y tipografía
  widgets/   Componentes reutilizables
  features/  Pantallas por módulo
test/        Pruebas unitarias y recorridos de la app
```

## Particularidades del backend

La app ya contempla estos puntos, que no están en la documentación:

| Hallazgo | Cómo lo resuelve la app |
| --- | --- |
| El `server` del spec (`lapticon-backend-ed`) responde 404 | Usa `lapticon-backend` |
| La búsqueda distingue tildes: "Bogotá" da 0 resultados y "Bogota" trae los datos | Quita las tildes de toda ciudad antes de enviarla |
| Los catálogos mezclan variantes de una misma ciudad | Las une en el selector |
| `/ciudades` no incluye todas las ciudades (no aparece Madrid) | El selector permite filtrar por país |
| `fechaViaje` se guarda a medianoche UTC y en Colombia se vería un día antes | Se lee sin convertir a hora local |
| `/viajes/disponibles` no trae `_id`, `estado` ni `numeroVuelo` | Los modelos toleran campos ausentes |
| Render apaga el servidor por inactividad | Espera hasta 65 s y avisa que está despertando |
| Algunas conexiones se cortan | Reintenta GET, nunca POST ni PUT |
| `/vuelos` responde 500 porque falta `RAPIDAPI_KEY` | La verificación es opcional y no bloquea el registro |
| `cancelada` responde 400, aunque Postman dice que da 200 | Retirar una publicación la deja como `vencida` |
| El spec omite el estado `entregada` | Flujo: tomada, entregada (viajero), recibida (remitente) |
| `/encomiendas/disponibles` no trae `uid`, y `/buscar` incluye las propias | Usa `/buscar` y oculta las propias |
| El nombre del remitente viene como `remitenteNombre` | El modelo lee ese campo |
| `/chatbot` responde 500 porque la clave de OpenRouter del servidor es inválida | Avisa que el asistente no está disponible |

## Chat entre remitente y viajero

La API no tiene endpoints para enviar ni leer mensajes (solo `GET /api/chats/estado/{chatId}`),
así que el chat usa **Cloud Firestore** del mismo proyecto Firebase (`lapticon-eba31`). Cada
encomienda tomada tiene su conversación en `chats/{idEncomienda}`, con los mensajes en la
subcolección `mensajes`. Se abre desde el detalle de la encomienda ("Chatear con el viajero" o
"Chatear con el remitente") mientras está tomada, entregada o recibida.

Para activarlo, alguien con acceso a la consola de Firebase debe:

1. **Firestore Database → Crear base de datos** (modo producción, región cercana).
2. **Reglas:** pegar el contenido de `firestore.rules` y publicar. Solo los dos participantes
   leen y escriben su conversación, y nadie puede escribir a nombre de otro.
3. **Configuración del proyecto → Tus apps → Agregar app Android** con el paquete
   `com.lapticon.lapticon`, y poner el `App ID` que entrega en `FIREBASE_APP_ID` de
   `config/firebase.json`.

Mientras Firestore no esté activado, el chat muestra un aviso en lugar de fallar. En modo demo
funciona con mensajes en memoria y la otra persona responde sola.

## Limitaciones de la API

- **Contacto:** `GET /api/users/{uid}` solo funciona para el dueño, así que no se puede ver el
  teléfono de la otra persona.
- **Encomiendas tomadas:** no hay un listado general. Solo se consultan por ruta, y por eso se
  muestran en el detalle del viaje.
- **Detalle por id:** no hay `GET` de un viaje o una encomienda. El detalle usa el dato de la lista.

## Endpoints sin pantalla

| Endpoint | Motivo |
| --- | --- |
| `POST /encomiendas/actualizar-vencidas` | Es una tarea programada |
| `POST /encomiendas/evaluar-emparejamiento` | Requiere la reputación y días de diferencia como entrada, y `MATCHING_API_URL` en el servidor |
| `GET /encomiendas/vencidas` | Lista las de todos los usuarios; las propias ya salen en la lista |
| `GET /encomiendas/mis-encomiendas` | `GET /encomiendas` ya las incluye |
| `GET /encomiendas/disponibles` | `/encomiendas/buscar` trae lo mismo y además el `uid` |
| `GET /chats/estado/{chatId}` | No hay cómo obtener el `chatId` |
