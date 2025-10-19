# backend/app.py

from flask import Flask, request, jsonify
from flask_cors import CORS
import psycopg2
import psycopg2.extras
from psycopg2.extras import RealDictCursor
import bcrypt
import jwt
from datetime import datetime, timedelta
from functools import wraps
from config import Config
from roboflow import Roboflow
import os
import requests
from urllib.parse import unquote
import firebase_admin
from firebase_admin import credentials, storage
from PIL import Image # <-- 1. IMPORTAR LA LIBRERÍA
import time
import re #

try:
    cred = credentials.Certificate("serviceAccountKey.json")
    firebase_admin.initialize_app(cred, {
        'storageBucket': 'identificador-plagas-v2.firebasestorage.app'
    })
except Exception as e:
    print(f"Error inicializando Firebase Admin: {e}")

origins = [
    re.compile(r"http://localhost:.*"), # <-- 2. PERMITE CUALQUIER PUERTO EN LOCALHOST
    "https://identificador-plagas-v2.web.app"
]

app = Flask(__name__)
app.config.from_object(Config)
# Configuración de CORS
CORS(
    app,
    resources={r"/*": {"origins": origins}},
    supports_credentials=True,
    allow_headers=["Authorization", "Content-Type", "x-access-token"]
)

def get_db_connection():
    conn = psycopg2.connect(app.config['DATABASE_URI'])
    return conn

# --- Rutas de Autenticación (sin cambios) ---
# backend/app.py

@app.route('/register', methods=['POST'])
def register():
    data = request.get_json()
    nombre_completo = data.get('nombre_completo')
    email = data.get('email').lower()
    password = data.get('password')
    ong = data.get('ong')
    # --- 👇 NUEVA LÍNEA ---
    profile_image_url = data.get('profile_image_url') # Puede ser nulo si no suben foto

    if not all([nombre_completo, email, password]):
        return jsonify({"error": "Faltan datos requeridos"}), 400

    hashed_password = bcrypt.hashpw(password.encode('utf-8'), bcrypt.gensalt())

    try:
        conn = get_db_connection()
        cur = conn.cursor()
        # --- 👇 MODIFICACIÓN EN LA CONSULTA SQL ---
        cur.execute(
            "INSERT INTO usuarios (nombre_completo, email, password_hash, ong, profile_image_url) VALUES (%s, %s, %s, %s, %s)",
            (nombre_completo, email, hashed_password.decode('utf-8'), ong, profile_image_url)
        )
        conn.commit()
        cur.close()
        conn.close()
        return jsonify({"message": "Usuario registrado exitosamente"}), 201
    except psycopg2.IntegrityError:
        return jsonify({"error": "El correo electrónico ya está registrado"}), 409
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/login', methods=['POST'])
def login():
    data = request.get_json()
    email = data.get('email')
    password = data.get('password')

    if not email or not password:
        return jsonify({"error": "Email y contraseña son requeridos"}), 400

    try:
        conn = get_db_connection()
        cur = conn.cursor(cursor_factory=psycopg2.extras.DictCursor)
        # backend/app.py -> en la función login()
        cur.execute("SELECT id_usuario, password_hash, es_admin, nombre_completo FROM usuarios WHERE LOWER(email) = LOWER(%s)", (email,))
        user = cur.fetchone()
        cur.close()
        conn.close()

        if not user:
            return jsonify({"error": "Credenciales inválidas"}), 401

        if bcrypt.checkpw(password.encode('utf-8'), user['password_hash'].encode('utf-8')):
            token = jwt.encode({
                'user_id': user['id_usuario'],
                'es_admin': user['es_admin'],
                'exp': datetime.utcnow() + timedelta(hours=24)
            }, app.config['SECRET_KEY'], algorithm="HS256")

            # Devolvemos el token Y el rol de administrador
            return jsonify({
                "token": token,
                "es_admin": user['es_admin'],
                "nombre_completo": user['nombre_completo'] # <-- ¡AÑADIDO!
            }), 200
        else:
            return jsonify({"error": "Credenciales inválidas"}), 401

    except Exception as e:
        return jsonify({"error": str(e)}), 500


def token_required(f):
    # ... (código sin cambios)
    @wraps(f)
    def decorated(*args, **kwargs):
        token = None
        if 'x-access-token' in request.headers:
            token = request.headers['x-access-token']
        
        if not token:
            return jsonify({'message': 'Falta el token de autenticación'}), 401
        
        try:
            data = jwt.decode(token, app.config['SECRET_KEY'], algorithms=["HS256"])
            current_user_id = data['user_id']
        except:
            return jsonify({'message': 'El token es inválido o ha expirado'}), 401
        
        return f(current_user_id, *args, **kwargs)
    return decorated

def admin_required(f):
    @wraps(f)
    def decorated(*args, **kwargs):
        token = None
        if 'x-access-token' in request.headers:
            token = request.headers['x-access-token']

        if not token:
            return jsonify({'message': 'Falta el token de autenticación'}), 401

        try:
            data = jwt.decode(token, app.config['SECRET_KEY'], algorithms=["HS256"])
            current_user_id = data['user_id']
            # Verificamos si la clave 'es_admin' está y si es verdadera
            if not data.get('es_admin'):
                return jsonify({'message': 'Acceso denegado. Se requieren permisos de administrador.'}), 403 # 403 Forbidden
        except:
            return jsonify({'message': 'El token es inválido o ha expirado'}), 401

        # Pasamos el user_id como en token_required, por si lo necesitamos
        return f(current_user_id, *args, **kwargs)
    return decorated    
    
