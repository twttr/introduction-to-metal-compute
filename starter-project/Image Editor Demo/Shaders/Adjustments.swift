import Metal

final class Adjustments {
    var temperature: Float = .zero
    var tint: Float = .zero
    
    private var deviceSupportsNonuniformThreadgroups: Bool
    private let pipelineState: MTLComputePipelineState
    
    init(library: MTLLibrary) throws {
        deviceSupportsNonuniformThreadgroups = library.device.supportsFeatureSet(.iOS_GPUFamily4_v1)
        let constantValues = MTLFunctionConstantValues()
        constantValues.setConstantValue(&self.deviceSupportsNonuniformThreadgroups, type: .bool, index: 0)
        let function = try library.makeFunction(name: "adjustments", constantValues: constantValues)
        self.pipelineState = try library.device.makeComputePipelineState(function: function)
    }
    
    func encode(source: MTLTexture, destination: MTLTexture, in commandBuffer: MTLCommandBuffer) {
        guard let commandEncoder = commandBuffer.makeComputeCommandEncoder() else { return }
        
        commandEncoder.setTexture(source, index: 0)
        commandEncoder.setTexture(destination, index: 1)
        
        commandEncoder.setBytes(&self.temperature, length: MemoryLayout<Float>.stride, index: 0)
        commandEncoder.setBytes(&self.tint, length: MemoryLayout<Float>.stride, index: 1)
        
        let gridSize = MTLSize(width: source.width, height: source.height, depth: 0)
        let threadGroupWidth = self.pipelineState.threadExecutionWidth
        let threadGroupHeight = self.pipelineState.maxTotalThreadsPerThreadgroup / threadGroupWidth
        let threadGroupSize = MTLSize(width: threadGroupWidth, height: threadGroupHeight, depth: 1)
        
        commandEncoder.setComputePipelineState(self.pipelineState)
        
        if self.deviceSupportsNonuniformThreadgroups {
            commandEncoder.dispatchThreads(gridSize, threadsPerThreadgroup: threadGroupSize)
        } else {
            let threadGroupCount = MTLSize(
                width: (gridSize.width + threadGroupSize.width - 1) / threadGroupSize.width,
                height: (gridSize.height + threadGroupSize.height - 1) / threadGroupSize.height,
                depth: 1
            )
            commandEncoder.dispatchThreadgroups(threadGroupCount, threadsPerThreadgroup: threadGroupSize)
        }
        commandEncoder.endEncoding()
    }
}
