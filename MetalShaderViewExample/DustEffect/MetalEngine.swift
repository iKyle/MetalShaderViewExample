//
//  MetalEngine.swift
//  MetalShaderViewExample
//
//  Created by kylewu on 2024/3/24.
//

import Foundation
import MetalKit

public protocol ComputeState: AnyObject {
    init?(device: MTLDevice)
}

public struct RenderSize: Equatable {
    public var width: Int
    public var height: Int
    
    public init(width: Int, height: Int) {
        self.width = width
        self.height = height
    }
}

public struct RenderLayerSpec: Equatable {
    public var size: RenderSize
    public var edgeInset: Int
    
    public init(size: RenderSize, edgeInset: Int = 0) {
        self.size = size
        self.edgeInset = edgeInset
    }
}

public struct RenderLayerPlacement: Equatable {
    public var effectiveRect: CGRect
    
    public init(effectiveRect: CGRect) {
        self.effectiveRect = effectiveRect
    }
}

public final class MetalEngine {
    fileprivate final class Impl {
        let device: MTLDevice
        let library: MTLLibrary
        let commandQueue: MTLCommandQueue
        
        init?(device: MTLDevice) {
            
            self.device = device
            
            guard let commandQueue = device.makeCommandQueue() else {
                return nil
            }
            self.commandQueue = commandQueue
            
            let library: MTLLibrary?
            library = try? device.makeDefaultLibrary()
            
            guard let lib = library else {
                return nil
            }
            self.library = lib
        }
    }
    
    public static let shared = MetalEngine()
    fileprivate let impl: Impl
    
    public var device: MTLDevice {
        return self.impl.device
    }
    
    public func sharedBuffer(spec: BufferSpec) -> SharedBuffer? {
        return SharedBuffer(device: self.device, spec: spec)
    }
    
    private init() {
        self.impl = Impl(device: MTLCreateSystemDefaultDevice()!)!
    }
}

