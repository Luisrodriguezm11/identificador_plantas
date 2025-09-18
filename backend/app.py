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

try:
    cred = credentials.Certificate("serviceAccountKey.json")
    firebase_admin.initialize_app(cred, {
        'storageBucket': 'identificador-plagas-v2.firebasestorage.app'
    })
except Exception as e:
    print(f"Error inicializando Firebase Admin: {e}")

app = Flask(__name__)
CORS(app)
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
    # ... (código sin cambios)
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
    
def _run_prediction(image_url):
    temp_image_path = "temp_image.jpg"
    try:
        response = requests.get(image_url, stream=True)
        response.raise_for_status()
        with open(temp_image_path, 'wb') as f:
            f.write(response.content)

        # --- 2. CÓDIGO NUEVO PARA REDIMENSIONAR LA IMAGEN ---
        max_size = (1024, 1024)  # Tamaño máximo (ancho, alto) en píxeles
        with Image.open(temp_image_path) as img:
            img.thumbnail(max_size, Image.Resampling.LANCZOS)
            # Guardar la imagen redimensionada, sobrescribiendo la original
            img.save(temp_image_path, "JPEG", quality=90)
        # --- FIN DEL CÓDIGO NUEVO ---

        rf = Roboflow(api_key=app.config['ROBOFLOW_API_KEY'])
        project_id, version_id = app.config['ROBOFLOW_MODEL_ID'].split('/')
        project = rf.workspace().project(project_id)
        model = project.version(version_id).model
        
        prediction_result = model.predict(temp_image_path, confidence=40, overlap=30).json()

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
    # ... (código sin cambios)
    data = request.get_json()
    image_url_front = data.get('image_url_front')
    image_url_back = data.get('image_url_back') # Puede ser None

    if not image_url_front:
        return jsonify({"error": "La URL de la imagen del frente es requerida"}), 400

    try:
        result_front = _run_prediction(image_url_front)
        final_result = result_front

        if image_url_back:
            result_back = _run_prediction(image_url_back)
            
            is_front_disease = result_front['prediction'] != 'No se detectó ninguna plaga'
            is_back_disease = result_back['prediction'] != 'No se detectó ninguna plaga'

            if is_back_disease:
                final_result = result_back
            elif is_front_disease and not is_back_disease:
                final_result = result_front
            else:
                final_result = result_front if result_front['confidence'] >= result_back['confidence'] else result_back

        conn = get_db_connection()
        cur = conn.cursor()
        cur.execute(
            """
            INSERT INTO analisis (id_usuario, url_imagen, resultado_prediccion, confianza, fecha_analisis)
            VALUES (%s, %s, %s, %s, %s)
            """,
            (current_user_id, image_url_front, final_result['prediction'], final_result['confidence'], datetime.utcnow())
        )
        conn.commit()
        cur.close()
        conn.close()

        return jsonify(final_result), 200

    except Exception as e:
        return jsonify({"error": f"Ocurrió un error durante el análisis: {str(e)}"}), 500

# (El resto de tus rutas no necesitan cambios)
# ...
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

        cur.execute(
            "SELECT tipo_tratamiento, descripcion_tratamiento FROM tratamientos WHERE id_enfermedad = %s",
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
        
        cur.execute(
            "SELECT * FROM analisis WHERE id_usuario = %s AND fecha_eliminado IS NULL ORDER BY fecha_analisis DESC", 
            (current_user_id,)
        )
        
        history = cur.fetchall()
        cur.close()
        conn.close()
        
        results = []
        for row in history:
            results.append({
                "id_analisis": row["id_analisis"],
                "url_imagen": row["url_imagen"],
                "resultado_prediccion": row["resultado_prediccion"],
                "confianza": row["confianza"],
                "fecha_analisis": row["fecha_analisis"].isoformat()
            })

        return jsonify(results), 200

    except Exception as e:
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

@app.route('/history/<int:analysis_id>/permanent', methods=['DELETE'])
@token_required
def permanently_delete_item(current_user_id, analysis_id):
    try:
        conn = get_db_connection()
        cur = conn.cursor(cursor_factory=psycopg2.extras.DictCursor)

        cur.execute(
            "SELECT url_imagen FROM analisis WHERE id_analisis = %s AND id_usuario = %s",
            (analysis_id, current_user_id)
        )
        item_to_delete = cur.fetchone()

        if not item_to_delete:
            return jsonify({"error": "Análisis no encontrado"}), 404
        
        image_url = item_to_delete['url_imagen']

        cur.execute(
            "DELETE FROM analisis WHERE id_analisis = %s", (analysis_id,)
        )
        conn.commit()
        cur.close()
        conn.close()

        if image_url:
            try:
                path_start = image_url.find("/o/") + 3
                path_end = image_url.find("?alt=media")
                file_path = unquote(image_url[path_start:path_end])
                
                bucket = storage.bucket()
                blob = bucket.blob(file_path)
                blob.delete()
                print(f"Imagen {file_path} borrada de Firebase Storage.")
            except Exception as e:
                print(f"No se pudo borrar la imagen de Firebase Storage: {e}")

        return jsonify({"message": "Análisis borrado permanentemente"}), 200

    except Exception as e:
        return jsonify({"error": f"Ocurrió un error en el borrado permanente: {str(e)}"}), 500
    
@app.route('/history/trash/empty', methods=['DELETE'])
@token_required
def empty_trash(current_user_id):
    try:
        conn = get_db_connection()
        cur = conn.cursor(cursor_factory=psycopg2.extras.DictCursor)

        cur.execute(
            "SELECT url_imagen FROM analisis WHERE id_usuario = %s AND fecha_eliminado IS NOT NULL",
            (current_user_id,)
        )
        items_to_delete = cur.fetchall()

        if items_to_delete:
            print(f"Vaciando papelera para el usuario {current_user_id}. {len(items_to_delete)} items encontrados.")
            bucket = storage.bucket()
            for item in items_to_delete:
                image_url = item['url_imagen']
                if image_url:
                    try:
                        path_start = image_url.find("/o/") + 3
                        path_end = image_url.find("?alt=media")
                        if path_start > 2 and path_end != -1:
                            file_path = unquote(image_url[path_start:path_end])
                            blob = bucket.blob(file_path)
                            if blob.exists():
                                blob.delete()
                    except Exception as e:
                        print(f"ADVERTENCIA: No se pudo borrar la imagen {image_url} de Firebase Storage: {e}")
        
        cur.execute(
            "DELETE FROM analisis WHERE id_usuario = %s AND fecha_eliminado IS NOT NULL",
            (current_user_id,)
        )
        conn.commit()

        cur.close()
        conn.close()

        return jsonify({"message": "La papelera ha sido vaciada exitosamente"}), 200

    except Exception as e:
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


if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5001, debug=True)