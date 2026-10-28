"""Small catalog API used by the CI/CD portfolio demo."""
from fastapi import FastAPI

app = FastAPI(title="Catalog service", version="1.0.0")


@app.get("/health")
def health():
    return {"status": "ok", "service": "catalog"}


@app.get("/api/catalog")
def catalog():
    return {"items": [{"id": "item-1", "name": "notebook", "price": 4.5}]}
