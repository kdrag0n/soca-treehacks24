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

struct ARViewRepresentable: UIViewRepresentable {
    let session: ARSession

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        arView.automaticallyConfigureSession = false
        arView.session = session
        return arView
    }
    
    func updateUIView(_ uiView: ARView, context: Context) {
    }
}

struct ContentView: View {
    @StateObject private var ar = ARClient()

    var body: some View {
        VStack {
            if let depthBuffer = ar.depthBuffer {
                if let img = UIImage(pixelBuffer: depthBuffer) {
                    Image(uiImage: img)
                        .frame(width: 500, height: 500)
                        .rotationEffect(.degrees(90))
                        .scaleEffect(2)
                }
            }
            
//            ARViewRepresentable(session: ar.session)
//                .frame(width: 100, height: 100)
            
            Button("Dump") {
                ar.exportPointCloud()
            }
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

#Preview {
    ContentView()
}
