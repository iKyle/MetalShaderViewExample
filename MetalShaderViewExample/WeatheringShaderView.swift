//
//  WeatheringShaderView.swift
//  MetalShaderViewExample
//
//  Created by kylewu on 2024/3/21.
//

import MetalKit

public struct BufferSpec: Equatable {
    public var length: Int
    
    public init(length: Int) {
        self.length = length
    }
}

public final class SharedBuffer {
    public let buffer: MTLBuffer
    
    init?(device: MTLDevice, spec: BufferSpec) {
        guard let buffer = device.makeBuffer(length: spec.length, options: [.storageModeShared]) else {
            return nil
        }
        self.buffer = buffer
    }
}

/// 汽泡Item
class BubbleItem {
    let frame: CGRect
    let texture: MTLTexture
    
    var phase: Float = 0.1
    var particleBufferIsInitialized: Bool = false
    var particleBuffer: SharedBuffer?
    
    init?(frame: CGRect, image: UIImage, device: MTLDevice) {
        self.frame = frame
        
        guard let cgImage = image.cgImage else { return nil }
        guard let texture = try? MTKTextureLoader(device: device).newTexture(cgImage: cgImage, options: [.SRGB: false as NSNumber]) else { return nil }
        self.texture = texture
    }
}

class WeatheringShaderView: MTKView {
    //指令队列
    private let commandQueue: MTLCommandQueue
    //渲染管线
    private let pipelineState: MTLRenderPipelineState
    private let computePipelineStateInitializeParticle: MTLComputePipelineState
    private let computePipelineStateUpdateParticle: MTLComputePipelineState
    private var lastTimeStep: Double = 0.0
    private var lastUpdateTimestamp: Double?
    private var bubbleItem: BubbleItem?
    private let animationDurationFactor = 1.0
    private var effectiveRect: CGRect = CGRect(x: 0, y: 0, width: 100, height: 50)

    init?(vertexShaderName: String,
          fragmentShaderName: String) {
        guard let device = MTLCreateSystemDefaultDevice(),  //创建一个对设备GPU的引用
              let commandQueue = device.makeCommandQueue(), //创建一个指令队列
              let library = device.makeDefaultLibrary() else {  //通过makeDefaultLibrary加载Metal库
                fatalError("Failed to set up shader view")
                return nil
        }
        
        guard let plState = try? WeatheringShaderView.createPipelineState(
                                    device: device,
                                    library: library,
                                    vertexShaderName: "dustEffectVertex",
                                    fragmentShaderName: "dustEffectFragment") else {
            return nil
        }
        
        guard let functionDustEffectInitializeParticle = library.makeFunction(name: "dustEffectInitializeParticle") else {
            return nil
        }
        
        guard let computePipelineStateInitializeParticle = try? device.makeComputePipelineState(function: functionDustEffectInitializeParticle) else {
            return nil
        }
        
        guard let functionDustEffectUpdateParticle = library.makeFunction(name: "dustEffectUpdateParticle") else {
            return nil
        }
        
        guard let computePipelineStateUpdateParticle = try? device.makeComputePipelineState(function: functionDustEffectUpdateParticle) else {
            return nil
        }
        
        self.commandQueue = commandQueue
        self.pipelineState = plState
        self.computePipelineStateInitializeParticle = computePipelineStateInitializeParticle
        self.computePipelineStateUpdateParticle = computePipelineStateUpdateParticle
        
        let image = UIImage(named: "StockCake-Autumn")
        self.bubbleItem = BubbleItem(frame: CGRect(x: 0, y: 0, width: 100, height: 50), image: image ?? UIImage(), device: device)
        super.init(frame: .zero, device: device)
    }
    
    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func draw(_ rect: CGRect) {
        guard let device = self.device,
              let commandBuffer = self.commandQueue.makeCommandBuffer(), //创建指令缓冲区
              let bubbleItem = self.bubbleItem else {
            return
        }
        
        let containerSize = self.bounds.size
        var itemFrame = bubbleItem.frame
        itemFrame.origin.y = containerSize.height - itemFrame.maxY
        
        let particleColumnCount = Int(itemFrame.width)
        let particleRowCount = Int(itemFrame.height)
        let particleCount = particleColumnCount * particleRowCount
        
        if bubbleItem.particleBuffer == nil {
            if let particleBuffer = SharedBuffer(device: device, spec: BufferSpec(length: particleCount * 4 * (4 + 1))) {
                bubbleItem.particleBuffer = particleBuffer
            }
        }
        
        self.updateTime()
        self.compute(commandBuffer)
        self.renderToLayer(commandBuffer)
    }
    
    private func updateTime() {
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
            deltaTimeValue = 0.016//deltaTime
        } else {
            deltaTimeValue = localDeltaTime
        }
        
