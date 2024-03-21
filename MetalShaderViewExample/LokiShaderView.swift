//
//  LokiShaderView.swift
//  MetalShaderViewExample
//
//  Created by kylewu on 2024/3/21.
//

import MetalKit

class LokiShaderView : MTKView {
    //指令队列
    private let commandQueue: MTLCommandQueue
    private var psShadeImage: MTLComputePipelineState!
    private var iteration = 0
    
    init?(vertexShaderName: String,
          fragmentShaderName: String) {
        guard let device = MTLCreateSystemDefaultDevice(),  //创建一个对设备GPU的引用
              let commandQueue = device.makeCommandQueue(), //创建一个指令队列
              let library = device.makeDefaultLibrary() else {  //通过makeDefaultLibrary加载Metal库
                fatalError("Failed to set up shader view")
                return nil
        }
        
        let vertexFunction = library.makeFunction(name: "loki_shader")
        guard let psShadeImage = try? device.makeComputePipelineState(function: vertexFunction!) else {
            return nil
        }
        
        self.commandQueue = commandQueue
        self.psShadeImage = psShadeImage
        super.init(frame: .zero, device: device)
        
        // Tell the MTKView that we want to use other buffers to draw
        // (needed for displaying from our own texture)
        self.framebufferOnly = false
        
        // Indicate we would like to use the RGBAPisle format.
        self.colorPixelFormat = .bgra8Unorm
        
        //Some Other Stuff
        self.sampleCount = 1
        self.preferredFramesPerSecond = 60
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func draw(_ rect: CGRect) {
        let commandBuffer = self.commandQueue.makeCommandBuffer()
        commandBuffer?.label = "Iteration: \(self.iteration)"
        
        let commandEncoder = commandBuffer?.makeComputeCommandEncoder()
        
        // If the commandEncoder could not be made
        if commandEncoder == nil || commandBuffer == nil {
            return
        }
        
        // If drawable is not ready, don't draw
        guard let drawable = self.currentDrawable else { // If drawable
            print("Drawable not ready for iteration #\(self.iteration)")
            commandEncoder!.endEncoding()
            commandBuffer!.commit()
            return;
        }
        
        commandEncoder!.setBytes(&self.iteration,  length: MemoryLayout<Int>.size, index: 0)
        commandEncoder!.setTexture(self.currentDrawable?.texture , index: 0)
        self.dispatchPipelineState(using: commandEncoder!)
        
        self.iteration += 1

        commandEncoder!.endEncoding()
        commandBuffer!.present(drawable)
        commandBuffer!.commit()
    }
    
    fileprivate func dispatchPipelineState(using commandEncoder: MTLComputeCommandEncoder) {
        let w = self.psShadeImage.threadExecutionWidth
        let h = self.psShadeImage.maxTotalThreadsPerThreadgroup / w
        let width = Int(self.frame.width)
        let height = Int(self.frame.height)
        let threadsPerThreadgroup = MTLSizeMake(w, h, 1)
        
        let threadgroupsPerGrid =  MTLSize(width:  width,
                                           height: height,
                                           depth: 1)
        
        commandEncoder.setComputePipelineState(self.psShadeImage)
        commandEncoder.dispatchThreadgroups(threadgroupsPerGrid,
                                            threadsPerThreadgroup: threadsPerThreadgroup)
    }
}
