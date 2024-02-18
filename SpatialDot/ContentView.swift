//
//  ContentView.swift
//  SpatialDot
//
//  Created by Danny Lin on 2/17/24.
//

import SwiftUI
import VideoToolbox
import ARKit
import RealityKit
import SceneKit

class SceneDelegate: NSObject, ARSCNViewDelegate {
    var audioSource = SCNAudioSource(fileNamed: "pinknoise.wav")!

    override init() {
        super.init()
        audioSource.loops = true
        audioSource.load()
    }

    // add red dot with sound for every anchor
    //func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {

    func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
        print("new node:\(anchor.transform)")
        // create node
        let node = SCNNode()
        node.simdTransform = anchor.transform

        let sphere = SCNSphere(radius: 0.01)
        sphere.firstMaterial?.diffuse.contents = UIColor.red
        let sphereNode = SCNNode(geometry: sphere)
        node.addChildNode(sphereNode)
        
        let audioPlayer = SCNAudioPlayer(source: audioSource)
        sphereNode.addAudioPlayer(audioPlayer)

        return node
    }

    // update red dot position
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        // /Users/dragon/code/hackathon/spatialdot-treehacks24/SpatialDot/ContentView.swift:36:60 Value of type 'simd_float4x4' has no member 'position'

        //node.childNodes.first?.position = anchor.transform.position
        
        node.simdTransform = anchor.transform
    }

    // remove red dot
    func renderer(_ renderer: SCNSceneRenderer, didRemove node: SCNNode, for anchor: ARAnchor) {
        node.removeFromParentNode()
    }
}

struct ARViewRepresentable: UIViewRepresentable {
    let ar: ARClient
    @State private var delegate = SceneDelegate()

    func makeUIView(context: Context) -> ARSCNView {
        
        let arView = ar.view
        arView.delegate = delegate
        arView.audioEnvironmentNode.distanceAttenuationParameters.distanceAttenuationModel = .exponential
        arView.audioEnvironmentNode.distanceAttenuationParameters.rolloffFactor = 5
        return arView
    }
    
    func updateUIView(_ uiView: ARSCNView, context: Context) {
    }
}

struct ScaledBezier: Shape {
    let bezierPath: CGPath

    func path(in rect: CGRect) -> Path {
        let path = Path(bezierPath)

        // Figure out how much bigger we need to make our path in order for it to fill the available space without clipping.
        let multiplier = min(rect.width, rect.height)

        // Create an affine transform that uses the multiplier for both dimensions equally.
        let transform = CGAffineTransform(scaleX: multiplier, y: multiplier)

        // Apply that scale and send back the result.
        return path.applying(transform)
    }
}

struct ContentView: View {
    @StateObject private var ar = ARClient()

    var body: some View {
        ScrollView {
            VStack {
                if let depthBuffer = ar.depthBuffer {
                    if let img = UIImage(pixelBuffer: depthBuffer)
                    {
                        ZStack {
                            Image(uiImage: img)
                                .frame(width: 384, height: 512)
                            if let path = ar.contoursPath {
                                ScaledBezier(bezierPath: path)
                                    .stroke(.red, lineWidth: 2)
                                    .scaleEffect(x: -1, y: 1)
                                    .rotationEffect(.degrees(180))
                                    .frame(width: 384, height: 512)
                            }
                        }
                        .rotationEffect(.degrees(90))
                        .scaleEffect(2)
                    }
                }
                
                ARViewRepresentable(ar: ar)
                    .frame(width: 500, height: 500)
                
                Button("Dump") {
                    ar.exportPointCloud()
                }
            }
        }
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = true
            
        }
        .padding()
    }
}

extension UIImage {
    public convenience init?(pixelBuffer: CVPixelBuffer) {
        var cgImage: CGImage?
        VTCreateCGImageFromCVPixelBuffer(pixelBuffer, options: nil, imageOut: &cgImage)

        guard let cgImage else { return nil }
        self.init(cgImage: cgImage)
    }
}
