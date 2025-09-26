# backend/config.py

import os
from dotenv import load_dotenv

# Cargar variables de entorno desde el archivo .env
load_dotenv()

class Config:
    # Clave secreta para firmar los JWT
    SECRET_KEY = os.environ.get('SECRET_KEY', 'una-clave-secreta-muy-dificil-de-adivinar')

    # Usa directamente la variable DATABASE_URI proporcionada por Render
    DATABASE_URI = os.environ.get('DATABASE_URI')

    
    ROBOFLOW_API_KEY = os.environ.get('ROBOFLOW_API_KEY')
    ROBOFLOW_MODEL_ID = os.environ.get('ROBOFLOW_MODEL_ID')