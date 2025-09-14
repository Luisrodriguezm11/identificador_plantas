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
from roboflow import Roboflow # Importa Roboflow
import os
import requests
from urllib.parse import unquote, urlparse
import firebase_admin
from firebase_admin import credentials, storage

# --- INICIALIZACIÓN DE FIREBASE ADMIN SDK ---
# Asegúrate de que el path al archivo .json sea correcto
try:
    cred = credentials.Certificate("serviceAccountKey.json")
    firebase_admin.initialize_app(cred, {
        'storageBucket': 'identificador-plagas-v2.firebasestorage.app'
    })
except Exception as e:
    print(f"Error inicializando Firebase Admin: {e}")
# --- FIN DE LA INICIALIZACIÓN ---

app = Flask(__name__)
CORS(app)
app.config.from_object(Config)

def get_db_connection():
    """Establece conexión con la base de datos."""
    conn = psycopg2.connect(app.config['DATABASE_URI'])
    return conn

# --- Rutas de Autenticación (sin cambios) ---

@app.route('/register', methods=['POST'])
def register():
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
        cur.execute("SELECT * FROM usuarios WHERE email = %s", (email,))
        user = cur.fetchone()
        cur.close()
        conn.close()

        if not user:
            return jsonify({"error": "Credenciales inválidas"}), 401

        if bcrypt.checkpw(password.encode('utf-8'), user['password_hash'].encode('utf-8')):
            token = jwt.encode({
                'user_id': user['id_usuario'],
                'exp': datetime.utcnow() + timedelta(hours=24)
            }, app.config['SECRET_KEY'], algorithm="HS256")

            return jsonify({"token": token}), 200
        else:
            return jsonify({"error": "Credenciales inválidas"}), 401

    except Exception as e:
        return jsonify({"error": str(e)}), 500

# --- Decorador (sin cambios) ---
def token_required(f):
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
    
# --- Ruta /analyze CORREGIDA ---
@app.route('/analyze', methods=['POST'])
@token_required
def analyze_image(current_user_id):
    data = request.get_json()
    image_url = data.get('image_url')

    if not image_url:
        return jsonify({"error": "No se proporcionó la URL de la imagen"}), 400

    temp_image_path = "temp_image.jpg"
    try:
        # 1. Descarga la imagen desde la URL de Firebase
        response = requests.get(image_url, stream=True)
        response.raise_for_status()

        with open(temp_image_path, 'wb') as f:
            f.write(response.content)

        # 2. Realiza la predicción con Roboflow
        rf = Roboflow(api_key=app.config['ROBOFLOW_API_KEY'])
        # Extrae el workspace y el project_id del string del modelo
        project_id, version_id = app.config['ROBOFLOW_MODEL_ID'].split('/')
        project = rf.workspace().project(project_id)
        model = project.version(version_id).model
        
        prediction = model.predict(temp_image_path, confidence=40, overlap=30).json()

        # 3. Formatea el resultado
        class_detected = "No se detectó ninguna plaga"
        confidence = 0.0
        # Toma la predicción con la confianza más alta
        if prediction.get('predictions'):
            top_pred = max(prediction['predictions'], key=lambda p: p['confidence'])
            class_detected = top_pred['class']
            confidence = top_pred['confidence']

        # Aquí podrías tener una lógica más compleja para las recomendaciones
        recommendations = {
            "cercospora": "Aplicar fungicidas a base de cobre y mejorar la ventilación.",
            "phoma": "Podar las ramas afectadas y aplicar un tratamiento fungicida específico.",
            "roya": "Usar variedades resistentes y aplicar fungicidas sistémicos. Controlar la sombra.",
            "sano": "La hoja parece estar sana. Continúa con las buenas prácticas de cultivo.",
            "minador": "Utilizar trampas pegajosas y control biológico con avispas parasitoides."
        }
        
        analysis_result = {
            "prediction": class_detected,
            "confidence": confidence,
            "recommendation": recommendations.get(class_detected.lower(), "No hay una recomendación específica.")
        }

        # 4. Guarda el análisis en la base de datos
        conn = get_db_connection()
        cur = conn.cursor()
        cur.execute(
            """
            INSERT INTO analisis (id_usuario, url_imagen, resultado_prediccion, confianza, fecha_analisis)
            VALUES (%s, %s, %s, %s, %s)
            """,
            (current_user_id, image_url, analysis_result['prediction'], analysis_result['confidence'], datetime.utcnow())
        )
        conn.commit()
        cur.close()
        conn.close()

        # 5. Borra la imagen temporal y devuelve el resultado
        os.remove(temp_image_path)
        return jsonify(analysis_result), 200

    except Exception as e:
        if os.path.exists(temp_image_path):
            os.remove(temp_image_path)
        # Devolvemos un error más específico en formato JSON
        return jsonify({"error": f"Ocurrió un error durante el análisis: {str(e)}"}), 500


