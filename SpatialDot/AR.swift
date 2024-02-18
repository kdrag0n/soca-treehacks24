//
//  AR.swift
//  SpatialDot
//
//  Created by Danny Lin on 2/17/24.
//

import Foundation
import SwiftUI
import ARKit
import PHASE
import Starscream


private let depthWidth = 256
private let depthHeight = 192
private let depthDownsample = 4
private let depthDW = depthWidth / depthDownsample
private let depthDH = depthHeight / depthDownsample

class ARClient: NSObject, ObservableObject, ARSessionDelegate, URLSessionDelegate, WebSocketDelegate {
  


    
    let view = ARSCNView(frame: .zero)
    let session: ARSession
    private var pointCloud = [Float]()
    @Published var depthBuffer: CVPixelBuffer? = nil
    @Published var contoursPath: CGPath? = nil
    private var oldAnchors = [ARAnchor]()
    
    let engine = AVAudioEngine()
    var players = [AVAudioPlayerNode]()
    let env = AVAudioEnvironmentNode()
//    var webSocket : URLSessionWebSocketTask?
    var webSocket: WebSocket

    override init() {
        
        var request = URLRequest(url: URL(string: "wss://a109-171-64-77-61.ngrok-free.app/ws/send_data")!)
        request.timeoutInterval = 500
        webSocket = WebSocket(request: request)
        print(webSocket)
        webSocket.connect()
        
        session = view.session
        super.init()
        session.delegate = self
        start()
        
        webSocket.delegate = self

        
        
//
//
//        let wssession = URLSession(configuration: .default, delegate: self, delegateQueue: OperationQueue())
//        let url = URL(string: "wss://a109-171-64-77-61.ngrok-free.app/ws/send_data")
//
//        webSocket = wssession.webSocketTask(with: url!)
//        print(webSocket!)
//        webSocket!.resume()
//        print("this is running")


        
//
//        engine.attach(env)
//
//        // load wav
//        let url = Bundle.main.url(forResource: "pinknoise", withExtension: "wav")!
//        let audioFile = try! AVAudioFile(forReading: url)
//        let audioBuffer = AVAudioPCMBuffer(pcmFormat: audioFile.processingFormat, frameCapacity: AVAudioFrameCount(audioFile.length))!
//        try! audioFile.read(into: audioBuffer)
//
//        players.reserveCapacity(depthDW * depthDH)
//        for i in 0..<(depthDW*depthDH) {
//            let player = AVAudioPlayerNode()
//            player.renderingAlgorithm = .sphericalHead
//            players.append(player)
//            engine.attach(player)
//            engine.connect(player, to: env, format: audioBuffer.format)
//        }
//        engine.connect(env, to: engine.outputNode, format: engine.outputNode.outputFormat(forBus: 0))
//        try! engine.start()
    }
    
    
//    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
//            print("Connected to server")
//    }
//
//    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
//        print("Disconnect from Server \(String(describing: reason))")
//    }
    

    func didReceive(event: Starscream.WebSocketEvent, client: Starscream.WebSocketClient) {
        var isConnected = false
        switch event {
        case .connected(let headers):
            isConnected = true
            print("websocket is connected: \(headers)")
        case .disconnected(let reason, let code):
            isConnected = false
            print("websocket is disconnected: \(reason) with code: \(code)")
        case .text(let string):
            print("Received text: \(string)")
        case .binary(let data):
            print("Received data: \(data.count)")
        case .ping(_):
            break
        case .pong(_):
            break
        case .viabilityChanged(_):
            break
        case .reconnectSuggested(_):
            break
        case .cancelled:
            isConnected = false
        case .error(let error):
            isConnected = false
            case .peerClosed:
                   break
        }
    }
    
    func start() {
        let config = ARWorldTrackingConfiguration()
        // smoothedSceneDepth has too much motion blur
        config.frameSemantics = [.sceneDepth]
        session.run(config)
    }
    