def _run_prediction(image_url):
    temp_image_path = "temp_image.jpg"
    try:
        # --- MEDIMOS EL TIEMPO DE DESCARGA ---
        start_download = time.time()
        response = requests.get(image_url, stream=True)
        response.raise_for_status()
        with open(temp_image_path, 'wb') as f:
            f.write(response.content)
        end_download = time.time()
        print(f"✅ Tiempo de descarga de imagen: {end_download - start_download:.2f} segundos")

        # --- MEDIMOS EL TIEMPO DE PREDICCIÓN DE ROBOFLOW ---
        start_prediction = time.time()
        rf = Roboflow(api_key=app.config['ROBOFLOW_API_KEY'])
        project_id, version_id = app.config['ROBOFLOW_MODEL_ID'].split('/')
        project = rf.workspace().project(project_id)
        model = project.version(version_id).model
        
        prediction_result = model.predict(temp_image_path, confidence=40, overlap=30).json()
        end_prediction = time.time()
        print(f"🤖 Tiempo de predicción de Roboflow: {end_prediction - start_prediction:.2f} segundos")

        class_detected = "No se detectó ninguna plaga"
        confidence = 0.0
        if prediction_result.get('predictions'):
            top_pred = max(prediction_result['predictions'], key=lambda p: p['confidence'])
            class_detected = top_pred['class']
            confidence = top_pred['confidence']
        
        return {"prediction": class_detected, "confidence": confidence}

    finally:
        if os.path.exists(temp_image_path):
            os.remove(temp_image_path)



# backend/app.py

# EN: backend/app.py

@app.route('/analyze', methods=['POST'])
@token_required
def analyze_image(current_user_id):
    # --- ESTA FUNCIÓN AHORA ANALIZA, NO GUARDA ---
    total_start_time = time.time()
    data = request.get_json()
    image_url_front = data.get('image_url_front')
    image_url_back = data.get('image_url_back')

    if not image_url_front:
        return jsonify({"error": "La URL de la imagen del frente es requerida"}), 400

    try:
        print("\n--- Iniciando análisis (sin guardar) para el usuario:", current_user_id)
        
        result_front = _run_prediction(image_url_front)
        final_result = result_front

        if image_url_back:
            print("--- Procesando imagen del reverso ---")
            result_back = _run_prediction(image_url_back)
            
            is_front_disease = result_front['prediction'] not in ['No se detectó ninguna plaga', 'Hoja sana']
            is_back_disease = result_back['prediction'] not in ['No se detectó ninguna plaga', 'Hoja sana']

            if is_back_disease:
                final_result = result_back
            elif is_front_disease and not is_back_disease:
                final_result = result_front
            else:
                final_result = result_front if result_front['confidence'] >= result_back['confidence'] else result_back

        # --- 👇 INICIO DEL FILTRO DE VALIDACIÓN CORREGIDO 👇 ---

        MIN_CONFIDENCE_FOR_VALID_LEAF = 0.30 # Umbral del 30%

        prediction_text = final_result['prediction']
        prediction_confidence = final_result['confidence']
        is_valid_leaf = True

        # --- 👇 ¡AQUÍ ESTÁ LA CORRECCIÓN CLAVE! 👇 ---
        # ANTES (Incorrecto):
        # if prediction_text != 'No se detectó ninguna plaga' and prediction_confidence < MIN_CONFIDENCE_FOR_VALID_LEAF:
        
        # DESPUÉS (Correcto):
        # Ahora, si la predicción es "No se detectó..." O la confianza es muy baja, la consideramos inválida.
        if prediction_text == 'No se detectó ninguna plaga' or prediction_confidence < MIN_CONFIDENCE_FOR_VALID_LEAF:
            is_valid_leaf = False
            prediction_text = "Imagen no reconocida"
        
        # --- 👆 FIN DEL FILTRO DE VALIDACIÓN CORREGIDO 👆 ---

        total_end_time = time.time()
        print(f"⏱️ Tiempo total de la solicitud '/analyze': {total_end_time - total_start_time:.2f} segundos\n")

        response_data = {
            "prediction": prediction_text,
            "confidence": prediction_confidence,
            "is_valid_leaf": is_valid_leaf,
            "url_imagen": image_url_front,
            "url_imagen_reverso": image_url_back
        }

        return jsonify(response_data), 200

    except Exception as e:
        return jsonify({"error": f"Ocurrió un error durante el análisis: {str(e)}"}), 500

# --- 👇 ESTA ES LA NUEVA FUNCIÓN PARA GUARDAR 👇 ---
@app.route('/history/save', methods=['POST'])
@token_required
def save_analysis(current_user_id):
    data = request.get_json()
    
    # Extraemos todos los datos necesarios del cuerpo de la solicitud
    url_imagen = data.get('url_imagen')
    url_imagen_reverso = data.get('url_imagen_reverso')
    resultado_prediccion = data.get('prediction')
    confianza = data.get('confidence')

    if not all([url_imagen, resultado_prediccion, confianza is not None]):
        return jsonify({"error": "Faltan datos para guardar el análisis"}), 400

    try:
        conn = get_db_connection()
        cur = conn.cursor()
        
        cur.execute(
            """
            INSERT INTO analisis (id_usuario, url_imagen, url_imagen_reverso, resultado_prediccion, confianza, fecha_analisis)
            VALUES (%s, %s, %s, %s, %s, %s) RETURNING id_analisis;
            """,
            (current_user_id, url_imagen, url_imagen_reverso, resultado_prediccion, confianza, datetime.utcnow())
        )
        new_id = cur.fetchone()[0] # Obtenemos el ID del nuevo análisis guardado
        conn.commit()
        cur.close()
        conn.close()

        # Devolvemos el resultado completo con el nuevo ID, por si la app lo necesita
        response_data = {
            "id_analisis": new_id,
            "id_usuario": current_user_id,
            "url_imagen": url_imagen,
            "url_imagen_reverso": url_imagen_reverso,
            "resultado_prediccion": resultado_prediccion,
            "confianza": confianza
        }
        
        return jsonify(response_data), 201 # 201 Creado

    except Exception as e:
        return jsonify({"error": f"Error al guardar en la base de datos: {str(e)}"}), 500

@app.route('/disease/<string:roboflow_name>', methods=['GET'])
@token_required
def get_disease_details(current_user_id, roboflow_name):
    try:
        conn = get_db_connection()
        cur = conn.cursor(cursor_factory=psycopg2.extras.DictCursor)

        cur.execute("SELECT * FROM enfermedades WHERE roboflow_class = %s", (roboflow_name,))
        disease = cur.fetchone()

        if not disease:
            return jsonify({"error": "Enfermedad no encontrada"}), 404

        # Se seleccionan todas las columnas de la tabla de tratamientos
        cur.execute(
            "SELECT * FROM tratamientos WHERE id_enfermedad = %s",
            (disease['id_enfermedad'],)
        )
        treatments = cur.fetchall()

        cur.close()
        conn.close()
        
        response = {
            "info": dict(disease),
            "recommendations": [dict(t) for t in treatments]
        }
        
        return jsonify(response), 200

    except Exception as e:
        return jsonify({"error": f"Ocurrió un error al obtener los detalles: {str(e)}"}), 500