        self.lastTimeStep = deltaTimeValue
    }
    
    private func compute(_ commandBuffer: MTLCommandBuffer) {
        guard let computeEncoder = commandBuffer.makeComputeCommandEncoder() else { //创建计算指令
            return
        }
        
        guard let bubbleItem = self.bubbleItem,
            let particleBuffer = bubbleItem.particleBuffer else {
            return
        }
        
        let itemFrame = bubbleItem.frame
        let particleColumnCount = Int(itemFrame.width)
        let particleRowCount = Int(itemFrame.height)
        let threadgroupSize = MTLSize(width: 32, height: 1, depth: 1)
        let threadgroupCount = MTLSize(width: (particleRowCount * particleColumnCount + threadgroupSize.width - 1) / threadgroupSize.width, height: 1, depth: 1)
        
        computeEncoder.setBuffer(particleBuffer.buffer, offset: 0, index: 0)
        
        if !bubbleItem.particleBufferIsInitialized {
            bubbleItem.particleBufferIsInitialized = true
            computeEncoder.setComputePipelineState(self.computePipelineStateInitializeParticle)
            computeEncoder.dispatchThreadgroups(threadgroupCount, threadsPerThreadgroup: threadgroupSize)
        }
        
        if self.lastTimeStep != 0.0 {
            computeEncoder.setComputePipelineState(self.computePipelineStateUpdateParticle)
            var particleCount = SIMD2<UInt32>(UInt32(particleColumnCount), UInt32(particleRowCount))
            computeEncoder.setBytes(&particleCount, length: 4 * 2, index: 1)
            var phase = bubbleItem.phase
            computeEncoder.setBytes(&phase, length: 4, index: 2)
            var timeStep: Float = Float(self.lastTimeStep) / Float(self.animationDurationFactor)
            timeStep *= 2.0
            computeEncoder.setBytes(&timeStep, length: 4, index: 3)
            computeEncoder.dispatchThreadgroups(threadgroupCount, threadsPerThreadgroup: threadgroupSize)
        }
        
        computeEncoder.endEncoding()
    }
    
    private func renderToLayer(_ commandBuffer: MTLCommandBuffer) {
//        guard let drawable = currentDrawable,
//              let descriptor = currentRenderPassDescriptor,
//              // 创建一个渲染命令编码器
//              let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor) else {
//                return
//        }
        
        guard let drawable = currentDrawable else {
            return
        }
        
        let renderPass = MTLRenderPassDescriptor()
        renderPass.colorAttachments[0].texture = drawable.texture
        renderPass.colorAttachments[0].loadAction = .load
        renderPass.colorAttachments[0].storeAction = .store
        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPass) else {
            return
        }
        
        guard let bubbleItem = self.bubbleItem,
            let particleBuffer = bubbleItem.particleBuffer else {
            return
        }
        
        encoder.setRenderPipelineState(self.pipelineState)
        let subRect = CGRect(x: 0, y: 0, width: 1179, height: 1179)
        encoder.setScissorRect(MTLScissorRect(x: Int(subRect.minX), y: 1179 - Int(subRect.maxY), width: Int(subRect.width), height: Int(subRect.height)))
        
        var itemFrame = bubbleItem.frame
        let containerSize = self.bounds.size
        itemFrame.origin.y = containerSize.height - itemFrame.maxY
        
        let particleColumnCount = Int(itemFrame.width)
        let particleRowCount = Int(itemFrame.height)
        let particleCount = particleColumnCount * particleRowCount
        
        var effectiveRect = self.effectiveRect
        effectiveRect.origin.x += itemFrame.minX / containerSize.width * effectiveRect.width
        effectiveRect.origin.y += itemFrame.minY / containerSize.height * effectiveRect.height
        effectiveRect.size.width = itemFrame.width / containerSize.width * effectiveRect.width
        effectiveRect.size.height = itemFrame.height / containerSize.height * effectiveRect.height
        
        var rect = SIMD4<Float>(Float(effectiveRect.minX), Float(effectiveRect.minY), Float(effectiveRect.width), Float(effectiveRect.height))
        encoder.setVertexBytes(&rect, length: 4 * 4, index: 0)
        
        var size = SIMD2<Float>(Float(itemFrame.width), Float(itemFrame.height))
        encoder.setVertexBytes(&size, length: 4 * 2, index: 1)
        
        var particleResolution = SIMD2<UInt32>(UInt32(particleColumnCount), UInt32(particleRowCount))
        encoder.setVertexBytes(&particleResolution, length: 4 * 2, index: 2)
        
        encoder.setVertexBuffer(particleBuffer.buffer, offset: 0, index: 3)
        
        encoder.setFragmentTexture(bubbleItem.texture, index: 0)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6, instanceCount: particleCount)
        // 结束编码
        encoder.endEncoding()
        // 将drawable呈现到屏幕上
        commandBuffer.present(drawable)
        // 提交命令缓冲区
        commandBuffer.commit()
    }
}

extension WeatheringShaderView {
    static func createPipelineState(device: MTLDevice,
                                    library: MTLLibrary,
                                    vertexShaderName: String,
                                    fragmentShaderName: String) throws -> MTLRenderPipelineState {
        let pipelineStateDescriptor = MTLRenderPipelineDescriptor()
        pipelineStateDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        pipelineStateDescriptor.colorAttachments[0].isBlendingEnabled = true
        pipelineStateDescriptor.colorAttachments[0].rgbBlendOperation = .add
        pipelineStateDescriptor.colorAttachments[0].alphaBlendOperation = .add
        pipelineStateDescriptor.colorAttachments[0].sourceRGBBlendFactor = .one
        pipelineStateDescriptor.colorAttachments[0].sourceAlphaBlendFactor = .one
        pipelineStateDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        pipelineStateDescriptor.colorAttachments[0].destinationAlphaBlendFactor = .one
        
        let vertexFunction = library.makeFunction(name: vertexShaderName)
        let fragmentFunction = library.makeFunction(name: fragmentShaderName)
        pipelineStateDescriptor.vertexFunction = vertexFunction  //顶点着色器程序
        pipelineStateDescriptor.fragmentFunction = fragmentFunction  //片段着色器程序
        return try device.makeRenderPipelineState(descriptor: pipelineStateDescriptor)
    }
}
