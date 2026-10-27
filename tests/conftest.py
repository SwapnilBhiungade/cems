import os
import pytest

# Ensure testing environment variables are set prior to app import
os.environ['SECRET_KEY'] = 'test-secret-key-1234567890-test'  # nosec B105
os.environ['DEBUG'] = 'false'
os.environ['ENABLE_METRICS'] = 'true'
os.environ['DB_HOST'] = '127.0.0.1'
os.environ['DB_PORT'] = '3306'
os.environ['DB_USER'] = 'test_user'
os.environ['DB_PASSWORD'] = 'test_password'  # nosec B105
os.environ['DB_NAME'] = 'test_db'

from app import app as flask_app  # noqa: E402


@pytest.fixture
def app():
    flask_app.config.update({
        'TESTING': True,
        'WTF_CSRF_ENABLED': False,
    })
    yield flask_app


@pytest.fixture
def client(app):
    return app.test_client()


@pytest.fixture
def runner(app):
    return app.test_cli_runner()
