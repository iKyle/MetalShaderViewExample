//
//  MetalEngine.swift
//  MetalShaderViewExample
//
//  Created by kylewu on 2024/3/24.
//

import Foundation
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
    final class Impl {
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
    let impl: Impl
    
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

final class Surface {
    let id: Int
    let width: Int
    let height: Int
    
    let ioSurface: IOSurface
    let texture: MTLTexture
    
    init?(id: Int, device: MTLDevice, width: Int, height: Int) {
        self.id = id
        self.width = width
        self.height = height
        
        let ioSurfaceProperties: [String: Any] = [
            kIOSurfaceWidth as String: width,
            kIOSurfaceHeight as String: height,
            kIOSurfaceBytesPerElement as String: 4,
            kIOSurfacePixelFormat as String: kCVPixelFormatType_32BGRA
        ]
        guard let ioSurface = IOSurfaceCreate(ioSurfaceProperties as CFDictionary) else {
            return nil
        }
        self.ioSurface = ioSurface
        
        let textureDescriptor = MTLTextureDescriptor()
        textureDescriptor.pixelFormat = .bgra8Unorm
        textureDescriptor.width = Int(width)
        textureDescriptor.height = Int(height)
        textureDescriptor.storageMode = .shared
        textureDescriptor.usage = .renderTarget
        
        guard let texture = device.makeTexture(descriptor: textureDescriptor, iosurface: ioSurface, plane: 0) else {
            return nil
        }
        self.texture = texture
    }
}
