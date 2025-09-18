# backend/cleanup_script.py

import psycopg2
import psycopg2.extras
import os
from datetime import datetime, timedelta
from config import Config
import firebase_admin
from firebase_admin import credentials, storage
from urllib.parse import unquote

def cleanup_expired_items():
    """
    Encuentra y elimina permanentemente los registros de análisis y sus
    imágenes correspondientes de Firebase Storage que fueron movidos a la
    papelera hace más de 30 días.
    """
    print(f"--- Iniciando limpieza de la papelera - {datetime.utcnow()} UTC ---")
    conn = None
    cur = None
    
    try:
        # --- Inicializar Firebase (solo si no se ha hecho) ---
        if not firebase_admin._apps:
            cred = credentials.Certificate("serviceAccountKey.json")
            firebase_admin.initialize_app(cred, {
                'storageBucket': 'identificador-plagas-v2.firebasestorage.app'
            })
        bucket = storage.bucket()
        
        # --- Conectar a la Base de Datos ---
        conn = psycopg2.connect(Config.DATABASE_URI)
        cur = conn.cursor(cursor_factory=psycopg2.extras.DictCursor)

        # 1. Encontrar los archivos expirados
        thirty_days_ago = datetime.utcnow() - timedelta(days=30)
        cur.execute(
            "SELECT id_analisis, url_imagen FROM analisis WHERE fecha_eliminado IS NOT NULL AND fecha_eliminado < %s",
            (thirty_days_ago,)
        )
        expired_items = cur.fetchall()
        
        if not expired_items:
            print("No se encontraron archivos expirados para eliminar.")
            return

        print(f"Se encontraron {len(expired_items)} archivos expirados para eliminar.")
        
        ids_to_delete = []
        for item in expired_items:
            # 2. Borrar la imagen de Firebase Storage
            image_url = item['url_imagen']
            if image_url:
                try:
                    # Extraer el path del archivo de la URL
                    path_start = image_url.find("/o/") + 3
                    path_end = image_url.find("?alt=media")
                    if path_start > 2 and path_end != -1:
                        file_path = unquote(image_url[path_start:path_end])
                        blob = bucket.blob(file_path)
                        if blob.exists():
                            blob.delete()
                            print(f"  - Imagen borrada de Firebase: {file_path}")
                        else:
                            print(f"  - La imagen no se encontró en Firebase (pudo ser borrada antes): {file_path}")
                except Exception as e:
                    print(f"  - ERROR: No se pudo borrar la imagen {image_url} de Firebase: {e}")

            ids_to_delete.append(item['id_analisis'])
        
        # 3. Borrar los registros de la base de datos en un solo lote
        if ids_to_delete:
            cur.execute("DELETE FROM analisis WHERE id_analisis = ANY(%s::int[])", (ids_to_delete,))
            conn.commit()
            print(f"Se eliminaron {len(ids_to_delete)} registros de la base de datos.")

    except Exception as e:
        print(f"Ocurrió un error durante el proceso de limpieza: {e}")
    finally:
        if cur:
            cur.close()
        if conn:
            conn.close()
        print("--- Proceso de limpieza finalizado ---")

if __name__ == '__main__':
    cleanup_expired_items()