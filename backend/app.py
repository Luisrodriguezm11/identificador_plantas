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
from roboflow import Roboflow # <-- 1. Importa Roboflow
import os # Necesario para guardar temporalmente la imagen

app = Flask(__name__)
CORS(app)
app.config.from_object(Config)

def get_db_connection():
    """Establece conexión con la base de datos."""
    conn = psycopg2.connect(app.config['DATABASE_URI'])
    return conn

# --- Rutas de Autenticación ---

@app.route('/register', methods=['POST'])
def register():
    data = request.get_json()
    nombre_completo = data.get('nombre_completo')
    email = data.get('email')
    password = data.get('password')
    ong = data.get('ong')

    if not all([nombre_completo, email, password]):
        return jsonify({"error": "Faltan datos requeridos"}), 400

    # Cifrar la contraseña
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
        # Usar DictCursor para obtener resultados como diccionarios
        cur = conn.cursor(cursor_factory=psycopg2.extras.DictCursor)
        cur.execute("SELECT * FROM usuarios WHERE email = %s", (email,))
        user = cur.fetchone()
        cur.close()
        conn.close()

        if not user:
            return jsonify({"error": "Credenciales inválidas"}), 401

        # Verificar la contraseña cifrada
        if bcrypt.checkpw(password.encode('utf-8'), user['password_hash'].encode('utf-8')):
            # Generar el token JWT
            token = jwt.encode({
                'user_id': user['id_usuario'],
                'exp': datetime.utcnow() + timedelta(hours=24) # El token expira en 24 horas
            }, app.config['SECRET_KEY'], algorithm="HS256")

            return jsonify({"token": token}), 200
        else:
            return jsonify({"error": "Credenciales inválidas"}), 401

    except Exception as e:
        return jsonify({"error": str(e)}), 500
    
@app.route('/analyze', methods=['POST'])
def analyze_image():
    if 'image' not in request.files:
        return jsonify({"error": "No se encontró ninguna imagen"}), 400

    image_file = request.files['image']

    if image_file.filename == '':
        return jsonify({"error": "No se seleccionó ninguna imagen"}), 400

    try:
        # --- Inicio de la Integración con Roboflow ---

        # 2. Guarda la imagen temporalmente para que Roboflow pueda leerla
        temp_image_path = os.path.join("./", image_file.filename)
        image_file.save(temp_image_path)

        # 3. Inicializa la API de Roboflow
        rf = Roboflow(api_key=app.config['ROBOFLOW_API_KEY'])
        project = rf.workspace().project(app.config['ROBOFLOW_MODEL_ID'].split('/')[0])
        model = project.version(int(app.config['ROBOFLOW_MODEL_ID'].split('/')[1])).model

        # 4. Realiza la predicción
        prediction = model.predict(temp_image_path, confidence=40, overlap=30).json()

        # 5. Borra la imagen temporal
        os.remove(temp_image_path)

        # --- Fin de la Integración con Roboflow ---

        # 6. Procesa la respuesta de Roboflow
        if not prediction['predictions']:
            # Si el modelo no detectó nada con suficiente confianza
            analysis_result = {
                "prediction": "No se detectó ninguna plaga conocida",
                "confidence": 0.0,
                "recommendation": "La hoja parece estar sana. Continúe monitoreando regularmente."
            }
        else:
            # Toma la detección con la confianza más alta
            best_prediction = prediction['predictions'][0]
            disease_name = best_prediction['class']
            confidence_level = best_prediction['confidence']

            # (Opcional) Aquí podrías buscar en tu base de datos una recomendación para 'disease_name'
            recommendation_text = "Recomendación para " + disease_name # Placeholder

            analysis_result = {
                "prediction": disease_name,
                "confidence": confidence_level,
                "recommendation": recommendation_text
            }

        return jsonify(analysis_result), 200

    except Exception as e:
        # Si algo falla (ej. la imagen temporal), bórrala si existe
        if 'temp_image_path' in locals() and os.path.exists(temp_image_path):
            os.remove(temp_image_path)
        return jsonify({"error": f"Ocurrió un error durante el análisis: {str(e)}"}), 500



if __name__ == '__main__':
    # Escucha en todas las interfaces de red, útil para probar desde el emulador
    app.run(host='0.0.0.0', port=5001, debug=True)