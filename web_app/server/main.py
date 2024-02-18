from fastapi import FastAPI, WebSocket, BackgroundTasks
import asyncio
import numpy as np

app = FastAPI()

receivers = []

@app.websocket("/ws/receive")
async def ws_send_data(websocket: WebSocket):

    await websocket.accept()

    # receivers.append(websocket)

    try:
        while True:
            print('connected')
            # Keep the connection alive
            dummy_data = np.random.rand(10).tolist()
            await websocket.send_json({"float_array": dummy_data})
            await asyncio.sleep(0.1)  # Send data every second, adjust the sleep time as needed


            # await websocket.receive_text()

    except Exception as e:
        receivers.remove(websocket)

@app.websocket("/ws/receive")
async def ws_receive_data(websocket: WebSocket):
    """
    receive an array of floats from the client
    """
    await websocket.accept()
    # receivers.append(websocket)




