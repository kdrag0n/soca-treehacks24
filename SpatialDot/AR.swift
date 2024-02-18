//
//  AR.swift
//  SpatialDot
//
//  Created by Danny Lin on 2/17/24.
//

import Foundation
import SwiftUI
import ARKit

class ARClient: NSObject, ObservableObject, ARSessionDelegate {
    let session = ARSession()
    private var pointCloud = [simd_float3]()
    @Published var depthBuffer: CVPixelBuffer? = nil
    
    override init() {
        super.init()
        session.delegate = self
        start()
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
                    grayscaleBufAddr.advanced(by: i * 1).storeBytes(of: depthUint8, as: UInt8.self)
                    
                    // add to point clouda
                    // cameraIntrinsics translates to camera width,height space
                    let worldX = (Float(x) - cameraIntrinsics[2][0]) * depthVal / cameraIntrinsics[0][0]
                    let worldY = (Float(y) - cameraIntrinsics[2][1]) * depthVal / cameraIntrinsics[1][1]
                    let worldZ = depthVal
                    // TODO: check confidnece
                    pointCloud.append(simd_float3(worldX, worldY, worldZ))
                }
            }
            //print("depth: min=\(minDepth) max=\(maxDepth) -> \(pointCloud)")
            CVPixelBufferUnlockBaseAddress(grayscaleBuf, .init(rawValue: 0))
            CVPixelBufferUnlockBaseAddress(confidenceBuf, .readOnly)
            CVPixelBufferUnlockBaseAddress(buf, .readOnly)
            depthBuffer = grayscaleBuf
        }
    }
    
    func exportPointCloud() {
        let jsonStr = try! JSONEncoder().encode(pointCloud)
        print(String(data: jsonStr, encoding: .utf8)!)
        let paths = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)
        try! jsonStr.write(to: URL(fileURLWithPath: "\(paths[0])/pointcloud_\(Date.now.timeIntervalSince1970).json"))
    }
}
