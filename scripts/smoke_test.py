import time
import urllib.error
import urllib.request


checks = {
    "http://localhost:8080/health": '"service":"gateway"',
    "http://localhost:8080/api/orders": '"ord-1001"',
    "http://localhost:8080/api/catalog": '"notebook"',
}
for url, expected in checks.items():
    for attempt in range(20):
        try:
            with urllib.request.urlopen(url, timeout=2) as response:
                body = response.read().decode()
            if expected not in body:
                raise AssertionError(f"Unexpected response from {url}: {body}")
            print(f"PASS {url}")
            break
        except (urllib.error.URLError, TimeoutError):
            if attempt == 19:
                raise
            time.sleep(1)
