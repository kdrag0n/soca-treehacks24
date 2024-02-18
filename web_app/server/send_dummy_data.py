import websockets
import asyncio

async def send_dummy_data():
    uri = "ws://localhost:8000/ws/send_data"
    async with websockets.connect(uri) as websocket:
        await websocket.send('{"float_array": [1.0, 2.0, 3.0]}')

asyncio.get_event_loop().run_until_complete(send_dummy_data())