import React, { useEffect, useState } from 'react';

function WebSocketReceiver() {
    const [floatArrays, setFloatArrays] = useState([]);

    useEffect(() => {
        // Connect to the WebSocket server
        const ws = new WebSocket('ws://localhost:8000/ws/get_data');

        // Set up the WebSocket event listeners
        ws.addEventListener("open", (event) => {
            ws.send("Connection established")
        })

        // Listen for messages
        ws.addEventListener("message", (event) => {
            //console.log("Message from server ", event.data)

        })

        return () => {
            ws.close();
        }
    }, []);

    useEffect(() => {
        console.log('floatArrays:', floatArrays);
    }, [floatArrays]);

    return (
        <div>
            this!
        </div>
    );
}

export default WebSocketReceiver;
