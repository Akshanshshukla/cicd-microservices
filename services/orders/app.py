"""Small orders API used by the CI/CD portfolio demo."""
from fastapi import FastAPI

app = FastAPI(title="Orders service", version="1.0.0")


@app.get("/health")
def health():
    return {"status": "ok", "service": "orders"}


@app.get("/api/orders")
def orders():
    return {"orders": [{"id": "ord-1001", "item": "notebook", "quantity": 2}]}
