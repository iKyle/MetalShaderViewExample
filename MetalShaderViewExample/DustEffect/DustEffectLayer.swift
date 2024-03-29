//
//  DustEffectLayer.swift
//  MetalShaderViewExample
//
//  Created by kylewu on 2024/3/24.
//

import Foundation
import MetalKit

private var metalLibraryValue: MTLLibrary?
func metalLibrary(device: MTLDevice) -> MTLLibrary? {
    if let metalLibraryValue {
        return metalLibraryValue
    }

    guard let library = try? device.makeDefaultLibrary() else {
        return nil
    }
    
    metalLibraryValue = library
    return library
}

public protocol RenderToLayerState: AnyObject {
    var pipelineState: MTLRenderPipelineState { get }
    
    init?(device: MTLDevice)
}

public final class DustEffectLayer: MetalEngineSubjectLayer {
//    public var internalData: MetalEngineSubjectInternalData?
    
    private final class Item {
        let frame: CGRect
        let texture: MTLTexture
        var phaseTmp: Float = 0.0
        
        var phase: Float {
            get {
                return self.phaseTmp
            }
            set {
                self.phaseTmp = newValue
            }
        }
        var particleBufferIsInitialized: Bool = false
        var particleBuffer: SharedBuffer?
        
        init?(frame: CGRect) {
            self.frame = frame
            
            guard let cgImage = UIImage(named: "StockCake-Autumn")?.cgImage,
                  let texture = try? MTKTextureLoader(device: MetalEngine.shared.device).newTexture(cgImage: cgImage, options: [.SRGB: false as NSNumber]) else {
                return nil
            }
            self.texture = texture
        }
    }
    
    private final class RenderState: RenderToLayerState {
        let pipelineState: MTLRenderPipelineState
        
        init?(device: MTLDevice) {
            guard let library = metalLibrary(device: device) else {
                return nil
            }
            guard let vertexFunction = library.makeFunction(name: "dustEffectVertex"), let fragmentFunction = library.makeFunction(name: "dustEffectFragment") else {
                return nil
            }
            
            let pipelineDescriptor = MTLRenderPipelineDescriptor()
            pipelineDescriptor.vertexFunction = vertexFunction
            pipelineDescriptor.fragmentFunction = fragmentFunction
            pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
            pipelineDescriptor.colorAttachments[0].isBlendingEnabled = true
            pipelineDescriptor.colorAttachments[0].rgbBlendOperation = .add
            pipelineDescriptor.colorAttachments[0].alphaBlendOperation = .add
            pipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = .one
            pipelineDescriptor.colorAttachments[0].sourceAlphaBlendFactor = .one
            pipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
            pipelineDescriptor.colorAttachments[0].destinationAlphaBlendFactor = .one
            guard let pipelineState = try? device.makeRenderPipelineState(descriptor: pipelineDescriptor) else {
                return nil
            }
            self.pipelineState = pipelineState
        }
    }
    
    final class DustComputeState: ComputeState {
        let computePipelineStateInitializeParticle: MTLComputePipelineState
        let computePipelineStateUpdateParticle: MTLComputePipelineState
        
        required init?(device: MTLDevice) {
            guard let library = metalLibrary(device: device) else {
                return nil
            }
            
            guard let functionDustEffectInitializeParticle = library.makeFunction(name: "dustEffectInitializeParticle") else {
                return nil
            }
            guard let computePipelineStateInitializeParticle = try? device.makeComputePipelineState(function: functionDustEffectInitializeParticle) else {
                return nil
            }
            self.computePipelineStateInitializeParticle = computePipelineStateInitializeParticle
            
            guard let functionDustEffectUpdateParticle = library.makeFunction(name: "dustEffectUpdateParticle") else {
                return nil
            }
            guard let computePipelineStateUpdateParticle = try? device.makeComputePipelineState(function: functionDustEffectUpdateParticle) else {
                return nil
            }
            
            self.computePipelineStateUpdateParticle = computePipelineStateUpdateParticle
        }
    }
    
//    private var updateLink: SharedDisplayLinkDriver.Link?
    private var items: [Item] = []
    private var lastTimeStep: Double = 0.0
    private var phaseTmp = 0.0
    public var animationSpeed: Float = 1.0
    
    public var becameEmpty: (() -> Void)?
    