# --- RUTA PARA OBTENER EL HISTORIAL DE ANÁLISIS ---
@app.route('/history', methods=['GET'])
@token_required
def get_history(current_user_id):
    """
    Devuelve todos los análisis realizados por el usuario actual,
    ordenados del más reciente al más antiguo.
    """
    try:
        conn = get_db_connection()
        # Usamos DictCursor para que los resultados sean fáciles de manejar
        cur = conn.cursor(cursor_factory=psycopg2.extras.DictCursor)
        
        # Seleccionamos todos los análisis que coincidan con el id del usuario
        cur.execute(
            "SELECT * FROM analisis WHERE id_usuario = %s AND fecha_eliminado IS NULL ORDER BY fecha_analisis DESC", 
            (current_user_id,)
        )
        
        history = cur.fetchall()
        cur.close()
        conn.close()
        
        # Convertimos los resultados a una lista de diccionarios que se pueda enviar como JSON
        # También nos aseguramos de que el formato de fecha sea un string legible
        results = []
        for row in history:
            results.append({
                "id_analisis": row["id_analisis"],
                "url_imagen": row["url_imagen"],
                "resultado_prediccion": row["resultado_prediccion"],
                "confianza": row["confianza"],
                "fecha_analisis": row["fecha_analisis"].isoformat() # Convertir fecha a string
            })

        return jsonify(results), 200

    except Exception as e:
        return jsonify({"error": f"Ocurrió un error al obtener el historial: {str(e)}"}), 500

# --- RUTA PARA BORRAR UN ANÁLISIS ESPECÍFICO ---
@app.route('/history/<int:analysis_id>', methods=['DELETE'])
@token_required
def delete_history_item(current_user_id, analysis_id):
    """
    Borra un registro de análisis específico de la base de datos y su imagen de Firebase Storage.
    """
    try:
        conn = get_db_connection()
        cur = conn.cursor(cursor_factory=psycopg2.extras.DictCursor)

        # Primero, obtenemos la URL de la imagen para poder borrarla de Firebase
        cur.execute(
            "SELECT url_imagen FROM analisis WHERE id_analisis = %s AND id_usuario = %s",
            (analysis_id, current_user_id)
        )
        item = cur.fetchone()

        if not item:
            cur.close()
            conn.close()
            return jsonify({"error": "Análisis no encontrado o no autorizado"}), 404

        # Ahora, borramos el registro de la base de datos
        cur.execute(
            "UPDATE analisis SET fecha_eliminado = NOW() AT TIME ZONE 'UTC' WHERE id_analisis = %s AND id_usuario = %s",
            (analysis_id, current_user_id)
        )
        conn.commit()
        cur.close()
        conn.close()
        
        # Opcional pero recomendado: Borrar la imagen de Firebase Storage
        # Esta parte es más avanzada y requiere el SDK de Admin de Firebase.
        # Por ahora, nos enfocaremos en borrar el registro de la base de datos.

        return jsonify({"message": "Análisis borrado exitosamente"}), 200

    except Exception as e:
        return jsonify({"error": f"Ocurrió un error al borrar el análisis: {str(e)}"}), 500

# --- RUTA PARA VER LOS ELEMENTOS EN LA PAPELERA ---
@app.route('/history/trash', methods=['GET'])
@token_required
def get_trashed_history(current_user_id):
    """Devuelve todos los análisis que han sido 'borrados' por el usuario."""
    try:
        conn = get_db_connection()
        cur = conn.cursor(cursor_factory=psycopg2.extras.DictCursor)
        
        # Seleccionamos solo los análisis donde fecha_eliminado NO es NULL
        cur.execute(
            "SELECT * FROM analisis WHERE id_usuario = %s AND fecha_eliminado IS NOT NULL ORDER BY fecha_eliminado DESC", 
            (current_user_id,)
        )
        
        history = cur.fetchall()
        # ... (el resto del código para formatear la respuesta es igual que en get_history)
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


# --- RUTA PARA RESTAURAR UN ANÁLISIS DESDE LA PAPELERA ---
@app.route('/history/<int:analysis_id>/restore', methods=['PUT'])
@token_required
def restore_history_item(current_user_id, analysis_id):
    """Restaura un análisis marcando su fecha_eliminado como NULL."""
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


# --- RUTA PARA BORRAR PERMANENTEMENTE UN ANÁLISIS (VERSIÓN MEJORADA) ---
@app.route('/history/<int:analysis_id>/permanent', methods=['DELETE'])
@token_required
def permanently_delete_item(current_user_id, analysis_id):
    """
    Borra un registro permanentemente de la DB y su archivo de Firebase Storage.
    """
    try:
        conn = get_db_connection()
        cur = conn.cursor(cursor_factory=psycopg2.extras.DictCursor)

        # 1. Obtenemos la URL de la imagen ANTES de borrar el registro
        cur.execute(
            "SELECT url_imagen FROM analisis WHERE id_analisis = %s AND id_usuario = %s",
            (analysis_id, current_user_id)
        )
        item_to_delete = cur.fetchone()

        if not item_to_delete:
            return jsonify({"error": "Análisis no encontrado"}), 404
        
        image_url = item_to_delete['url_imagen']

        # 2. Borramos el registro de la base de datos
        cur.execute(
            "DELETE FROM analisis WHERE id_analisis = %s", (analysis_id,)
        )
        conn.commit()
        cur.close()
        conn.close()

        # 3. Borramos la imagen de Firebase Storage
        if image_url:
            try:
                # Extraemos el nombre del archivo desde la URL
                # La ruta del archivo está después de '/o/' y antes de '?alt=media'
                path_start = image_url.find("/o/") + 3
                path_end = image_url.find("?alt=media")
                file_path = unquote(image_url[path_start:path_end])
                
                bucket = storage.bucket()
                blob = bucket.blob(file_path)
                blob.delete()
                print(f"Imagen {file_path} borrada de Firebase Storage.")
            except Exception as e:
                print(f"No se pudo borrar la imagen de Firebase Storage: {e}")

        return jsonify({"message": "Análisis borrado permanentemente de la base de datos y del almacenamiento"}), 200

    except Exception as e:
        return jsonify({"error": f"Ocurrió un error en el borrado permanente: {str(e)}"}), 500



if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5001, debug=True)
