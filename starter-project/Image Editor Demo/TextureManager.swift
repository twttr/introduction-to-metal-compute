import MetalKit

final class TextureManager {
    enum Error: Swift.Error {
        case cgImageCreationFailed
        case textureCreationFailed
    }
    
    private let textureLoader: MTKTextureLoader
    
    init(device: MTLDevice) {
        self.textureLoader = .init(device: device)
    }
    
    func texture(from cgImage: CGImage, usage: MTLTextureUsage = [.shaderRead, .shaderWrite]) throws -> MTLTexture {
        let textureOptions: [MTKTextureLoader.Option: Any] = [
            .textureUsage: NSNumber(value: usage.rawValue),
            .generateMipmaps: NSNumber(value: false),
            .SRGB: NSNumber(value: false)
        ]
        
        return try self.textureLoader.newTexture(cgImage: cgImage, options: textureOptions)
    }
    
    func cgImage(from texture: MTLTexture) throws -> CGImage {
        let bytesPerRow = texture.width * 4
        let length = bytesPerRow * texture.height
        let rgbaBytes = UnsafeMutableRawPointer.allocate(byteCount: length, alignment: MemoryLayout<UInt8>.alignment)
        defer { rgbaBytes.deallocate() }
        
        let destinationRegion = MTLRegion(
            origin: .init(x: 0, y: 0, z: 0),
            size: .init(
                width: texture.width,
                height: texture.height,
                depth: texture.depth
            )
        )
        
        texture.getBytes(rgbaBytes, bytesPerRow: bytesPerRow, from: destinationRegion, mipmapLevel: 0)
        let colorShape = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageByteOrderInfo.order32Little.rawValue | CGImageAlphaInfo.noneSkipFirst.rawValue)
        
        guard let data = CFDataCreate(nil, rgbaBytes.assumingMemoryBound(to: UInt8.self), length) else { throw Error.cgImageCreationFailed }
        guard let dataProvider = CGDataProvider(data: data) else { throw Error.cgImageCreationFailed }
        guard let cgImage = CGImage(
            width: texture.width,
            height: texture.height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: bytesPerRow,
            space: colorShape,
            bitmapInfo: bitmapInfo,
            provider: dataProvider,
            decode: nil,
            shouldInterpolate: true,
            intent: .defaultIntent) else { throw Error.cgImageCreationFailed }
        
        return cgImage
    }
    
    func matchingTexture(to texture: MTLTexture) throws -> MTLTexture {
        let matchingDescriptor = MTLTextureDescriptor()
        matchingDescriptor.width = texture.width
        matchingDescriptor.height = texture.height
        matchingDescriptor.usage = texture.usage
        matchingDescriptor.pixelFormat = texture.pixelFormat
        matchingDescriptor.storageMode = texture.storageMode
        
        guard let matchingTexture = self.textureLoader.device.makeTexture(descriptor: matchingDescriptor) else { throw Error.textureCreationFailed }
        
        return matchingTexture
    }
}
