"""lab-tracker api and static ui."""

from __future__ import annotations

from pathlib import Path

from fastapi import FastAPI, HTTPException, Request
from fastapi.responses import FileResponse, JSONResponse
from fastapi.staticfiles import StaticFiles

from app.inventory import InventoryError, get_inventory, save_inventory

WEB_DIR = Path(__file__).resolve().parent.parent / "web"

app = FastAPI(title="lab-tracker", docs_url=None, redoc_url=None)


@app.exception_handler(InventoryError)
async def inventory_error_handler(_request: Request, exc: InventoryError):
    return JSONResponse(
        status_code=400,
        content={"error": exc.message, "fix": exc.fix},
    )


@app.get("/api/inventory")
def api_get_inventory():
    data, file_hash = get_inventory()
    return {"hash": file_hash, "inventory": data}


@app.put("/api/inventory")
async def api_put_inventory(request: Request):
    body = await request.json()
    if not isinstance(body, dict):
        raise HTTPException(status_code=400, detail="body must be an object")
    inventory = body.get("inventory")
    expected_hash = body.get("hash")
    if inventory is None:
        raise InventoryError(
            "missing inventory",
            "PUT body needs inventory and hash fields",
        )
    data, file_hash = save_inventory(inventory, expected_hash=expected_hash)
    return {"hash": file_hash, "inventory": data}


@app.get("/")
def index():
    return FileResponse(WEB_DIR / "index.html")


app.mount("/static", StaticFiles(directory=WEB_DIR), name="static")