@app.route('/history', methods=['GET'])
@token_required
def get_history(current_user_id):
    try:
        conn = get_db_connection()
        cur = conn.cursor(cursor_factory=psycopg2.extras.DictCursor)
        
        # Seleccionamos todas las columnas necesarias, incluyendo la del reverso
        cur.execute(
            """SELECT 
               id_analisis, url_imagen, url_imagen_reverso, 
               resultado_prediccion, confianza, fecha_analisis 
               FROM analisis 
               WHERE id_usuario = %s AND fecha_eliminado IS NULL 
               ORDER BY fecha_analisis DESC""", 
            (current_user_id,)
        )
        
        history = cur.fetchall()
        cur.close()
        conn.close()
        
        results = []
        for row in history:
            # --- 👇 CAMBIO PRINCIPAL AQUÍ 👇 ---
            # Nos aseguramos de incluir TODAS las columnas en la respuesta JSON
            results.append({
                "id_analisis": row["id_analisis"],
                "url_imagen": row["url_imagen"],
                "url_imagen_reverso": row["url_imagen_reverso"], # <-- ¡Esta era la que faltaba!
                "resultado_prediccion": row["resultado_prediccion"],
                "confianza": row["confianza"],
                "fecha_analisis": row["fecha_analisis"].isoformat()
            })

        return jsonify(results), 200

    except Exception as e:
        return jsonify({"error": f"Ocurrió un error al obtener el historial: {str(e)}"}), 500
        return jsonify({"error": f"Ocurrió un error al obtener el historial: {str(e)}"}), 500

@app.route('/history/<int:analysis_id>', methods=['DELETE'])
@token_required
def delete_history_item(current_user_id, analysis_id):
    try:
        conn = get_db_connection()
        cur = conn.cursor(cursor_factory=psycopg2.extras.DictCursor)

        cur.execute(
            "SELECT url_imagen FROM analisis WHERE id_analisis = %s AND id_usuario = %s",
            (analysis_id, current_user_id)
        )
        item = cur.fetchone()

        if not item:
            cur.close()
            conn.close()
            return jsonify({"error": "Análisis no encontrado o no autorizado"}), 404

        cur.execute(
            "UPDATE analisis SET fecha_eliminado = NOW() AT TIME ZONE 'UTC' WHERE id_analisis = %s AND id_usuario = %s",
            (analysis_id, current_user_id)
        )
        conn.commit()
        cur.close()
        conn.close()

        return jsonify({"message": "Análisis borrado exitosamente"}), 200

    except Exception as e:
        return jsonify({"error": f"Ocurrió un error al borrar el análisis: {str(e)}"}), 500
    
@app.route('/admin/analysis/<int:analysis_id>', methods=['DELETE'])
@admin_required
def admin_delete_analysis(current_user_id, analysis_id):
    """
    Permite a un administrador mover cualquier análisis a la papelera,
    sin importar quién sea el propietario.
    """
    try:
        conn = get_db_connection()
        cur = conn.cursor()
        
        # Como es un admin, no necesitamos verificar el id_usuario
        cur.execute(
            "UPDATE analisis SET fecha_eliminado = NOW() AT TIME ZONE 'UTC' WHERE id_analisis = %s",
            (analysis_id,)
        )
        
        # Verificamos si se afectó alguna fila para saber si el análisis existía
        if cur.rowcount == 0:
            cur.close()
            conn.close()
            return jsonify({"error": "Análisis no encontrado"}), 404
            
        conn.commit()
        cur.close()
        conn.close()
        
        return jsonify({"message": "Análisis borrado por el administrador exitosamente"}), 200

    except Exception as e:
        return jsonify({"error": f"Ocurrió un error al borrar el análisis: {str(e)}"}), 500


@app.route('/history/trash', methods=['GET'])
@token_required
def get_trashed_history(current_user_id):
    try:
        conn = get_db_connection()
        cur = conn.cursor(cursor_factory=psycopg2.extras.DictCursor)
        
        cur.execute(
            "SELECT * FROM analisis WHERE id_usuario = %s AND fecha_eliminado IS NOT NULL ORDER BY fecha_eliminado DESC", 
            (current_user_id,)
        )
        
        history = cur.fetchall()
        results = [dict(row) for row in history]
        for r in results:
            if r.get('fecha_analisis'):
                r['fecha_analisis'] = r['fecha_analisis'].isoformat()
            if r.get('fecha_eliminado'):
                r['fecha_eliminado'] = r['fecha_eliminado'].isoformat()

        cur.close()
        conn.close()
        return jsonify(results), 200
    except Exception as e:
        return jsonify({"error": f"Ocurrió un error al obtener la papelera: {str(e)}"}), 500

@app.route('/history/<int:analysis_id>/restore', methods=['PUT'])
@token_required
def restore_history_item(current_user_id, analysis_id):
    try:
        conn = get_db_connection()
        cur = conn.cursor()
        cur.execute(
            "UPDATE analisis SET fecha_eliminado = NULL WHERE id_analisis = %s AND id_usuario = %s",
            (analysis_id, current_user_id)
        )
        conn.commit()
        cur.close()
        conn.close()
        return jsonify({"message": "Análisis restaurado exitosamente"}), 200
    except Exception as e:
        return jsonify({"error": f"Ocurrió un error al restaurar: {str(e)}"}), 500
    
