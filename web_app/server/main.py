from fastapi import FastAPI, WebSocket, BackgroundTasks
import asyncio
import numpy as np
import json

app = FastAPI()

receivers = []

@app.websocket("/ws/get_data")
async def ws_send_data(websocket: WebSocket):

    await websocket.accept()

    receivers.append(websocket)

    try:
        while True:
            # Keep the connection alive
            # dummy_data = np.random.rand(10).tolist()
            # await websocket.send_json({"float_array": dummy_data})
            # await asyncio.sleep(0.1)  # Send data every second, adjust the sleep time as needed

            await websocket.receive_text()

    except Exception as e:
        receivers.remove(websocket)

@app.websocket("/ws/send_data")
async def ws_receive_data(websocket: WebSocket):
    """
    receive an array of floats from the client, and send it to all the connected clients
    """


    while True:
        await websocket.accept()
        try:
            while True:
                # data = await websocket.receive_json()
                data = await websocket.receive_bytes()
                # decode the bytes to a list of floats
                data = {"float_array": (np.frombuffer(data, dtype=np.float16) * 100).tolist()}

                print(data)
                for receiver in receivers:
                    await receiver.send_json(data)

        # except (RuntimeError, ConnectionError) as e:
        except Exception as e:
            print(e)
            pass



