"""
CEMS Smoke Test Script
Executes non-destructive HTTP checks against a running CEMS deployment
(local Docker, Kubernetes NodePort, or AWS Application Load Balancer).

Usage:
    python tests/test_smoke.py [BASE_URL]
    e.g. python tests/test_smoke.py http://cems-alb-123456.ap-south-1.elb.amazonaws.com
"""
import sys
import time
import requests


def run_smoke_tests(base_url):
    base_url = base_url.rstrip('/')
    print("\n==========================================")
    print("  Starting CEMS Deployment Smoke Tests")
    print(f"  Target: {base_url}")
    print("==========================================\n")

    endpoints = [
        {"path": "/health", "expected_code": 200, "description": "Liveness Probe"},
        {"path": "/metrics", "expected_code": 200, "description": "Prometheus Metrics Endpoint"},
        {"path": "/login", "expected_code": 200, "description": "User Login Interface"},
        {"path": "/register", "expected_code": 200, "description": "Student Registration Interface"},
        {"path": "/about", "expected_code": 200, "description": "About Information Page"},
        {"path": "/static/css/styles.css", "expected_code": 200, "description": "Static Assets (CSS)"},
    ]

    all_passed = True

    for ep in endpoints:
        url = f"{base_url}{ep['path']}"
        start_time = time.time()
        try:
            response = requests.get(url, timeout=10, allow_redirects=True)
            elapsed_ms = (time.time() - start_time) * 1000

            if response.status_code == ep['expected_code']:
                desc = ep['description']
                path = ep['path']
                print(f"[PASS] {desc:<32} | GET {path:<22} -> HTTP {response.status_code} ({elapsed_ms:.1f}ms)")
            else:
                desc = ep['description']
                path = ep['path']
                exp = ep['expected_code']
                print(f"[FAIL] {desc:<32} | GET {path:<22} -> Expected {exp}, Got {response.status_code}")
                all_passed = False
        except requests.exceptions.RequestException as exc:
            desc = ep['description']
            path = ep['path']
            print(f"[ERROR] {desc:<32} | GET {path:<22} -> Connection Error: {exc}")
            all_passed = False

    print("\n------------------------------------------")
    if all_passed:
        print("RESULT: ALL SMOKE TESTS PASSED SUCCESSFULLY! Deployment is healthy.")
        print("------------------------------------------\n")
        return 0
    else:
        print("RESULT: ONE OR MORE SMOKE TESTS FAILED!")
        print("------------------------------------------\n")
        return 1


if __name__ == "__main__":
    target = sys.argv[1] if len(sys.argv) > 1 else "http://localhost:5000"
    exit_code = run_smoke_tests(target)
    sys.exit(exit_code)
