import json
from unittest.mock import patch, MagicMock


def test_app_config(app):
    """Test that the application loaded with appropriate test configuration."""
    assert app.config['TESTING'] is True
    assert app.config['SECRET_KEY'] is not None


def test_health_endpoint(client):
    """Test that /health returns HTTP 200 and healthy JSON payload."""
    response = client.get('/health')
    assert response.status_code == 200
    data = json.loads(response.data.decode('utf-8'))
    assert data['status'] == 'healthy'
    assert data['service'] == 'cems'
    assert 'timestamp' in data


def test_healthz_alias(client):
    """Test that Kubernetes /healthz alias works identically."""
    response = client.get('/healthz')
    assert response.status_code == 200
    data = json.loads(response.data.decode('utf-8'))
    assert data['status'] == 'healthy'


def test_health_with_db_check_mock(client):
    """Test /health?check_db=1 with mocked database connection."""
    with patch('app.db_api.connection.cursor') as mock_cursor_method:
        mock_cursor = MagicMock()
        mock_cursor.fetchone.return_value = (1,)
        mock_cursor_method.return_value = mock_cursor

        response = client.get('/health?check_db=1')
        assert response.status_code == 200
        data = json.loads(response.data.decode('utf-8'))
        assert data['status'] == 'healthy'
        assert data['database'] == 'connected'


def test_metrics_endpoint(client):
    """Test that Prometheus /metrics endpoint is exposed and responds."""
    response = client.get('/metrics')
    assert response.status_code == 200
    content = response.data.decode('utf-8')
    assert 'cems_app_info' in content or 'flask_' in content or 'process_' in content


def test_login_page_renders(client):
    """Test that login route returns HTTP 200."""
    response = client.get('/login')
    assert response.status_code == 200
    assert b'login' in response.data.lower() or b'sign in' in response.data.lower()


def test_register_page_renders(client):
    """Test that register route returns HTTP 200."""
    response = client.get('/register')
    assert response.status_code == 200
    assert b'register' in response.data.lower() or b'student' in response.data.lower()


def test_about_page_renders(client):
    """Test that about page renders successfully with mocked statistics."""
    with patch('app.db_api.connection.cursor') as mock_cursor_method:
        mock_cursor = MagicMock()
        mock_cursor.fetchone.return_value = {'total': 5}
        mock_cursor_method.return_value = mock_cursor

        response = client.get('/about')
        assert response.status_code == 200
        assert b'About' in response.data or b'Campus' in response.data


def test_nonexistent_route_404(client):
    """Test that querying a nonexistent route returns a 404 status."""
    response = client.get('/api/v1/nonexistent-route-for-cems-404')
    assert response.status_code == 404
