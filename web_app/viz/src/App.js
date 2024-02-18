import logo from './logo.svg';
import './App.css';
import PointCloudRenderer from './components/PointCloudRenderer';
import WebSocketReceiver from './components/DataReceiver';

function App() {
  return (
    <div className="">
      <PointCloudRenderer />
      {/*<WebSocketReceiver />*/}
    </div>
  );
}

export default App;
