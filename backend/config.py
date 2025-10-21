import os
from dotenv import load_dotenv

load_dotenv()

class Config:
    # Clave secreta para firmar los JWT
    SECRET_KEY = os.environ.get('SECRET_KEY', 'una-clave-secreta-muy-dificil-de-adivinar')

    DATABASE_URL = os.environ.get('DATABASE_URL')
    

    if DATABASE_URL and DATABASE_URL.startswith("postgres://"):
        DATABASE_URL = DATABASE_URL.replace("postgres://", "postgresql://", 1)

    DB_USER = os.environ.get('DB_USER') 
    DB_PASSWORD = os.environ.get('DB_PASSWORD')
    DB_HOST = os.environ.get('DB_HOST')
    DB_PORT = os.environ.get('DB_PORT')
    DB_NAME = os.environ.get('DB_NAME')


    #ELIMINAR ESTO PARA QUE SE CONECTE A LA NUBE Y DESCONEMENTAR LO OTRO

    #if all([DB_USER, DB_PASSWORD, DB_HOST, DB_PORT, DB_NAME]):
    #    DATABASE_URI = f"postgresql://{DB_USER}:{DB_PASSWORD}@{DB_HOST}:{DB_PORT}/{DB_NAME}"
    #else:
    #    DATABASE_URI = os.environ.get('DATABASE_URL')
    #    if DATABASE_URI and DATABASE_URI.startswith("postgres://"):
    #        DATABASE_URI = DATABASE_URI.replace("postgres://", "postgresql://", 1)

    #ELIMINAR ESTO PARA QUE SE CONECTE A LA NUBE Y DESCONEMENTAR LO OTRO

    
    DATABASE_URI = f"postgresql://{DB_USER}:{DB_PASSWORD}@{DB_HOST}:{DB_PORT}/{DB_NAME}"

    DATABASE_URI = DATABASE_URL


    # Claves para el servicio de Roboflow
    ROBOFLOW_API_KEY = os.environ.get('ROBOFLOW_API_KEY')
    ROBOFLOW_MODEL_ID = os.environ.get('ROBOFLOW_MODEL_ID')