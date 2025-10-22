# Identificador de Plagas y Enfermedades del Café 🍃

Un asistente inteligente para el monitoreo y diagnóstico de cultivos de café. Esta aplicación web y móvil permite a los productores tomar fotos de las hojas de sus plantas y recibir un diagnóstico instantáneo basado en inteligencia artificial, junto con recomendaciones de tratamiento.

## ✨ Características Principales

### Para Productores (Usuarios) 🧑‍🌾
* **Autenticación Completa**: Registro seguro (con foto de perfil), inicio de sesión y gestión de perfil (actualizar nombre, contraseña y eliminar cuenta).
* **Análisis con IA**: Sube una foto del frente y (opcionalmente) del reverso de una hoja para obtener un diagnóstico.
* **Resultados Detallados**: Visualiza el diagnóstico, el nivel de confianza y los tratamientos recomendados en una vista detallada.
* **Historial de Análisis**: Revisa todos tus diagnósticos pasados en una galería personal.
* **Papelera de Reciclaje**: "Elimina" análisis de forma segura (borrado lógico) y restáuralos o elimínalos permanentemente.
* **Guía de Enfermedades**: Una guía de referencia visual para consultar todas las plagas y enfermedades que la app puede reconocer, junto con sus detalles y tratamientos.
* **Exportación a PDF**: Genera una ficha técnica en PDF para cualquier enfermedad de la guía o para un análisis específico.
* **Tema Claro/Oscuro**: Soporte completo para modos de visualización claro y oscuro.

### Para Administradores 👨‍💼
* **Panel de Administrador**: Un dashboard central para acceder a funciones de gestión.
* **Monitor de Productores**: Visualiza a todos los usuarios registrados, ve sus historiales de análisis individuales, restablece sus contraseñas o elimínalos permanentemente.
* **Monitor de Análisis Global**: Revisa *todos* los análisis enviados por *todos* los usuarios en un solo lugar.
* **Gestión de Tratamientos**: Edita la información de las enfermedades (descripción, prevención, riesgo) y gestiona (añade, edita, elimina) las recomendaciones de tratamiento asociadas a cada una.

---

## 🛠️ Stack Tecnológico

* **Backend 🐍**: **Python** con **Flask** para la API REST.
* **Frontend 📱**: **Flutter** (Dart) para una aplicación web y móvil multiplataforma.
* **Base de Datos 🐘**: **PostgreSQL** para almacenar datos de usuarios, análisis y tratamientos.
* **IA / Machine Learning 🤖**: **Roboflow** para el modelo de detección de objetos (enfermedades).
* **Cloud y Almacenamiento ☁️**:
    * **Firebase Storage**: Para alojar todas las imágenes subidas (perfil, análisis, enfermedades).
    * **Firebase Admin SDK**: Usado en el backend para gestionar el almacenamiento.

---

## 📁 Módulos del Proyecto

El proyecto está dividido en dos componentes principales: `backend` y `frontend`.

### 🚀 Backend (`identificador_plagas/backend/`)

El servidor Flask que actúa como el cerebro de la aplicación.

| Archivo | Descripción |
| :--- | :--- |
| **`app.py`** | 🟢 **Archivo Principal**. Define todas las rutas de la API REST, maneja la lógica de negocio, la autenticación (JWT), y se comunica con la base de datos, Roboflow y Firebase. |
| **`config.py`** | ⚙️ Gestiona la carga de variables de entorno (claves de API, credenciales de BD) desde el archivo `.env`. |
| **`requirements.txt`** | 📦 Lista de todas las dependencias de Python necesarias para el backend (Flask, psycopg2, firebase-admin, roboflow, etc.). |
| **`cleanup_script.py`** | 🧹 Un script programable (cron job) que elimina permanentemente los análisis de la papelera que tengan más de 30 días, limpiando la BD y Firebase Storage. |
| **`serviceAccountKey.json`** | 🔑 Clave privada de Firebase Admin SDK. **¡NUNCA debe ser pública!** (Está en `.gitignore`). |
| **`.env`** | 🔒 Archivo de configuración local para variables de entorno. **¡NUNCA debe ser público!** |

### 🎨 Frontend (`identificador_plagas/frontend/`)

La aplicación Flutter multiplataforma que los usuarios ven y con la que interactúan.

