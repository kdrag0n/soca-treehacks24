from fastapi import FastAPI, WebSocket
from fastapi.responses import HTMLResponse
from typing import Union

app = FastAPI()
receivers = []

@app.get("/")
def read_root():
    return {"Hello": "World"}


@app.get("/items/{item_id}")
def read_item(item_id: int, q: Union[str, None] = None):
    return {"item_id": item_id, "q": q}

@app.websocket("/ws/send")
async def websocket_sender(websocket: WebSocket):
    await websocket.accept()
    while True:
        data = await websocket.receive_json()
        # Assuming the incoming message is an array of floats
        float_array = data.get("float_array", [])
        # Echo the received array of floats to all connected receivers
        for receiver in receivers:
            await receiver.send_json({"float_array": float_array})

@app.websocket("/ws/receive")
async def websocket_receiver(websocket: WebSocket):
    await websocket.accept()
    receivers.append(websocket)
    try:
        while True:
            # Keep the connection alive
            await websocket.receive_text()
    except Exception as e:
        receivers.remove(websocket)



