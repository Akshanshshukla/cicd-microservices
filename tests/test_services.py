from fastapi.testclient import TestClient

from services.catalog.app import app as catalog_app
from services.orders.app import app as orders_app


def test_orders_health_and_payload():
    client = TestClient(orders_app)
    assert client.get("/health").json() == {"status": "ok", "service": "orders"}
    assert client.get("/api/orders").json()["orders"][0]["id"] == "ord-1001"


def test_catalog_health_and_payload():
    client = TestClient(catalog_app)
    assert client.get("/health").json() == {"status": "ok", "service": "catalog"}
    assert client.get("/api/catalog").json()["items"][0]["name"] == "notebook"
