import Alloy
internal class Adjustments {
    internal let deviceSupportsNonuniformThreadgroups: Bool
    internal let pipelineState: MTLComputePipelineState
    internal init(library: MTLLibrary) throws {
        let constantValues = MTLFunctionConstantValues()
        let feature: Feature = .nonUniformThreadgroups
        self.deviceSupportsNonuniformThreadgroups = library.device.supports(feature: feature)
        constantValues.set(self.deviceSupportsNonuniformThreadgroups, at: 0)
        self.pipelineState = try library.computePipelineState(function: "adjustments", constants: constantValues)
    }
    internal func callAsFunction(source: MTLTexture, destination: MTLTexture, temperature: Float32, tint: Float32, in commandBuffer: MTLCommandBuffer) {
        self.encode(source: source, destination: destination, temperature: temperature, tint: tint, in: commandBuffer)
    }
    internal func callAsFunction(source: MTLTexture, destination: MTLTexture, temperature: Float32, tint: Float32, using encoder: MTLComputeCommandEncoder) {
        self.encode(source: source, destination: destination, temperature: temperature, tint: tint, using: encoder)
    }
    internal func encode(source: MTLTexture, destination: MTLTexture, temperature: Float32, tint: Float32, in commandBuffer: MTLCommandBuffer) {
        commandBuffer.compute { encoder in
            encoder.label = "Adjustments"
            self.encode(source: source, destination: destination, temperature: temperature, tint: tint, using: encoder)
        }
    }
    internal func encode(source: MTLTexture, destination: MTLTexture, temperature: Float32, tint: Float32, using encoder: MTLComputeCommandEncoder) {
        let _threadgroupSize = self.pipelineState.max2dThreadgroupSize
        encoder.setTexture(source, index: 0)
        encoder.setTexture(destination, index: 1)
        encoder.setValue(temperature, at: 0)
        encoder.setValue(tint, at: 1)
        if self.deviceSupportsNonuniformThreadgroups { encoder.dispatch2d(state: self.pipelineState, exactly: destination.size, threadgroupSize: _threadgroupSize) } else { encoder.dispatch2d(state: self.pipelineState, covering: destination.size, threadgroupSize: _threadgroupSize) }
    }
}
