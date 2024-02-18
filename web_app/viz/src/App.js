import logo from './logo.svg';
import { extend, Canvas, useFrame, useLoader, useThree } from '@react-three/fiber'
import './App.css';
import PointCloudRenderer from './components/PointCloudRenderer';
import WebSocketReceiver from './components/DataReceiver';

function App() {
  return (
    <div className="h-screen">
        <PointCloudRenderer />
      {/*<WebSocketReceiver />*/}
    </div>
  );
}

export default App;
