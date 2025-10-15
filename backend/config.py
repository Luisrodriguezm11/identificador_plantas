# backend/config.py

import os
from dotenv import load_dotenv

# Cargar variables de entorno desde el archivo .env
load_dotenv()

class Config:
    # Clave secreta para firmar los JWT
    SECRET_KEY = os.environ.get('SECRET_KEY', 'una-clave-secreta-muy-dificil-de-adivinar')

    # Usa directamente la variable DATABASE_URI proporcionada por Render para en linea 
    DATABASE_URI = os.environ.get('DATABASE_URL')

    #Configuración de la base de datos PostgreSQL en local
    #DB_USER = os.environ.get('DB_USER', 'postgres')
    #DB_PASSWORD = os.environ.get('DB_PASSWORD', 'tu_contraseña_de_postgres')
    #DB_HOST = os.environ.get('DB_HOST', 'localhost')
    #DB_PORT = os.environ.get('DB_PORT', '5432')
    #DB_NAME = os.environ.get('DB_NAME', 'plagas_cafe_db')
    #DATABASE_URI = f"postgresql://{DB_USER}:{DB_PASSWORD}@{DB_HOST}:{DB_PORT}/{DB_NAME}"


    
    ROBOFLOW_API_KEY = os.environ.get('ROBOFLOW_API_KEY')
    ROBOFLOW_MODEL_ID = os.environ.get('ROBOFLOW_MODEL_ID')