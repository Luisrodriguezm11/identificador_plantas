# backend/app.py

from flask import Flask, request, jsonify
from flask_cors import CORS
import psycopg2
import psycopg2.extras
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

try:
    cred = credentials.Certificate("serviceAccountKey.json")
    firebase_admin.initialize_app(cred, {
        'storageBucket': 'identificador-plagas-v2.firebasestorage.app'
    })
except Exception as e:
    print(f"Error inicializando Firebase Admin: {e}")

app = Flask(__name__)
# Configuración de CORS para permitir todas las solicitudes de cualquier origen.
CORS(app, resources={r"/*": {"origins": "*"}})
app.config.from_object(Config)

def get_db_connection():
    conn = psycopg2.connect(app.config['DATABASE_URI'])
    return conn

# --- Rutas de Autenticación (sin cambios) ---
@app.route('/register', methods=['POST'])
def register():
    # ... (código sin cambios)
    data = request.get_json()
    nombre_completo = data.get('nombre_completo')
    email = data.get('email')
    password = data.get('password')
    ong = data.get('ong')

    if not all([nombre_completo, email, password]):
        return jsonify({"error": "Faltan datos requeridos"}), 400

    hashed_password = bcrypt.hashpw(password.encode('utf-8'), bcrypt.gensalt())

    try:
        conn = get_db_connection()
        cur = conn.cursor()
        cur.execute(
            "INSERT INTO usuarios (nombre_completo, email, password_hash, ong) VALUES (%s, %s, %s, %s)",
            (nombre_completo, email, hashed_password.decode('utf-8'), ong)
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
        # Pedimos la nueva columna 'es_admin' en la consulta
        cur.execute("SELECT id_usuario, password_hash, es_admin FROM usuarios WHERE email = %s", (email,))
        user = cur.fetchone()
        cur.close()
        conn.close()

        if not user:
            return jsonify({"error": "Credenciales inválidas"}), 401

        if bcrypt.checkpw(password.encode('utf-8'), user['password_hash'].encode('utf-8')):
            token = jwt.encode({
                'user_id': user['id_usuario'],
                # Incluimos el rol en el token para validarlo después
                'es_admin': user['es_admin'],
                'exp': datetime.utcnow() + timedelta(hours=24)
            }, app.config['SECRET_KEY'], algorithm="HS256")

            # Devolvemos el token Y el rol de administrador
            return jsonify({
                "token": token,
                "es_admin": user['es_admin'] # <-- ¡AÑADIDO!
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



@app.route('/analyze', methods=['POST'])
@token_required
def analyze_image(current_user_id):
    # --- ESTA FUNCIÓN AHORA SOLO ANALIZA, NO GUARDA ---
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
            
            is_front_disease = result_front['prediction'] != 'No se detectó ninguna plaga'
            is_back_disease = result_back['prediction'] != 'No se detectó ninguna plaga'

            if is_back_disease:
                final_result = result_back
            elif is_front_disease and not is_back_disease:
                final_result = result_front
            else:
                final_result = result_front if result_front['confidence'] >= result_back['confidence'] else result_back

        total_end_time = time.time()
        print(f"⏱️ Tiempo total de la solicitud '/analyze': {total_end_time - total_start_time:.2f} segundos\n")

        # Se devuelve el resultado completo, incluyendo las URLs para guardarlas después
        response_data = {
            "prediction": final_result['prediction'],
            "confidence": final_result['confidence'],
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

# backend/app.py

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
    

# --- NUEVO: Endpoint para obtener una lista de usuarios con análisis ---
@app.route('/admin/users_with_analyses', methods=['GET'])
@admin_required
def get_users_with_analyses(current_user_id):
    try:
        conn = get_db_connection()
        cur = conn.cursor(cursor_factory=psycopg2.extras.DictCursor)
        # Seleccionamos de forma única los usuarios que aparecen en la tabla de análisis
        cur.execute(
            """
            SELECT DISTINCT ON (u.id_usuario) u.id_usuario, u.nombre_completo, u.email,
            (SELECT COUNT(*) FROM analisis a WHERE a.id_usuario = u.id_usuario AND a.fecha_eliminado IS NULL) as analysis_count
            FROM usuarios u
            JOIN analisis a ON u.id_usuario = a.id_usuario
            WHERE a.fecha_eliminado IS NULL
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


if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5001, debug=True)