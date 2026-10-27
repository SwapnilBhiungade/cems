"""
Gunicorn production configuration file for CEMS.
Optimized for containerized deployment on AWS EKS and Docker Compose.
"""
import os
import multiprocessing

# Network binding
bind = f"{os.getenv('HOST', '0.0.0.0')}:{os.getenv('PORT', '5000')}"  # nosec B104

# Worker processes and threading model
# In Kubernetes pods, keeping workers proportional to pod CPU limits avoids OOM
default_workers = max(2, min(4, multiprocessing.cpu_count()))
workers = int(os.getenv('GUNICORN_WORKERS', default_workers))
threads = int(os.getenv('GUNICORN_THREADS', 2))
worker_class = 'gthread'

# Process management & recycling (mitigates memory leaks)
max_requests = int(os.getenv('GUNICORN_MAX_REQUESTS', 1000))
max_requests_jitter = int(os.getenv('GUNICORN_MAX_REQUESTS_JITTER', 50))

# Timeouts (aligned with Kubernetes terminationGracePeriodSeconds and ALB timeouts)
timeout = int(os.getenv('GUNICORN_TIMEOUT', 60))
graceful_timeout = int(os.getenv('GUNICORN_GRACEFUL_TIMEOUT', 30))
keepalive = int(os.getenv('GUNICORN_KEEPALIVE', 5))

# Logging configuration
accesslog = '-'
errorlog = '-'
loglevel = os.getenv('GUNICORN_LOG_LEVEL', 'info')
access_log_format = '%(h)s %(l)s %(u)s %(t)s "%(r)s" %(s)s %(b)s "%(f)s" "%(a)s" %(D)s µs'

# Security: forward remote IP from ALB / Ingress
forwarded_allow_ips = '*'
proxy_allow_ips = '*'


def when_ready(server):
    server.log.info("CEMS Gunicorn Server is ready. Listening on %s", bind)


def on_exit(server):
    server.log.info("CEMS Gunicorn Server is shutting down.")
