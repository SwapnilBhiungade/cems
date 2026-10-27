import os
from urllib.parse import urlparse
from dotenv import load_dotenv

load_dotenv()


def _resolve_path(path_value):
    if not path_value:
        return None
    expanded = os.path.expanduser(path_value.strip())
    if os.path.isabs(expanded):
        return expanded
    return os.path.abspath(expanded)


def _parse_cloudinary_url(url_value):
    if not url_value:
        return {}
    parsed = urlparse(url_value.strip())
    if parsed.scheme != 'cloudinary':
        return {}

    cloud_name = parsed.hostname or ''
    api_key = parsed.username or ''
    api_secret = parsed.password or ''
    return {
        'cloud_name': cloud_name,
        'api_key': api_key,
        'api_secret': api_secret,
    }


class Config:
    SECRET_KEY = os.getenv('SECRET_KEY', 'your-secret-key-here')
    DEBUG = os.getenv('DEBUG', 'false').lower() in ('1', 'true', 'yes', 'on')
    PREFERRED_URL_SCHEME = 'https'
    SESSION_COOKIE_HTTPONLY = True
    SESSION_COOKIE_SECURE = os.getenv('SESSION_COOKIE_SECURE', 'false').lower() in ('1', 'true', 'yes', 'on')
    SESSION_COOKIE_SAMESITE = os.getenv('SESSION_COOKIE_SAMESITE', 'Lax')
    CLOUDINARY_URL = os.getenv('CLOUDINARY_URL', '')
    _CLOUDINARY_FROM_URL = _parse_cloudinary_url(CLOUDINARY_URL)
    CLOUDINARY_CLOUD_NAME = os.getenv('CLOUDINARY_CLOUD_NAME', _CLOUDINARY_FROM_URL.get('cloud_name', ''))
    CLOUDINARY_API_KEY = os.getenv('CLOUDINARY_API_KEY', _CLOUDINARY_FROM_URL.get('api_key', ''))
    CLOUDINARY_API_SECRET = os.getenv('CLOUDINARY_API_SECRET', _CLOUDINARY_FROM_URL.get('api_secret', ''))
    CLOUDINARY_FOLDER = os.getenv('CLOUDINARY_FOLDER', 'cems-share/gallery')
    MYSQL_HOST = os.getenv('DB_HOST', 'localhost')
    MYSQL_PORT = int(os.getenv('DB_PORT', '3306'))
    MYSQL_USER = os.getenv('DB_USER', 'root')
    MYSQL_PASSWORD = os.getenv('DB_PASSWORD', '')
    MYSQL_DB = os.getenv('DB_NAME', 'campus_events')
    MYSQL_SSL_CA = _resolve_path(os.getenv('DB_CA'))
    MYSQL_SSL_VERIFY_CERT = os.getenv('DB_SSL_VERIFY_CERT', 'true' if MYSQL_SSL_CA else 'false').lower() in ('1', 'true', 'yes', 'on')
    MYSQL_SSL_VERIFY_IDENTITY = os.getenv('DB_SSL_VERIFY_IDENTITY', 'false').lower() in ('1', 'true', 'yes', 'on')

DB_CONFIG = {
    'host': Config.MYSQL_HOST,
    'port': Config.MYSQL_PORT,
    'user': Config.MYSQL_USER,
    'password': Config.MYSQL_PASSWORD,
    'database': Config.MYSQL_DB,
    'ssl_ca': Config.MYSQL_SSL_CA,
    'ssl_verify_cert': Config.MYSQL_SSL_VERIFY_CERT,
    'ssl_verify_identity': Config.MYSQL_SSL_VERIFY_IDENTITY,
}
