//
//  MetalEngine.swift
//  MetalShaderViewExample
//
//  Created by kylewu on 2024/3/24.
//

import Foundation
import MetalKit

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
}


public final class MetalEngineSubjectContext {
    fileprivate final class ComputeOperation {
        let commands: (MTLCommandBuffer) -> Void
        
        init(commands: @escaping (MTLCommandBuffer) -> Void) {
            self.commands = commands
        }
    }
    
    fileprivate final class RenderToLayerOperation {
        let spec: RenderLayerSpec
        let state: RenderToLayerState
        weak var layer: MetalEngineSubjectLayer?
        let commands: (MTLRenderCommandEncoder, RenderLayerPlacement) -> Void
        
        init(
            spec: RenderLayerSpec,
            state: RenderToLayerState,
            layer: MetalEngineSubjectLayer,
            commands: @escaping (MTLRenderCommandEncoder, RenderLayerPlacement) -> Void
        ) {
            self.spec = spec
            self.state = state
            self.layer = layer
            self.commands = commands
        }
    }
    
    private let device: MTLDevice
    private let impl: MetalEngine.Impl
    
    fileprivate var computeOperations: [ComputeOperation] = []
    fileprivate var computeOperation: ComputeOperation?
    fileprivate var renderToLayerOperationsGroupedByState: [ObjectIdentifier: [RenderToLayerOperation]] = [:]
    fileprivate var renderToLayerOperations: RenderToLayerOperation?
    
    fileprivate init(device: MTLDevice, impl: MetalEngine.Impl) {
        self.device = device
        self.impl = impl
    }
    
    public func renderToLayer<RenderToLayerStateType: RenderToLayerState, each Resolved>(
        spec: RenderLayerSpec,
        state: RenderToLayerStateType.Type,
        layer: MetalEngineSubjectLayer,
        inputs: repeat Placeholder<each Resolved>,
        commands: @escaping (MTLRenderCommandEncoder, RenderLayerPlacement, repeat each Resolved) -> Void
    ) {
//        let stateTypeId = ObjectIdentifier(state)
        let resolvedState: RenderToLayerStateType
        if let current = self.impl.renderState as? RenderToLayerStateType {
            resolvedState = current
        } else {
            guard let value = RenderToLayerStateType(device: self.device) else {
                assertionFailure("Could not initialize render state \(state)")
                return
            }
            resolvedState = value
//            self.impl.renderStates[stateTypeId] = resolvedState
            self.impl.renderState = resolvedState
        }
        
        let operation = RenderToLayerOperation(
            spec: spec,
            state: resolvedState,
            layer: layer,
            commands: { encoder, placement in
                let resolvedInputs: (repeat each Resolved)
                do {
                    resolvedInputs = (repeat try resolvePlaceholder(each inputs))
                } catch {
                    print("Could not resolve renderToLayer inputs")
                    return
                }
                commands(encoder, placement, repeat each resolvedInputs)
            }
        )
        self.renderToLayerOperations = operation
//        if self.renderToLayerOperationsGroupedByState[stateTypeId] == nil {
//            self.renderToLayerOperationsGroupedByState[stateTypeId] = [operation]
//        } else {
//            self.renderToLayerOperationsGroupedByState[stateTypeId]?.append(operation)
//        }
    }
    
    public func renderToLayer<RenderToLayerStateType: RenderToLayerState>(
        spec: RenderLayerSpec,
        state: RenderToLayerStateType.Type,
        layer: MetalEngineSubjectLayer,
        commands: @escaping (MTLRenderCommandEncoder, RenderLayerPlacement) -> Void
    ) {
        self.renderToLayer(spec: spec, state: state, layer: layer, inputs: noInputPlaceholder, commands: { encoder, placement, _ in
            commands(encoder, placement)
        })
    }
    
    public func compute<ComputeStateType: ComputeState, each Resolved, Output>(
        state: ComputeStateType.Type,
        inputs: repeat Placeholder<each Resolved>,
        commands: @escaping (MTLCommandBuffer, ComputeStateType, repeat each Resolved) -> Output
    ) -> Placeholder<Output> {
        let stateTypeId = ObjectIdentifier(state)
        let resolvedState: ComputeStateType
        if let current = self.impl.computeStates[stateTypeId] as? ComputeStateType {
            resolvedState = current
        } else {
            guard let value = ComputeStateType(device: self.device) else {
                assertionFailure("Could not initialize compute state \(state)")
                return Placeholder()
            }
            resolvedState = value
            self.impl.computeStates[stateTypeId] = resolvedState
        }
        
        let resultPlaceholder = Placeholder<Output>()
        self.computeOperation = ComputeOperation(commands: { commandBuffer in
            let resolvedInputs: (repeat each Resolved)
            do {
                resolvedInputs = (repeat try resolvePlaceholder(each inputs))
            } catch {
                print("Could not resolve renderToLayer inputs")
                return
            }
            resultPlaceholder.contents = commands(commandBuffer, resolvedState, repeat each resolvedInputs)
        })
        return resultPlaceholder
    }
    
    public func compute<ComputeStateType: ComputeState, Output>(
        state: ComputeStateType.Type,
        commands: @escaping (MTLCommandBuffer, ComputeStateType) -> Output
    ) -> Placeholder<Output> {
        return self.compute(state: state, inputs: noInputPlaceholder, commands: { commandBuffer, state, _ in
            return commands(commandBuffer, state)
        })
    }
}