    override public init() {
        super.init()
        
        self.isOpaque = false
        self.backgroundColor = nil
        
//        self.didEnterHierarchy = { [weak self] in
//            guard let self else {
//                return
//            }
//            self.updateNeedsAnimation()
//        }
//        self.didExitHierarchy = { [weak self] in
//            guard let self else {
//                return
//            }
//            self.updateNeedsAnimation()
//        }
        self.addItem(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height/2))
    }
    
    override public init(layer: Any) {
        super.init(layer: layer)
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private var lastUpdateTimestamp: Double?
    
    public func updateItems(deltaTime: Double) {
        let timestamp = CACurrentMediaTime()
        let localDeltaTime: Double
        if let lastUpdateTimestamp = self.lastUpdateTimestamp {
            localDeltaTime = timestamp - lastUpdateTimestamp
        } else {
            localDeltaTime = 0.0
        }
        self.lastUpdateTimestamp = timestamp
        
        let deltaTimeValue: Double
        if localDeltaTime <= 0.001 || localDeltaTime >= 0.2 {
            deltaTimeValue = deltaTime
        } else {
            deltaTimeValue = localDeltaTime
        }
        
        self.lastTimeStep = deltaTimeValue
        
        var didRemoveItems = false
        for i in (0 ..< self.items.count).reversed() {
            //不停的计算粒子应该要移动的因素
            self.items[i].phase += Float(deltaTimeValue) * self.animationSpeed / Float(1.0)
            
            if self.items[i].phase >= 4.0 {
                self.items.remove(at: i)
                didRemoveItems = true
            }
        }
        self.updateNeedsAnimation()
        
        if didRemoveItems && self.items.isEmpty {
            self.becameEmpty?()
        }
    }
    
    private func updateNeedsAnimation() {
//        if !self.items.isEmpty && self.isInHierarchy {
//            if self.updateLink == nil {
//                self.updateLink = SharedDisplayLinkDriver.shared.add(framesPerSecond: .max, { [weak self] deltaTime in
//                    guard let self else {
//                        return
//                    }
//                    self.updateItems(deltaTime: 0.01666616665897891)
//                    self.setNeedsUpdate()
//                })
//            }
//        } else {
//            if self.updateLink != nil {
//                self.updateLink = nil
//            }
//        }
    }
    
    public func addItem(frame: CGRect) {
        if let item = Item(frame: frame) {
            self.items.append(item)
            self.updateNeedsAnimation()
//            self.setNeedsUpdate()
        }
    }
    
    public func computeFunc(commandBuffer: MTLCommandBuffer) {
        let lastTimeStep = self.lastTimeStep
        self.lastTimeStep = 0.0
        
        guard let computeEncoder = commandBuffer.makeComputeCommandEncoder() else {
            return
        }
        
        for item in self.items {
            guard let state = DustComputeState(device: MetalEngine.shared.device) else {
                continue
            }
            
            let itemFrame = item.frame
            let particleColumnCount = Int(itemFrame.width)
            let particleRowCount = Int(itemFrame.height)
            let particleCount = particleColumnCount * particleRowCount
            let threadgroupSize = MTLSize(width: 32, height: 1, depth: 1)
            let threadgroupCount = MTLSize(width: (particleRowCount * particleColumnCount + threadgroupSize.width - 1) / threadgroupSize.width, height: 1, depth: 1)
        
            if item.particleBuffer == nil {
                if let particleBuffer = MetalEngine.shared.sharedBuffer(spec: BufferSpec(length: particleCount * 4 * (4 + 1))) {
                    item.particleBuffer = particleBuffer
                }
            }
            
            guard let particleBuffer = item.particleBuffer else { continue }
            computeEncoder.setBuffer(particleBuffer.buffer, offset: 0, index: 0)
            
            if !item.particleBufferIsInitialized {
                item.particleBufferIsInitialized = true
                computeEncoder.setComputePipelineState(state.computePipelineStateInitializeParticle)
                computeEncoder.dispatchThreadgroups(threadgroupCount, threadsPerThreadgroup: threadgroupSize)
            }
            
            if lastTimeStep != 0.0 {
                computeEncoder.setComputePipelineState(state.computePipelineStateUpdateParticle)
                var particleCount = SIMD2<UInt32>(UInt32(particleColumnCount), UInt32(particleRowCount))
                computeEncoder.setBytes(&particleCount, length: 4 * 2, index: 1)
                //phase决定粒子位移的因素
                var phase = item.phase
                computeEncoder.setBytes(&phase, length: 4, index: 2)
                //timeStep决定粒子位移的速度
                var timeStep: Float = Float(lastTimeStep) / Float(1.0)
                timeStep *= 2.0
                computeEncoder.setBytes(&timeStep, length: 4, index: 3)
                computeEncoder.dispatchThreadgroups(threadgroupCount, threadsPerThreadgroup: threadgroupSize)
            }
        }
        
        computeEncoder.endEncoding()
    }
    
    public func renderToLayer(encoder: MTLRenderCommandEncoder, placement: RenderLayerPlacement) {
        let containerSize = self.bounds.size
        
        for item in self.items {
            guard let particleBuffer = item.particleBuffer,
                  let state = RenderState(device: MetalEngine.shared.device) else {
                continue
            }
            
            var itemFrame = item.frame
            itemFrame.origin.y = containerSize.height - itemFrame.maxY
            
            let particleColumnCount = Int(itemFrame.width)
            let particleRowCount = Int(itemFrame.height)
            let particleCount = particleColumnCount * particleRowCount
            
//            var effectiveRect = placement.effectiveRect
//            effectiveRect.origin.x += itemFrame.minX / containerSize.width * effectiveRect.width
//            effectiveRect.origin.y += itemFrame.minY / containerSize.height * effectiveRect.height
//            effectiveRect.size.width = itemFrame.width / containerSize.width * effectiveRect.width
//            effectiveRect.size.height = itemFrame.height / containerSize.height * effectiveRect.height
            
            encoder.setRenderPipelineState(state.pipelineState)
            
            //effectiveRect是每个粒子的位置和大小，他的范围是[1,1]
            var rect = SIMD4<Float>(Float(0.32662722), Float(0.45892575), Float(0.16714127), Float(0.041469194))
            encoder.setVertexBytes(&rect, length: 4 * 4, index: 0)
            
            var size = SIMD2<Float>(Float(131), Float(25))
            encoder.setVertexBytes(&size, length: 4 * 2, index: 1)
            
            var particleResolution = SIMD2<UInt32>(UInt32(particleColumnCount), UInt32(particleRowCount))
            encoder.setVertexBytes(&particleResolution, length: 4 * 2, index: 2)
            
            encoder.setVertexBuffer(particleBuffer.buffer, offset: 0, index: 3)
            
            encoder.setFragmentTexture(item.texture, index: 0)
            
            encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
            encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6, instanceCount: particleCount)
        }
    }

}
