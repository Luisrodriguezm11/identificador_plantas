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
import requests

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
    
# Pega este bloque completo en tu archivo app.py

# --- Decorador para requerir un token JWT ---
def token_required(f):
    @wraps(f)
    def decorated(*args, **kwargs):
        token = None
        # Busca el token en los encabezados de la petición
        if 'x-access-token' in request.headers:
            token = request.headers['x-access-token']
        
        if not token:
            return jsonify({'message': 'Falta el token de autenticación'}), 401
        
        try:
            # Decodifica el token para obtener los datos del usuario
            data = jwt.decode(token, app.config['SECRET_KEY'], algorithms=["HS256"])
            current_user_id = data['user_id']
        except:
            return jsonify({'message': 'El token es inválido o ha expirado'}), 401
        
        # Pasa el ID del usuario a la función de la ruta
        return f(current_user_id, *args, **kwargs)
    return decorated    
    
@app.route('/analyze', methods=['POST'])
@token_required
def analyze_image(current_user_id):
    data = request.get_json()
    image_url = data.get('image_url')

    if not image_url:
        return jsonify({"error": "No se proporcionó la URL de la imagen"}), 400

    try:
        # --- Descarga la imagen desde la URL de Firebase ---
        response = requests.get(image_url, stream=True)
        response.raise_for_status() # Lanza un error si la descarga falla

        temp_image_path = "temp_image.jpg"
        with open(temp_image_path, 'wb') as f:
            f.write(response.content)

        # --- Realiza la predicción con Roboflow (como antes) ---
        # ... tu código de Roboflow usando temp_image_path ...

        # --- Guarda en la DB (como antes, pero con la URL de Firebase) ---
        # ... tu código para guardar en la tabla 'analisis' ...
        # Recuerda usar 'image_url' en lugar de la URL de S3

        return jsonify(analysis_result), 200


    except Exception as e:
        # Si algo falla (ej. la imagen temporal), bórrala si existe
        if 'temp_image_path' in locals() and os.path.exists(temp_image_path):
            os.remove(temp_image_path)
        return jsonify({"error": f"Ocurrió un error durante el análisis: {str(e)}"}), 500



if __name__ == '__main__':
    # Escucha en todas las interfaces de red, útil para probar desde el emulador
    app.run(host='0.0.0.0', port=5001, debug=True)