@app.route('/admin/analysis/restore/<int:analysis_id>', methods=['PUT'])
@admin_required
def admin_restore_analysis(current_user_id, analysis_id):
    """
    Permite a un administrador restaurar cualquier análisis (quitarlo de la papelera),
    sin importar quién sea el propietario.
    """
    try:
        conn = get_db_connection()
        cur = conn.cursor()
        
        # Simplemente quitamos la fecha de eliminado, sin verificar el propietario
        cur.execute(
            "UPDATE analisis SET fecha_eliminado = NULL WHERE id_analisis = %s",
            (analysis_id,)
        )
        
        if cur.rowcount == 0:
            cur.close()
            conn.close()
            return jsonify({"error": "Análisis no encontrado"}), 404
            
        conn.commit()
        cur.close()
        conn.close()
        
        return jsonify({"message": "Análisis restaurado por el administrador exitosamente"}), 200

    except Exception as e:
        return jsonify({"error": f"Ocurrió un error al restaurar el análisis: {str(e)}"}), 500


@app.route('/admin/trash', methods=['GET'])
@admin_required
def get_admin_trashed_items(current_user_id):
    """
    Obtiene todos los análisis que han sido movidos a la papelera (eliminado lógicamente)
    de todos los usuarios.
    """
    try:
        conn = get_db_connection()
        # --- CAMBIO AQUÍ ---
        cur = conn.cursor(cursor_factory=RealDictCursor) # <-- AÑADE EL CURSOR FACTORY
        
        # Unimos la tabla de analisis con la de usuarios para obtener el email
        cur.execute("""
            SELECT a.*, u.email 
            FROM analisis a
            JOIN usuarios u ON a.id_usuario = u.id_usuario
            WHERE a.fecha_eliminado IS NOT NULL
            ORDER BY a.fecha_eliminado DESC
        """)
        
        trashed_items = cur.fetchall()
        cur.close()
        conn.close()
        
        # --- AÑADIMOS CONVERSIÓN DE FECHA PARA EVITAR ERRORES EN FLUTTER ---
        results = [dict(row) for row in trashed_items]
        for r in results:
            if r.get('fecha_analisis'):
                r['fecha_analisis'] = r['fecha_analisis'].isoformat()
            if r.get('fecha_eliminado'):
                r['fecha_eliminado'] = r['fecha_eliminado'].isoformat()

        return jsonify(results) # <-- Devolvemos los resultados formateados

    except Exception as e:
        return jsonify({"error": f"Ocurrió un error al obtener la papelera de administrador: {str(e)}"}), 500

@app.route('/history/<int:analysis_id>/permanent', methods=['DELETE'])
@token_required
def permanently_delete_item(current_user_id, analysis_id):
    try:
        conn = get_db_connection()
        cur = conn.cursor(cursor_factory=psycopg2.extras.DictCursor)

        # --- 1. OBTENER AMBAS URLs ANTES DE BORRAR ---
        cur.execute(
            "SELECT url_imagen, url_imagen_reverso FROM analisis WHERE id_analisis = %s AND id_usuario = %s",
            (analysis_id, current_user_id)
        )
        item_to_delete = cur.fetchone()

        if not item_to_delete:
            cur.close()
            conn.close()
            return jsonify({"error": "Análisis no encontrado"}), 404

        # --- 2. BORRAR EL REGISTRO DE LA BASE DE DATOS ---
        cur.execute("DELETE FROM analisis WHERE id_analisis = %s", (analysis_id,))
        conn.commit()
        cur.close()
        conn.close()

        # --- 3. BORRAR AMBAS IMÁGENES DE FIREBASE ---
        urls_to_delete = [item_to_delete['url_imagen'], item_to_delete['url_imagen_reverso']]

        for image_url in urls_to_delete:
            if image_url: # Solo si la URL existe
                try:
                    path_part = image_url.split('?')[0]
                    file_path = path_part.split('/o/')[-1].replace('%2F', '/')

                    bucket = storage.bucket()
                    blob = bucket.blob(file_path)

                    if blob.exists():
                        blob.delete()
                        print(f"Imagen {file_path} borrada permanentemente de Firebase Storage.")
                    else:
                        print(f"Imagen {file_path} no encontrada en Firebase, posiblementa ya fue borrada.")
                except Exception as e:
                    print(f"ADVERTENCIA: No se pudo borrar la imagen {image_url} de Firebase Storage: {e}")

        return jsonify({"message": "Análisis borrado permanentemente"}), 200

    except Exception as e:
        if 'conn' in locals() and conn:
            cur.close()
            conn.close()
        return jsonify({"error": f"Ocurrió un error en el borrado permanente: {str(e)}"}), 500
    
    
# backend/app.py

@app.route('/history/trash/empty', methods=['DELETE'])
@token_required
def empty_trash(current_user_id):
    try:
        conn = get_db_connection()
        cur = conn.cursor(cursor_factory=psycopg2.extras.DictCursor)

        # --- 1. OBTENER AMBAS URLs DE TODOS LOS ITEMS EN LA PAPELERA ---
        cur.execute(
            "SELECT url_imagen, url_imagen_reverso FROM analisis WHERE id_usuario = %s AND fecha_eliminado IS NOT NULL",
            (current_user_id,)
        )
        items_to_delete = cur.fetchall()

        # --- 2. BORRAR IMÁGENES DE FIREBASE ---
        if items_to_delete:
            print(f"Vaciando papelera para el usuario {current_user_id}. {len(items_to_delete)} items encontrados.")
            bucket = storage.bucket()
            for item in items_to_delete:
                # Crear lista con las dos URLs del item actual
                urls_to_process = [item['url_imagen'], item['url_imagen_reverso']]
                for image_url in urls_to_process:
                    if image_url: # Solo si la URL existe
                        try:
                            path_part = image_url.split('?')[0]
                            file_path = path_part.split('/o/')[-1].replace('%2F', '/')
                            blob = bucket.blob(file_path)
                            if blob.exists():
                                blob.delete()
                                print(f"Imagen {file_path} borrada de Firebase Storage al vaciar papelera.")
                        except Exception as e:
                            print(f"ADVERTENCIA: No se pudo borrar la imagen {image_url} de Firebase Storage: {e}")

        # --- 3. BORRAR REGISTROS DE LA BASE DE DATOS ---
        cur.execute(
            "DELETE FROM analisis WHERE id_usuario = %s AND fecha_eliminado IS NOT NULL",
            (current_user_id,)
        )
        conn.commit()

        cur.close()
        conn.close()

        return jsonify({"message": "La papelera ha sido vaciada exitosamente"}), 200

    except Exception as e:
        if 'conn' in locals() and conn:
            cur.close()
            conn.close()
        return jsonify({"error": f"Ocurrió un error al vaciar la papelera: {str(e)}"}), 500
    
    

