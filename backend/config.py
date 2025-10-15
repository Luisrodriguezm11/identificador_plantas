# backend/config.py

import os
from dotenv import load_dotenv

# Cargar variables de entorno desde el archivo .env para desarrollo local
load_dotenv()

class Config:
    # Clave secreta para firmar los JWT
    SECRET_KEY = os.environ.get('SECRET_KEY', 'una-clave-secreta-muy-dificil-de-adivinar')

    # --- INICIO DE LA CORRECCIÓN ---
    # 1. Obtener la URL de la base de datos desde las variables de entorno.
    DATABASE_URL = os.environ.get('DATABASE_URL')
    
    # 2. Reemplazar 'postgres://' por 'postgresql://' si es necesario.
    #    Esto asegura la compatibilidad con psycopg2 en plataformas como Render.
    if DATABASE_URL and DATABASE_URL.startswith("postgres://"):
        DATABASE_URL = DATABASE_URL.replace("postgres://", "postgresql://", 1)

    DATABASE_URI = DATABASE_URL
    # --- FIN DE LA CORRECCIÓN ---

    # Claves para el servicio de Roboflow
    ROBOFLOW_API_KEY = os.environ.get('ROBOFLOW_API_KEY')
    ROBOFLOW_MODEL_ID = os.environ.get('ROBOFLOW_MODEL_ID')