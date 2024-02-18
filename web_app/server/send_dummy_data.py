import asyncio
import websockets
import json
import numpy as np
import ssl

async def send_dummy_data():

    # Create an SSL context that does not verify the certificate
    ssl_context = ssl.SSLContext(ssl.PROTOCOL_TLS_CLIENT)
    ssl_context.check_hostname = False
    ssl_context.verify_mode = ssl.CERT_NONE

    # uri = "ws://localhost:8000/ws/send_data"
    uri = "wss://a109-171-64-77-61.ngrok-free.app/ws/send_data"

    async with websockets.connect(uri, ssl=ssl_context) as websocket:
        while True:
            # await asyncio.sleep(0.1)
            dummy_data = (np.random.rand(10000 * 3) * 100).astype(np.float16).tolist()
            await websocket.send(json.dumps({"float_array": dummy_data}))

async def main():
    await send_dummy_data()

# Run the main function in the asyncio event loop
while True:
    try:
        asyncio.run(main())
    except Exception as e:
        print(e)
        pass