@app.route('/calculate_dose', methods=['POST'])
@token_required
def calculate_dose(current_user_id):
    data = request.get_json()
    treatment_id = data.get('treatment_id')
    plant_count = data.get('plant_count')

    if not treatment_id or not plant_count:
        return jsonify({"error": "Faltan datos requeridos (ID de tratamiento y número de plantas)"}), 400

    try:
        plant_count = int(plant_count)
        if plant_count <= 0:
            return jsonify({"error": "El número de plantas debe ser mayor que cero"}), 400

        conn = get_db_connection()
        cur = conn.cursor(cursor_factory=psycopg2.extras.DictCursor)

        cur.execute(
            "SELECT dosis_por_planta_ml, agua_por_planta_ml FROM tratamientos WHERE id_tratamiento = %s",
            (treatment_id,)
        )
        treatment_data = cur.fetchone()
        cur.close()
        conn.close()

        if not treatment_data:
            return jsonify({"error": "Tratamiento no encontrado"}), 404
        
        dosis_producto = treatment_data.get('dosis_por_planta_ml')
        dosis_agua = treatment_data.get('agua_por_planta_ml')

        if dosis_producto is None or dosis_agua is None:
            return jsonify({"error": "Los datos de dosis para este tratamiento están incompletos en la base de datos."}), 400

        total_producto_ml = dosis_producto * plant_count
        total_agua_ml = dosis_agua * plant_count

        response = {
            "total_producto_ml": total_producto_ml,
            "total_agua_litros": total_agua_ml / 1000,
            "mensaje": f"Para tratar {plant_count} plantas, necesitas {total_producto_ml:.2f} ml de producto y {total_agua_ml / 1000:.2f} litros de agua."
        }
        
        return jsonify(response), 200

    except ValueError:
        return jsonify({"error": "El número de plantas debe ser un número entero"}), 400
    except Exception as e:
        return jsonify({"error": f"Ocurrió un error al calcular la dosis: {str(e)}"}), 500
    
# Endpoint para obtener TODAS las enfermedades
@app.route('/admin/diseases', methods=['GET'])
@admin_required
def get_all_diseases(current_user_id):
    try:
        conn = get_db_connection()
        cur = conn.cursor(cursor_factory=psycopg2.extras.DictCursor)
        cur.execute("SELECT id_enfermedad, nombre_comun, roboflow_class FROM enfermedades ORDER BY nombre_comun ASC")
        diseases = cur.fetchall()
        cur.close()
        conn.close()
        return jsonify([dict(row) for row in diseases]), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500

# --- NUEVO ENDPOINT PARA ACTUALIZAR UNA ENFERMEDAD ---
@app.route('/admin/disease/<int:disease_id>', methods=['PUT'])
@admin_required
def update_disease_details(current_user_id, disease_id):
    """
    Permite a un administrador actualizar los detalles de una enfermedad,
    incluyendo su imagen, tipo, prevención y riesgo.
    """
    data = request.get_json()
    if not data:
        return jsonify({"error": "No se recibieron datos para actualizar"}), 400

    # Campos que se pueden actualizar
    imagen_url = data.get('imagen_url')
    tipo = data.get('tipo')
    prevencion = data.get('prevencion')
    riesgo = data.get('riesgo')

    try:
        conn = get_db_connection()
        cur = conn.cursor(cursor_factory=psycopg2.extras.DictCursor)

        # Construimos la consulta dinámicamente para solo actualizar los campos que se envían
        query_parts = []
        params = []
        if imagen_url is not None:
            query_parts.append("imagen_url = %s")
            params.append(imagen_url)
        if tipo is not None:
            query_parts.append("tipo = %s")
            params.append(tipo)
        if prevencion is not None:
            query_parts.append("prevencion = %s")
            params.append(prevencion)
        if riesgo is not None:
            query_parts.append("riesgo = %s")
            params.append(riesgo)

        if not query_parts:
            return jsonify({"error": "No se enviaron campos válidos para actualizar"}), 400

        params.append(disease_id)
        
        query = f"UPDATE enfermedades SET {', '.join(query_parts)} WHERE id_enfermedad = %s RETURNING *;"
        
        cur.execute(query, tuple(params))
        
        updated_disease = cur.fetchone()
        
        if updated_disease is None:
            cur.close()
            conn.close()
            return jsonify({"error": "Enfermedad no encontrada"}), 404

        conn.commit()
        cur.close()
        conn.close()
        
        return jsonify(dict(updated_disease)), 200

    except Exception as e:
        return jsonify({"error": f"Ocurrió un error al actualizar la enfermedad: {str(e)}"}), 500

# --- NUEVO ENDPOINT PARA BORRAR UNA IMAGEN DE FIREBASE STORAGE ---
@app.route('/admin/storage/delete', methods=['POST'])
@admin_required
def delete_from_storage(current_user_id):
    """
    Recibe una URL de Firebase Storage y elimina el archivo correspondiente.
    """
    data = request.get_json()
    image_url = data.get('image_url')

    if not image_url:
        return jsonify({"error": "No se proporcionó URL de la imagen"}), 400

    try:
        # Extraemos la ruta del archivo desde la URL de Firebase
        # La ruta está después de '/o/' y antes del '?'
        path_part = image_url.split('?')[0]
        file_path = path_part.split('/o/')[-1].replace('%2F', '/')
        
        # Obtenemos el bucket de Firebase
        bucket = storage.bucket()
        blob = bucket.blob(file_path)

        # Verificamos si el archivo existe y lo borramos
        if blob.exists():
            blob.delete()
            print(f"Imagen {file_path} borrada permanentemente de Firebase Storage por un admin.")
            return jsonify({"message": "Imagen eliminada exitosamente de Firebase Storage"}), 200
        else:
            print(f"ADVERTENCIA: Se intentó borrar la imagen {file_path} pero no se encontró en Firebase.")
            # Devolvemos éxito aunque no existiera para no bloquear el frontend
            return jsonify({"message": "La imagen no fue encontrada en Firebase, posiblemente ya fue borrada."}), 200

    except Exception as e:
        print(f"ERROR: No se pudo borrar la imagen {image_url} de Firebase Storage: {e}")
        # Es importante no devolver un error 500 para que la app pueda continuar
        # actualizando la base de datos aunque el borrado del archivo falle.
        return jsonify({"error": f"Ocurrió un error al intentar borrar la imagen de Firebase: {str(e)}"}), 500


