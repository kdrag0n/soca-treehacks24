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
import CoreMotion

private let depthWidth = 256
private let depthHeight = 192
private let depthDownsample = 4
private let depthDW = depthWidth / depthDownsample
private let depthDH = depthHeight / depthDownsample
private let nSounds = 1

class EwmaF32 {
    private var value: Float
    private let weight: Float
    
    init(initial: Float, weight: Float) {
        self.value = initial
        self.weight = weight
    }
    
    func update(_ sample: Float) -> Float {
        value = value*weight + sample*(1.0-weight)
        return value
    }
}
private let ewmaWeight: Float = 0.2

class ARClient: NSObject, ObservableObject, ARSessionDelegate {
    let view = ARSCNView(frame: .zero)
    let session: ARSession
    private var pointCloud = [simd_float3]()
    @Published var depthBuffer: CVPixelBuffer? = nil
    @Published var contoursPath: CGPath? = nil
    private var oldAnchors = [ARAnchor]()
    
    let engine = AVAudioEngine()
    var players = [AVAudioPlayerNode]()
    let env = AVAudioEnvironmentNode()
    private let hpMotion = CMHeadphoneMotionManager()
    private let deviceMotion = CMMotionManager()
    let startTime = DispatchTime.now()
    var lastPoint: (Float, Float, Float) = (0,0,0)
    
    private var initialHpAttitude: CMAttitude? = nil
    private var initialDeviceAttitude: CMAttitude? = nil
    private var lastDevRotation: simd_float3x3? = nil
    
    private let ewmaX = EwmaF32(initial: 0, weight: ewmaWeight)
    private let ewmaY = EwmaF32(initial: 0, weight: ewmaWeight)
    private let ewmaZ = EwmaF32(initial: 0, weight: ewmaWeight)
    
    override init() {
        session = view.session
        super.init()
        session.delegate = self
        start()
        print("forward  = \(PHASEObject.forward)")
        print("right  = \(PHASEObject.right)")
        print("up  = \(PHASEObject.up)")
        
//        env.distanceAttenuationParameters.distanceAttenuationModel = .exponential
        print("model=\(env.distanceAttenuationParameters.distanceAttenuationModel)")
        print("referenceDistance=\(env.distanceAttenuationParameters.referenceDistance)")
        print("referenceDistance=\(env.distanceAttenuationParameters.referenceDistance)")
        env.distanceAttenuationParameters.referenceDistance = 1
        env.renderingAlgorithm = .HRTF
        engine.attach(env)
        
        // load wav
        let url = Bundle.main.url(forResource: "music1trim", withExtension: "wav")!
        let audioFile = try! AVAudioFile(forReading: url)
        let audioBuffer = AVAudioPCMBuffer(pcmFormat: audioFile.processingFormat, frameCapacity: AVAudioFrameCount(audioFile.length))!
        try! audioFile.read(into: audioBuffer)
        
        print("begin inits")
        players.reserveCapacity(nSounds)
        for i in 0..<nSounds {
            if i % 100 == 0 {
                print("\(i)")
            }
            let player = AVAudioPlayerNode()
            player.renderingAlgorithm = .HRTF
            player.position = AVAudioMake3DPoint(100, 100, 100)
            players.append(player)
            engine.attach(player)
            engine.connect(player, to: env, format: audioBuffer.format)
        }
        print("end inits")
        engine.connect(env, to: engine.outputNode, format: engine.outputNode.outputFormat(forBus: 0))
        try! engine.start()
        for player in players {
            player.scheduleBuffer(audioBuffer, at: nil, options: .loops, completionHandler: nil)
            player.play()
        }
        
        deviceMotion.startDeviceMotionUpdates(to: OperationQueue.current!) { [weak self] motion, error in
            guard let self, let motion else { return }
            if initialDeviceAttitude == nil {
                print("initial device = \(motion.attitude)")
                initialDeviceAttitude = motion.attitude
            } else {
                let curDev = motion.attitude
                curDev.multiply(byInverseOf: initialDeviceAttitude!)
                let r = curDev.rotationMatrix
                lastDevRotation = simd_float3x3(rotationMatrix: r).inverse
            }
        }
        hpMotion.startDeviceMotionUpdates(to: OperationQueue.current!) { [weak self] motion, error in
            guard let self, let motion else { return }
//            print("Headphones motion: \(motion)")
            print("Headphones attitude angular: \(motion.attitude)")
//            print("Headphones attitude rotation matrix: \(motion.attitude.rotationMatrix)")
//            print("\(motion.attitude.pitch)")
            env.listenerAngularOrientation = AVAudio3DAngularOrientation(yaw: Float(motion.attitude.yaw) / .pi * 180, pitch: Float(motion.attitude.pitch) / .pi * 180, roll: Float(motion.attitude.roll) / .pi * 180)
            if initialHpAttitude == nil {
                print("initial HP = \(motion.attitude)")
                initialHpAttitude = motion.attitude
            }
        }
    }
    
