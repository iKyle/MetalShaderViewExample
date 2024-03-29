//
//  WeatheringShaderView.swift
//  MetalShaderViewExample
//
//  Created by kylewu on 2024/3/21.
//

import MetalKit

class WeatheringShaderView: MTKView {
    private var dustEffectLayer: DustEffectLayer?
    var surface: Surface?
    
    init?(vertexShaderName: String,
          fragmentShaderName: String) {
        
        super.init(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height/2), device: MetalEngine.shared.device)
        
        let dustEffectLayer = DustEffectLayer()
        dustEffectLayer.position = CGPoint(x: 0, y: 0)
        dustEffectLayer.bounds = CGRect(origin: CGPoint(), size: CGSize(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height/2))
        dustEffectLayer.zPosition = 10.0
        self.dustEffectLayer = dustEffectLayer
        self.layer.addSublayer(dustEffectLayer)
    }
    
    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func draw(_ rect: CGRect) {
        guard let commandBuffer = MetalEngine.shared.impl.commandQueue.makeCommandBuffer() else {
            return
        }
        
        self.dustEffectLayer?.updateItems(deltaTime: 0.01666616665897891)
        
        if self.dustEffectLayer?.hasSurface == false {
            if let surface = Surface(id: 0, device: MetalEngine.shared.device, width: 2496, height: 2688) {
                self.surface = surface
                self.dustEffectLayer?.hasSurface = true
                self.dustEffectLayer?.contentsRect = CGRect(x: 0, y: 0, width: 0.49759615384615385, height: 1.0)
                self.dustEffectLayer?.contents = surface.ioSurface
            }
        }
        
        if let surface = self.surface {
            self.dustEffectLayer?.computeFunc(commandBuffer: commandBuffer)
            
            let renderPass = MTLRenderPassDescriptor()
            renderPass.colorAttachments[0].texture = surface.texture
            renderPass.colorAttachments[0].loadAction = .load
            renderPass.colorAttachments[0].storeAction = .store
            guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPass) else {
                return
            }
                
            let subRect = CGRect(x: 0, y: 0, width: 1242, height: 2688) //surfaceAllocation.effectivePhase.subRect
            renderEncoder.setScissorRect(MTLScissorRect(x: Int(subRect.minX), y: surface.height - Int(subRect.maxY), width: Int(subRect.width), height: Int(subRect.height)))
            self.dustEffectLayer?.renderToLayer(encoder: renderEncoder,
                                        placement: RenderLayerPlacement(effectiveRect: CGRect(x: 0, y: 0, width: 0.49759615384615385, height: 1.0)))
            renderEncoder.endEncoding()
        }
        
        commandBuffer.commit()
        commandBuffer.waitUntilScheduled()
    }
}