# Endpoint para AÑADIR una nueva recomendación a una enfermedad
@app.route('/admin/treatments', methods=['POST'])
@admin_required
def add_treatment(current_user_id):
    data = request.get_json()
    id_enfermedad = data.get('id_enfermedad')
    # Añadimos todos los campos que podría tener una recomendación
    nombre_comercial = data.get('nombre_comercial')
    ingrediente_activo = data.get('ingrediente_activo')
    tipo_tratamiento = data.get('tipo_tratamiento')
    dosis = data.get('dosis')
    frecuencia_aplicacion = data.get('frecuencia_aplicacion')
    notas_adicionales = data.get('notas_adicionales')

    if not id_enfermedad or not nombre_comercial or not ingrediente_activo:
        return jsonify({"error": "Faltan datos requeridos"}), 400

    try:
        conn = get_db_connection()
        cur = conn.cursor(cursor_factory=psycopg2.extras.DictCursor)
        cur.execute(
            """
            INSERT INTO tratamientos (id_enfermedad, nombre_comercial, ingrediente_activo, tipo_tratamiento, dosis, frecuencia_aplicacion, notas_adicionales)
            VALUES (%s, %s, %s, %s, %s, %s, %s) RETURNING *;
            """,
            (id_enfermedad, nombre_comercial, ingrediente_activo, tipo_tratamiento, dosis, frecuencia_aplicacion, notas_adicionales)
        )
        new_treatment = cur.fetchone()
        conn.commit()
        cur.close()
        conn.close()
        return jsonify(dict(new_treatment)), 201
    except Exception as e:
        return jsonify({"error": str(e)}), 500

# Endpoint para MODIFICAR una recomendación existente
@app.route('/admin/treatments/<int:treatment_id>', methods=['PUT'])
@admin_required
def update_treatment(current_user_id, treatment_id):
    data = request.get_json()

    try:
        conn = get_db_connection()
        cur = conn.cursor(cursor_factory=psycopg2.extras.DictCursor)
        cur.execute(
            """
            UPDATE tratamientos SET
                nombre_comercial = %s,
                ingrediente_activo = %s,
                tipo_tratamiento = %s,
                dosis = %s,
                frecuencia_aplicacion = %s,
                notas_adicionales = %s
            WHERE id_tratamiento = %s RETURNING *;
            """,
            (
                data.get('nombre_comercial'), data.get('ingrediente_activo'),
                data.get('tipo_tratamiento'), data.get('dosis'),
                data.get('frecuencia_aplicacion'), data.get('notas_adicionales'),
                treatment_id
            )
        )
        updated_treatment = cur.fetchone()
        conn.commit()
        cur.close()
        conn.close()
        if updated_treatment:
            return jsonify(dict(updated_treatment)), 200
        return jsonify({"error": "Tratamiento no encontrado"}), 404
    except Exception as e:
        return jsonify({"error": str(e)}), 500