    func pause() {
        session.pause()
    }
    
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        if let depth = frame.sceneDepth {
            var cameraIntrinsics = frame.camera.intrinsics
            let cameraResolution = frame.camera.imageResolution
            
            let colorImage = frame.capturedImage
            
            let buf = depth.depthMap
            let width = CVPixelBufferGetWidth(buf)
            let height = CVPixelBufferGetHeight(buf)
            
            let scaleRes = simd_float2(x: Float(cameraResolution.width) / Float(width),
                                                    y: Float(cameraResolution.height) / Float(height))
            cameraIntrinsics[0][0] /= scaleRes.x
            cameraIntrinsics[1][1] /= scaleRes.y
            cameraIntrinsics[2][0] /= scaleRes.x
            cameraIntrinsics[2][1] /= scaleRes.y
            
            // 256x192
            // kCVPixelFormatType_DepthFloat32 = 'fdep'
            CVPixelBufferLockBaseAddress(buf, .readOnly)
            let bufAddr = CVPixelBufferGetBaseAddress(buf)!
            
            // L008 format
            let confidenceBuf = depth.confidenceMap!
            CVPixelBufferLockBaseAddress(confidenceBuf, .readOnly)
            let confidenceBufAddr = CVPixelBufferGetBaseAddress(buf)!
            
            // create camera preview
            var grayscaleBuf: CVPixelBuffer?
            CVPixelBufferCreate(nil, width, height, kCVPixelFormatType_OneComponent8, nil, &grayscaleBuf)
            guard let grayscaleBuf else {
                fatalError("failed to create buf")
            }
            CVPixelBufferLockBaseAddress(grayscaleBuf, .init(rawValue: 0))
            let grayscaleBufAddr = CVPixelBufferGetBaseAddress(grayscaleBuf)!
            // two-pass: find min/max
            var minDepth: Float32 = .infinity
            var maxDepth: Float32 = -.infinity
            for i in 0..<width*height {
                let depthVal = bufAddr.advanced(by: i * 4).load(as: Float32.self)
                if depthVal < minDepth {
                    minDepth = depthVal
                }
                if depthVal > maxDepth {
                    maxDepth = depthVal
                }
            }
            pointCloud.removeAll()
            pointCloud.reserveCapacity(width * height)
            for x in 0..<width {
                for y in 0..<height {
                    let i = y*width + x
                    let depthVal = bufAddr.advanced(by: i * 4).load(as: Float32.self)
                    let pixelVal = max(0, min(depthVal / 5, 1))
                    let depthUint8 = UInt8(max(0, min(pow(pixelVal, 1/2.2) * 255, 255)))
                    // print("depth = \(depthVal)")
                    if x % 3 == 0 && y % 3 == 0 {
                        grayscaleBufAddr.advanced(by: i * 1).storeBytes(of: depthUint8, as: UInt8.self)
                    } else {
                        grayscaleBufAddr.advanced(by: i * 1).storeBytes(of: 0, as: UInt8.self)
                    }
                    
                    // add to point clouda
                    // cameraIntrinsics translates to camera width,height space
                    let worldX = (Float(x) - cameraIntrinsics[2][0]) * depthVal / cameraIntrinsics[0][0]
                    let worldY = (Float(y) - cameraIntrinsics[2][1]) * depthVal / cameraIntrinsics[1][1]
                    let worldZ = depthVal
                    // TODO: check confidnece
                    pointCloud.append(worldX)
                    pointCloud.append(worldY)
                    pointCloud.append(worldZ)
                }
            }
            //print("depth: min=\(minDepth) max=\(maxDepth) -> \(pointCloud)")
            CVPixelBufferUnlockBaseAddress(grayscaleBuf, .init(rawValue: 0))
            CVPixelBufferUnlockBaseAddress(confidenceBuf, .readOnly)
            CVPixelBufferUnlockBaseAddress(buf, .readOnly)
            depthBuffer = grayscaleBuf
            onNewPointCloud(pointCloud)
            
            return
            
            for anchor in oldAnchors {
                session.remove(anchor: anchor)
            }
            oldAnchors.removeAll()
            
            let contoursReq = VNDetectContoursRequest()
            contoursReq.revision = VNDetectContourRequestRevision1
            contoursReq.detectsDarkOnLight = false
            contoursReq.contrastAdjustment = 1.0
            contoursReq.maximumImageDimension = 256
            // orientation is wrong but doesnt matter
            let reqHandler = VNImageRequestHandler(cvPixelBuffer: grayscaleBuf, orientation: .up)
            try! reqHandler.perform([contoursReq])
            if let contours = contoursReq.results?.first {
//                print("contours: count=\(contours.contourCount) toplevel=\(contours.topLevelContourCount)")// path=\(contours.normalizedPath)")
                contoursPath = contours.normalizedPath
                
                for ci in 0..<contours.contourCount {
                    let contour = try! contours.contour(at: ci)
                    var totalX: Float = 0
                    var totalY: Float = 0
                    var totalZ: Float = 0
                    for pt in contour.normalizedPoints {
                        let imgX = pt.x * Float(width)
                        let imgY = pt.y * Float(height)
                        let imgXint = max(0, min(Int(imgX), width-1))
                        let imgYint = max(0, min(Int(imgY), height-1))
                        let depthVal = bufAddr.advanced(by: (imgYint*width + imgXint) * 4).load(as: Float32.self)
                        
                        
                        let worldX = (Float(imgX) - cameraIntrinsics[2][0]) * depthVal / cameraIntrinsics[0][0]
                        let worldY = (Float(imgY) - cameraIntrinsics[2][1]) * depthVal / cameraIntrinsics[1][1]
                        let worldZ = -depthVal
                        
                        totalX += worldX
                        totalY += worldY
                        totalZ += worldZ
                    }
                    
                    let centerX = totalX / Float(contour.normalizedPoints.count)
                    let centerY = totalY / Float(contour.normalizedPoints.count)
                    let centerZ = totalZ / Float(contour.normalizedPoints.count)
//                    print("contour \(ci): \(centerX) \(centerY) \(centerZ)")
                    var translation = matrix_identity_float4x4
                    translation.columns.3.x = centerX
                    translation.columns.3.y = centerY
                    translation.columns.3.z = centerZ
                    let transform = simd_mul(frame.camera.transform, translation)
                    let anchor = ARAnchor(transform: transform)
                    session.add(anchor: anchor)
                    oldAnchors.append(anchor)
                }
            }
        }
    }
    
    func exportPointCloud() {
        let jsonStr = try! JSONEncoder().encode(pointCloud)
//        print(String(data: jsonStr, encoding: .utf8)!)
        let paths = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)
        try! jsonStr.write(to: URL(fileURLWithPath: "\(paths[0])/pointcloud_\(Date.now.timeIntervalSince1970).json"))
    }


   

    // flat array of x,y,z - 256x192
    func onNewPointCloud(_ pointCloud: [Float]) {

        let n = 3 000 // TODO will break
        let indicies = (0..<n).map { _ in Int.random(in: 0..<pointCloud.count / 3) }

        var points = [Float16]()
        for i in indicies {
            let x = pointCloud[i * 3]
            let y = pointCloud[i * 3 + 1]
            let z = pointCloud[i * 3 + 2]
            points.append(Float16(x))
            points.append(Float16(y))
            points.append(Float16(z))
        }
        
        /*webSocket.write(data: [points[0]])*/
        // write out float array into a data object (binary) 
        // by converting to  binary


//        let data = Data(string: points)
        let data = Data(bytes: &points, count: points.count * MemoryLayout<Float16>.stride)


        webSocket.write(data: data)
//        webSocket.write(string: "hellooo", completion: handleCompletion)
//        print(webSocket)


        // now, we want to take these points and send them through a websocket
        // the code below is a direct translation of the python code in the server
        /*async def send_dummy_data():

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
                    await websocket.send(json.dumps({"float_array": dummy_data}))*/

        /*let sslContext = SSLContext()*/
        /*sslContext.checkHostname = false*/
        /*sslContext.verifyMode = .none*/


    }
}


