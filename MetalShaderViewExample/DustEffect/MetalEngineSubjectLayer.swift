//
//  MetalEngineSubjectLayer.swift
//  MetalShaderViewExample
//
//  Created by kylewu on 2024/3/24.
//

import UIKit

open class MetalEngineSubjectLayer: CALayer {
    fileprivate var internalId: Int = -1
//    fileprivate var surfaceAllocation: MetalEngine.SurfaceAllocation?
    var hasSurface: Bool = false
    
    #if DEBUG
    fileprivate var surfaceChangeFrameCount: Int = 0
    #endif
    
    public var cloneLayers: [CALayer] = []
    
    override open var contents: Any? {
        didSet {
        }
    }
    
    override open var contentsRect: CGRect {
        didSet {
        }
    }
    
    public override init() {
        super.init()
        
//        self.setNeedsDisplay()
    }
    
    deinit {
//        MetalEngine.shared.impl.removeLayerSurfaceAllocation(layer: self)
    }
    
    override public init(layer: Any) {
        super.init(layer: layer)
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
//    override public func setNeedsDisplay() {
//        if let subject = self as? MetalEngineSubject {
//            subject.setNeedsUpdate()
//        }
//    }
}