# Endpoint para ELIMINAR una recomendación
@app.route('/admin/treatments/<int:treatment_id>', methods=['DELETE'])
@admin_required
def delete_treatment(current_user_id, treatment_id):
    try:
        conn = get_db_connection()
        cur = conn.cursor()
        cur.execute("DELETE FROM tratamientos WHERE id_tratamiento = %s", (treatment_id,))
        conn.commit()

        # rowcount nos dice cuántas filas fueron afectadas. Si es 0, no se encontró.
        if cur.rowcount == 0:
            cur.close()
            conn.close()
            return jsonify({"error": "Tratamiento no encontrado"}), 404

        cur.close()
        conn.close()
        return jsonify({"message": "Tratamiento eliminado exitosamente"}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500

# Endpoint para que el admin vea TODOS los análisis de TODOS los usuarios
@app.route('/admin/analyses', methods=['GET'])
@admin_required
def get_all_analyses(current_user_id):
    try:
        conn = get_db_connection()
        cur = conn.cursor(cursor_factory=psycopg2.extras.DictCursor)
        # Unimos la tabla de análisis con la de usuarios para obtener el email
        cur.execute(
            """
            SELECT a.*, u.email 
            FROM analisis a
            JOIN usuarios u ON a.id_usuario = u.id_usuario
            WHERE a.fecha_eliminado IS NULL
            ORDER BY a.fecha_analisis DESC
            """
        )
        analyses = cur.fetchall()
        cur.close()
        conn.close()

        # Convertimos las fechas a string para que no den problemas en JSON
        result = []
        for row in analyses:
            row_dict = dict(row)
            row_dict['fecha_analisis'] = row_dict['fecha_analisis'].isoformat()
            result.append(row_dict)

        return jsonify(result), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500
    

@app.route('/admin/users_with_analyses', methods=['GET'])
@admin_required
def get_users_with_analyses(current_user_id):
    try:
        conn = get_db_connection()
        cur = conn.cursor(cursor_factory=psycopg2.extras.DictCursor)
        # --- 👇 MODIFICACIÓN AQUÍ: Añadimos u.profile_image_url a la consulta 👇 ---
        cur.execute(
            """
            SELECT DISTINCT ON (u.id_usuario) u.id_usuario, u.nombre_completo, u.email, u.profile_image_url,
            (SELECT COUNT(*) FROM analisis a WHERE a.id_usuario = u.id_usuario AND a.fecha_eliminado IS NULL) as analysis_count
            FROM usuarios u
            LEFT JOIN analisis a ON u.id_usuario = a.id_usuario
            ORDER BY u.id_usuario;
            """
        )
        users = cur.fetchall()
        cur.close()
        conn.close()
        return jsonify([dict(row) for row in users]), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500

# --- NUEVO: Endpoint para obtener los análisis de un usuario específico ---
@app.route('/admin/analyses/user/<int:user_id>', methods=['GET'])
@admin_required
def get_analyses_for_user(current_user_id, user_id):
    try:
        conn = get_db_connection()
        cur = conn.cursor(cursor_factory=psycopg2.extras.DictCursor)
        cur.execute(
            """
            SELECT a.*, u.email 
            FROM analisis a
            JOIN usuarios u ON a.id_usuario = u.id_usuario
            WHERE a.id_usuario = %s AND a.fecha_eliminado IS NULL
            ORDER BY a.fecha_analisis DESC
            """, (user_id,)
        )
        analyses = cur.fetchall()
        cur.close()
        conn.close()

        result = []
        for row in analyses:
            row_dict = dict(row)
            row_dict['fecha_analisis'] = row_dict['fecha_analisis'].isoformat()
            result.append(row_dict)

        return jsonify(result), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500
    
 # backend/app.py

@app.route('/api/enfermedades', methods=['GET'])
@token_required
def get_enfermedades(current_user_id):
    """
    Endpoint para obtener todas las enfermedades de la base de datos.
    Ahora devuelve una lista completa de datos para la Guía de Tratamientos.
    """
    try:
        conn = get_db_connection()
        cur = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
        
        # --- 👇 ¡AQUÍ ESTÁ LA MODIFICACIÓN! 👇 ---
        # Seleccionamos las nuevas columnas que necesita el frontend.
        cur.execute("""
            SELECT 
                id_enfermedad as id, 
                nombre_comun, 
                roboflow_class,
                imagen_url,
                tipo,
                prevencion,
                riesgo
            FROM enfermedades 
            ORDER BY nombre_comun ASC
        """)
        
        enfermedades = cur.fetchall()
        cur.close()
        conn.close()

        return jsonify(enfermedades)
    except Exception as e:
        print(f"Error al obtener enfermedades: {e}")
        return jsonify({'error': 'Error interno al obtener las enfermedades.'}), 500


@app.route('/api/tratamientos/<int:enfermedad_id>', methods=['GET'])
@token_required
def get_tratamientos_por_enfermedad(current_user_id, enfermedad_id):
    """
    Endpoint para obtener los tratamientos para una enfermedad específica.
    Recibe el ID de la enfermedad como parámetro en la URL.
    """
    try:
        conn = get_db_connection()
        cur = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)

        # --- 👇 AQUÍ ESTÁ LA NUEVA CORRECCIÓN 👇 ---
        # Usamos COALESCE para manejar valores NULL en dosis y unidad.
        # Esto previene errores en el frontend si los datos están incompletos.
        cur.execute("""
            SELECT 
                id_tratamiento as id, 
                nombre_comercial, 
                ingrediente_activo, 
                tipo_tratamiento,
                COALESCE(dosis_valor, 0.0) as dosis, -- <-- ¡CORRECCIÓN! Si es NULL, devuelve 0.0
                COALESCE(dosis_unidad, '') as unidad_medida, -- <-- ¡CORRECCIÓN! Si es NULL, devuelve ''
                CAST(NULL AS TEXT) as periodo_carencia
            FROM tratamientos 
            WHERE id_enfermedad = %s
            ORDER BY nombre_comercial ASC
        """, (enfermedad_id,))
        
        tratamientos = cur.fetchall()
        cur.close()
        conn.close()

        return jsonify(tratamientos)
    except Exception as e:
        print(f"Error al obtener tratamientos: {e}")
        return jsonify({'error': 'Error interno al obtener los tratamientos.'}), 500
    
    
@app.route('/profile', methods=['GET'])
@token_required
def get_profile(current_user_id):
    """Obtiene los datos del perfil del usuario logueado."""
    try:
        conn = get_db_connection()
        cur = conn.cursor(cursor_factory=psycopg2.extras.DictCursor)
        cur.execute(
            "SELECT nombre_completo, email, ong, profile_image_url FROM usuarios WHERE id_usuario = %s",
            (current_user_id,)
        )
        user = cur.fetchone()
        cur.close()
        conn.close()

        if user is None:
            return jsonify({"error": "Usuario no encontrado"}), 404

        return jsonify(dict(user))
    except Exception as e:
        return jsonify({"error": str(e)}), 500