    func advancePos() {
        
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
            
            let scaleX = Float(cameraResolution.width) / Float(width)
            let scaleY = Float(cameraResolution.height) / Float(height)
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
            CVPixelBufferCreate(nil, width, height, kCVPixelFormatType_32ARGB, nil, &grayscaleBuf)
            guard let grayscaleBuf else {
                fatalError("failed to create buf")
            }
            CVPixelBufferLockBaseAddress(grayscaleBuf, .init(rawValue: 0))
            let grayscaleBufAddr = CVPixelBufferGetBaseAddress(grayscaleBuf)!
            // two-pass: find min/max
            var minDepth: Float32 = .infinity
            var maxDepth: Float32 = -.infinity
            var lastMinX = 0
            var lastMinY = 0
            for x in 0..<width {
                for y in 0..<height {
                    let i = y*width + x
                    if x % 3 != 0 || y % 3 != 0 {
                        continue
                    }
                    let depthVal = bufAddr.advanced(by: i * 4).load(as: Float32.self)
                    if depthVal < minDepth {
                        minDepth = depthVal
                        lastMinX = x
                        lastMinY = y
                    }
                    if depthVal > maxDepth {
                        maxDepth = depthVal
                    }
                }
            }
//            print("min=\(minDepth) max=\(maxDepth)")
            pointCloud.removeAll()
            pointCloud.reserveCapacity(width * height)
            for x in 0..<width {
                for y in 0..<height {
                    let i = y*width + x
                    let depthVal = bufAddr.advanced(by: i * 4).load(as: Float32.self)
                    let pixelVal = max(0, min(depthVal / 5, 1))
                    let depthUint8 = UInt32(max(0, min(pow(pixelVal, 1/2.2) * 255, 255)))
                    // print("depth = \(depthVal)")
                    if x % 3 != 0 || y % 3 != 0 {
                        grayscaleBufAddr.advanced(by: i * 4).storeBytes(of: (UInt32(0xff000000) | (depthUint8 << 16) | (depthUint8 << 8) | (depthUint8)).bigEndian, as: UInt32.self)
                        continue
                    }
                    if lastMinX == x && lastMinY == y {
                        grayscaleBufAddr.advanced(by: i * 4).storeBytes(of: UInt32(0xffff0000).bigEndian, as: UInt32.self)
                    } else {
                        grayscaleBufAddr.advanced(by: i * 4).storeBytes(of: UInt32(0xff000000).bigEndian, as: UInt32.self)
                    }
                    
                    // add to point cloud
                    // cameraIntrinsics translates to camera width,height space
                    let worldX = (Float(x) - cameraIntrinsics[2][0]) * depthVal / cameraIntrinsics[0][0]
                    let worldY = (Float(y) - cameraIntrinsics[2][1]) * depthVal / cameraIntrinsics[1][1]
                    let worldZ = depthVal
                    //let worldVec = frame.camera.intrinsics.inverse * simd_float3(Float(x)*scaleX, Float(y)*scaleY, depthVal)
                    //let worldVec = frame.camera.unprojectPoint(CGPoint(x: Float(x)*scaleX, y: Float(y)*scaleY), )
                    
                    // TODO: check confidnece
//                    pointCloud.append(simd_float3(worldVec))
//                    pointCloud.append(simd_float3(worldX, worldY, worldZ))
                    pointCloud.append(simd_float3(Float(x)/Float(width), Float(y)/Float(height), worldZ))
                }
            }
            
            for anchor in oldAnchors {
                session.remove(anchor: anchor)
            }
            oldAnchors.removeAll()
            
            // sort by distance, closest (least z) first
            pointCloud.sort { $0.magnitude < $1.magnitude }
//            print("first = \(pointCloud.first!)")
//            print("camera = \(frame.camera.projectionMatrix)")
            //env.listenerPosition = AVAudioMake3DPoint(0, 0, 0)
            //env.listenerPosition = AVAudioMake3DPoint(frame.camera.projectionMatrix.columns.3.x, frame.camera.projectionMatrix.columns.3.y, frame.camera.projectionMatrix.columns.3.z)
            //env.listenerPosition = AVAudioMake3DPoint(frame.camera.transform.columns.0.w, frame.camera.transform.columns.1.w, frame.camera.transform.columns.2.w)
            var listenerPos = simd_float3(0.5,0.5,0)
            if let lastDevRotation {
                listenerPos = lastDevRotation * listenerPos
            }
            env.listenerPosition = listenerPos.av
//            env.listenerPosition = AVAudioMake3DPoint(0, 0, 0)
            
            // set audio pooints
            for i in 0..<nSounds {
                var pt = pointCloud[i]
                pt = simd_float3(ewmaX.update(pt.x), ewmaY.update(pt.y), ewmaZ.update(pt.z))
                if let lastDevRotation {
                    pt = lastDevRotation * pt
                }
           //     print("audio at \(pt) = \(sqrt(pt.x*pt.x + pt.y*pt.y + pt.z+pt.z))")
                let avPoint = simd_float3(-pt[1] * 30, -pt[0] * 30, -pt[2] * 30).av
               // print("\(pt)")
//                let avPoint = AVAudioMake3DPoint(-80, 0, 0)
//                let rad = -(abs(Float(DispatchTime.now().uptimeNanoseconds - startTime.uptimeNanoseconds) / 1e9) / 5 * (2*Float.pi))
//                let avPoint = AVAudioMake3DPoint(cos(rad) * 40, sin(rad) * 40, 0)
                players[i].position = avPoint
                //players[0].position = AVAudioMake3DPoint(0, 20, 0)
                
                var translation = matrix_identity_float4x4
                translation.columns.3.x = pt[0]
                translation.columns.3.y = -pt[1]
                translation.columns.3.z = -pt[2]
                let transform = simd_mul(frame.camera.transform, translation)
                let anchor = ARAnchor(transform: transform)
                session.add(anchor: anchor)
                oldAnchors.append(anchor)
                
                lastPoint = (-pt[1] * 30, -pt[0] * 30, -pt[2] * 30)
            }
            //print("depth: min=\(minDepth) max=\(maxDepth) -> \(pointCloud)")
            CVPixelBufferUnlockBaseAddress(grayscaleBuf, .init(rawValue: 0))
            CVPixelBufferUnlockBaseAddress(confidenceBuf, .readOnly)
            CVPixelBufferUnlockBaseAddress(buf, .readOnly)
            depthBuffer = grayscaleBuf
            onNewPointCloud(pointCloud)
            
            return
            
            let contoursReq = VNDetectContoursRequest()
            contoursReq.revision = VNDetectContourRequestRevision1
            contoursReq.detectsDarkOnLight = false
            contoursReq.contrastAdjustment = 1.0
            contoursReq.maximumImageDimension = 256
            // orientation is wrong but doesnt matter
            let reqHandler = VNImageRequestHandler(cvPixelBuffer: grayscaleBuf, orientation: .up)
            try! reqHandler.perform([contoursReq])
            if let contours = contoursReq.results?.first {
                print("contours: count=\(contours.contourCount) toplevel=\(contours.topLevelContourCount)")// path=\(contours.normalizedPath)")
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
                    print("contour \(ci): \(centerX) \(centerY) \(centerZ)")
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
        print(String(data: jsonStr, encoding: .utf8)!)
        let paths = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)
        try! jsonStr.write(to: URL(fileURLWithPath: "\(paths[0])/pointcloud_\(Date.now.timeIntervalSince1970).json"))
    }
    
    // flat array of x,y,z - 256x192
    func onNewPointCloud(_ pointCloud: [simd_float3]) {
        // TODO
    }
}


extension simd_float3 {
    var magnitude: Float {
        sqrt(x*x + y*y + z*z)
    }
    
    var av: AVAudio3DPoint {
        AVAudioMake3DPoint(x, y,    z)
    }
    
    init(_ x: Double, _ y: Double, _ z: Double) {
        self.init(Float(x), Float(y), Float(z))
    }
}



extension simd_float3x3 {
    init(rotationMatrix r: CMRotationMatrix) {
        self.init([
            simd_float3(Float(-r.m11), Float(r.m13), Float(r.m12)),
            simd_float3(Float(-r.m31), Float(r.m33), Float(r.m32)),
            simd_float3(Float(-r.m21), Float(r.m23), Float(r.m22)),
        ])
    }
}