| Carpeta / Archivo | Descripción |
| :--- | :--- |
| **`main.dart`** | 🟢 **Archivo Principal**. Punto de entrada de la app. Configura los `Providers` (Tema, Autenticación) e inicia el `MainLayout`. |
| **`lib/screens/`** | 📱 Contiene todas las pantallas (vistas) de la aplicación. |
| `auth_check_screen.dart` | 🔐 Pantalla inicial que comprueba si el usuario tiene un token válido y redirige a `LoginScreen` o `DashboardScreen`. |
| `login_screen.dart` | ➡️ Pantalla de inicio de sesión. |
| `register_screen.dart` | 🆕 Pantalla de registro de nuevos usuarios. |
| `dashboard_screen.dart` | 🏠 El dashboard principal del usuario, con bienvenida y análisis recientes. |
| `detection_screen.dart` | 📷 La pantalla clave para subir imágenes y ejecutar el análisis de IA. |
| `analysis_detail_screen.dart` | 📊 Un modal que muestra el resultado detallado de un análisis. |
| `history_screen.dart` | 📚 Galería con todo el historial de análisis del usuario. |
| `trash_screen.dart` | 🗑️ Muestra los análisis "eliminados" (borrado lógico) y permite restaurarlos o borrarlos permanentemente. |
| `dose_calculation_screen.dart` | 📖 **(Guía de Enfermedades)**. Una guía de referencia que lista todas las enfermedades y sus tratamientos. |
| `edit_profile_screen.dart` | 👤 Pantalla para que el usuario edite su perfil, contraseña o elimine su cuenta. |
| `admin_dashboard_screen.dart` | 👑 Panel de control para administradores. |
| `admin_user_list_screen.dart` | 👥 (Admin) Lista de todos los usuarios y sus conteos de análisis. |
| `manage_recommendations_screen.dart` | ✏️ (Admin) Pantalla para seleccionar qué enfermedad/plaga editar. |
| `edit_recommendations_screen.dart` | 📝 (Admin) Formulario para editar los detalles y tratamientos de una enfermedad. |
| **`lib/services/`** | 🔌 Contiene la lógica para comunicarse con el backend y servicios externos. |
| `auth_service.dart` | 🔑 Maneja todas las llamadas a la API para registro, login, gestión de perfil y almacenamiento seguro de tokens. |
| `detection_service.dart` | 🧠 Gestiona las llamadas a la API para análisis, historial, papelera y datos del panel de admin. |
| `storage_service.dart` | 💾 Sube imágenes directamente a Firebase Storage (para análisis, perfil, etc.). |
| `treatment_service.dart` | 💊 Obtiene los datos para la Guía de Enfermedades. |
| **`lib/widgets/`** | 🧩 Componentes reutilizables de la interfaz de usuario. |
| `top_navigation_bar.dart` | 🗺️ La barra de navegación superior, responsiva (menú de hamburguesa en móvil). |
| `main_layout.dart` | 🏗️ El layout base de la app que contiene el fondo animado y el navegador anidado para las pantallas principales. |
| `animated_bubble_background.dart` | ✨ El fondo de burbujas borrosas y animadas que se usa en toda la app. |
| `disclaimer_widget.dart` | ⚠️ Un widget de advertencia reutilizable sobre la precisión de la IA. |
| **`lib/config/`** | 🎨 Configuración global de la aplicación. |
| `app_theme.dart` | 🎨 Define las paletas de colores y `ThemeData` para los modos claro y oscuro. |
| `theme_provider.dart` | 🌗 Gestiona el estado del tema (claro/oscuro) y lo guarda en `SharedPreferences`. |
| **`firebase_options.dart`** | 🔥 Archivo de configuración generado por FlutterFire para conectar la app con Firebase. |

---

## 🚀 Instalación y Ejecución

### Backend (Python)
1.  **Clonar el repositorio** (si aún no lo has hecho).
2.  **Navegar a la carpeta del backend**:
    ```bash
    cd identificador_plagas/backend
    ```
3.  **Crear un entorno virtual**:
    ```bash
    python -m venv venv
    ```
4.  **Activar el entorno virtual**:
    * Windows: `venv\Scripts\activate`
    * macOS/Linux: `source venv/bin/activate`
5.  **Instalar dependencias**:
    ```bash
    pip install -r requirements.txt
    ```
6.  **Configurar variables de entorno**:
    * Copia el contenido de `.env` y pégalo en un nuevo archivo llamado `.env`.
    * Añade tus credenciales de **PostgreSQL**, tu clave secreta (`SECRET_KEY`) y tus claves de **Roboflow** (`ROBOFLOW_API_KEY`, `ROBOFLOW_MODEL_ID`).
    * Asegúrate de tener tu `serviceAccountKey.json` en la raíz de `/backend` (o ajusta la ruta en `app.py`).
7.  **Ejecutar el servidor**:
    ```bash
    flask run
    ```
    *El servidor estará corriendo en `http://127.0.0.1:5001` (o el puerto que hayas configurado).*

### Frontend (Flutter)
1.  **Asegurarse de tener Flutter SDK instalado.**
2.  **Navegar a la carpeta del frontend**:
    ```bash
    cd identificador_plagas/frontend
    ```
3.  **Obtener dependencias de Flutter**:
    ```bash
    flutter pub get
    ```
4.  **Configurar la IP del backend**:
    * Abre los archivos en `lib/services/` (ej: `auth_service.dart`, `detection_service.dart`, etc.).
    * Cambia la variable `_baseUrl` por la IP de tu máquina donde corre el backend (ej: `http://192.168.1.10:5001`). **No uses `localhost` o `127.0.0.1` si pruebas en un dispositivo móvil real.**
5.  **Ejecutar la aplicación**:
    ```bash
    flutter run -d chrome
    ```
    *(Puedes reemplazar `chrome` por el ID de tu emulador o dispositivo móvil).*

---
## 🔐 Variables de Entorno (Backend)

Tu archivo `.env` en el backend debe contener las siguientes claves (basado en el archivo `.env` proporcionado):

```ini
# Clave secreta para firmar tokens JWT (pon algo seguro)
SECRET_KEY="1234"

# Credenciales de la Base de Datos PostgreSQL
DB_USER="postgres"
DB_PASSWORD="1234"
DB_HOST="localhost"
DB_PORT="5432"
DB_NAME="plagas_cafe_db"

# Credenciales de Roboflow
ROBOFLOW_API_KEY="FvvoZN66uiSxoq4rLQQ7"
ROBOFLOW_MODEL_ID="plagas-enfermedades-ba8sa/3"

# (Opcional) Si usas Render para producción
# DATABASE_URL="postgresql://user:password@host/db"