@app.route('/profile/update', methods=['PUT'])
@token_required
def update_profile(current_user_id):
    """Actualiza el nombre y/o la foto de perfil del usuario."""
    data = request.get_json()
    nombre_completo = data.get('nombre_completo')
    profile_image_url = data.get('profile_image_url')

    if not nombre_completo and not profile_image_url:
        return jsonify({"error": "No hay datos para actualizar"}), 400

    try:
        conn = get_db_connection()
        cur = conn.cursor()

        # Usamos un marcador de posición para construir la consulta dinámicamente
        query_parts = []
        params = []
        if nombre_completo:
            query_parts.append("nombre_completo = %s")
            params.append(nombre_completo)
        
        if profile_image_url:
            query_parts.append("profile_image_url = %s")
            params.append(profile_image_url)

        params.append(current_user_id)
        
        # Unimos las partes de la consulta
        query = f"UPDATE usuarios SET {', '.join(query_parts)} WHERE id_usuario = %s"
        
        cur.execute(query, tuple(params))

        conn.commit()
        cur.close()
        conn.close()
        return jsonify({"message": "Perfil actualizado exitosamente"}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500


@app.route('/profile/change-password', methods=['POST'])
@token_required
def change_password(current_user_id):
    """Cambia la contraseña del usuario."""
    data = request.get_json()
    current_password = data.get('current_password')
    new_password = data.get('new_password')

    if not current_password or not new_password:
        return jsonify({"error": "Faltan datos"}), 400

    try:
        conn = get_db_connection()
        cur = conn.cursor(cursor_factory=psycopg2.extras.DictCursor)
        cur.execute("SELECT password_hash FROM usuarios WHERE id_usuario = %s", (current_user_id,))
        user = cur.fetchone()
        
        if not user:
            cur.close()
            conn.close()
            return jsonify({"error": "Usuario no encontrado"}), 404
            
        if not bcrypt.checkpw(current_password.encode('utf-8'), user['password_hash'].encode('utf-8')):
            cur.close()
            conn.close()
            return jsonify({"error": "La contraseña actual es incorrecta"}), 401
        
        new_hashed_password = bcrypt.hashpw(new_password.encode('utf-8'), bcrypt.gensalt())
        cur.execute(
            "UPDATE usuarios SET password_hash = %s WHERE id_usuario = %s",
            (new_hashed_password.decode('utf-8'), current_user_id)
        )
        conn.commit()
        cur.close()
        conn.close()
        
        return jsonify({"message": "Contraseña actualizada exitosamente"}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500

# backend/app.py

# ... (todas las demás rutas e importaciones se mantienen igual)

@app.route('/admin/user/<int:user_id>', methods=['DELETE'])
@admin_required
def admin_delete_user(current_user_id, user_id):
    """
    Permite a un administrador eliminar permanentemente a un usuario,
    todos sus datos asociados de la BD y sus imágenes de Firebase Storage.
    """
    if current_user_id == user_id:
        return jsonify({"error": "Un administrador no puede eliminarse a sí mismo."}), 403

    conn = None
    try:
        conn = get_db_connection()
        cur = conn.cursor(cursor_factory=psycopg2.extras.DictCursor) # Usamos DictCursor para acceder a las columnas por nombre

        # --- INICIO DE LA LÓGICA MEJORADA ---

        # 1. Obtener todas las URLs de las imágenes de análisis del usuario
        cur.execute(
            "SELECT url_imagen, url_imagen_reverso FROM analisis WHERE id_usuario = %s",
            (user_id,)
        )
        analysis_images = cur.fetchall()
        
        # 2. Obtener la URL de la imagen de perfil del usuario
        cur.execute(
            "SELECT profile_image_url FROM usuarios WHERE id_usuario = %s",
            (user_id,)
        )
        user_profile = cur.fetchone()

        # Comprobar si el usuario a eliminar es un admin
        cur.execute("SELECT es_admin FROM usuarios WHERE id_usuario = %s", (user_id,))
        user_to_delete_is_admin = cur.fetchone()

        if user_to_delete_is_admin and user_to_delete_is_admin['es_admin']:
             cur.close()
             conn.close()
             return jsonify({"error": "No se puede eliminar a otro administrador."}), 403

        # 3. Construir una lista con TODAS las URLs a eliminar
        urls_to_delete = []
        if user_profile and user_profile['profile_image_url']:
            urls_to_delete.append(user_profile['profile_image_url'])
        
        for item in analysis_images:
            if item['url_imagen']:
                urls_to_delete.append(item['url_imagen'])
            if item['url_imagen_reverso']:
                urls_to_delete.append(item['url_imagen_reverso'])

        # 4. Eliminar los registros de la base de datos ANTES de borrar las imágenes
        # Se hace en este orden por si el borrado de imágenes falla, no dejar la BD inconsistente.
        cur.execute("DELETE FROM analisis WHERE id_usuario = %s", (user_id,))
        cur.execute("DELETE FROM usuarios WHERE id_usuario = %s", (user_id,))
        
        if cur.rowcount == 0:
            cur.close()
            conn.close()
            return jsonify({"error": "Usuario no encontrado"}), 404
        
        # Si todo fue bien en la BD, confirmamos los cambios
        conn.commit()
        
        # 5. Ahora, procedemos a borrar las imágenes de Firebase Storage
        if urls_to_delete:
            print(f"Iniciando borrado de {len(urls_to_delete)} imágenes de Firebase para el usuario {user_id}.")
            bucket = storage.bucket()
            for image_url in urls_to_delete:
                if image_url:
                    try:
                        # Esta lógica ya la tenías en otras funciones, la reutilizamos
                        path_part = image_url.split('?')[0]
                        file_path = path_part.split('/o/')[-1].replace('%2F', '/')
                        
                        blob = bucket.blob(file_path)
                        if blob.exists():
                            blob.delete()
                            print(f"Imagen {file_path} borrada de Firebase Storage.")
                        else:
                            print(f"ADVERTENCIA: Se intentó borrar {file_path} pero no se encontró en Firebase.")
                    except Exception as e:
                        # Imprimimos la advertencia pero no detenemos el proceso
                        print(f"ADVERTENCIA: No se pudo borrar la imagen {image_url} de Firebase: {e}")

        # --- FIN DE LA LÓGICA MEJORADA ---
        
        cur.close()
        conn.close()
        
        return jsonify({"message": "Usuario y todos sus datos han sido eliminados exitosamente"}), 200

    except Exception as e:
        if conn:
            conn.rollback() # Revertimos los cambios en la BD si algo falla
            cur.close()
            conn.close()
        return jsonify({"error": f"Ocurrió un error al eliminar el usuario: {str(e)}"}), 500

@app.route('/admin/user/<int:user_id>/reset-password', methods=['PUT'])
@admin_required
def admin_reset_password(current_user_id, user_id):
    """
    Permite a un administrador restablecer la contraseña de cualquier usuario.
    """
    data = request.get_json()
    new_password = data.get('new_password')

    if not new_password:
        return jsonify({"error": "Se requiere la nueva contraseña"}), 400

    try:
        conn = get_db_connection()
        cur = conn.cursor()
        
        # Encriptamos la nueva contraseña
        new_hashed_password = bcrypt.hashpw(new_password.encode('utf-8'), bcrypt.gensalt())
        
        # Actualizamos la contraseña en la base de datos
        cur.execute(
            "UPDATE usuarios SET password_hash = %s WHERE id_usuario = %s",
            (new_hashed_password.decode('utf-8'), user_id)
        )
        
        # Verificamos si se actualizó alguna fila
        if cur.rowcount == 0:
            cur.close()
            conn.close()
            return jsonify({"error": "Usuario no encontrado"}), 404
            
        conn.commit()
        cur.close()
        conn.close()
        
        return jsonify({"message": "Contraseña del usuario actualizada exitosamente"}), 200

    except Exception as e:
        return jsonify({"error": f"Ocurrió un error al restablecer la contraseña: {str(e)}"}), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5001, debug=True)