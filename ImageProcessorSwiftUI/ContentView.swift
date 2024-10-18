//
//  ContentView.swift
//  ImageProcessorSwiftUI
//
//  Created by Justin on 10/18/24.
//

import SwiftUI
import CoreImage
import CoreImage.CIFilterBuiltins
import GameplayKit
import PhotosUI

struct ContentView: View {
    @State private var image: UIImage? = nil
    @State private var grainIntensity: Double = 50
    @State private var scratchIntensity: Double = 50
    @State private var isShowingImagePicker = false
    
    var body: some View {
        VStack {
            // Display the selected or processed image
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 300, height: 300)
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 300, height: 300)
                    .overlay(Text("Select an Image").foregroundColor(.gray))
            }
            
            // Button to choose an image from the photo library
            Button(action: {
                isShowingImagePicker = true
            }) {
                Text("Choose Image")
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .padding()

            // Grain Intensity Slider
            HStack {
                Text("Grain: ")
                Slider(value: $grainIntensity, in: 0...100, step: 1, onEditingChanged: { _ in
                    updateImage()
                })
                Text("\(Int(grainIntensity))")
            }
            .padding()

            // Scratch Intensity Slider
            HStack {
                Text("Scratches: ")
                Slider(value: $scratchIntensity, in: 0...100, step: 1, onEditingChanged: { _ in
                    updateImage()
                })
                Text("\(Int(scratchIntensity))")
            }
            .padding()
        }
        .onAppear {
            updateImage()
        }
        .sheet(isPresented: $isShowingImagePicker) {
            ImagePicker(image: $image)
        }
    }
    
    // Update the image with the selected effects
    func updateImage() {
        if let inputImage = image {
            image = applyEffects(to: inputImage, grainIntensity: grainIntensity, scratchIntensity: scratchIntensity)
        }
    }

    // Generate Random Noise with GameplayKit
    func generateRandomNoise() -> CIImage? {
        let randomSource = GKARC4RandomSource()
        let randomNumbers = (0..<512*512).map { _ in CGFloat(randomSource.nextUniform()) }
        let width = 512
        let height = 512
        let bitmapData = randomNumbers.map { UInt8($0 * 255.0) }
        
        guard let dataProvider = CGDataProvider(data: Data(bitmapData) as CFData),
              let cgImage = CGImage(width: width,
                                    height: height,
                                    bitsPerComponent: 8,
                                    bitsPerPixel: 8,
                                    bytesPerRow: width,
                                    space: CGColorSpaceCreateDeviceGray(),
                                    bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
                                    provider: dataProvider,
                                    decode: nil,
                                    shouldInterpolate: false,
                                    intent: .defaultIntent) else { return nil }
        
        return CIImage(cgImage: cgImage)
    }

    // Resize Image for Performance Optimization
    func resizeImage(_ image: UIImage, targetSize: CGSize) -> UIImage? {
        let size = image.size
        let widthRatio  = targetSize.width  / size.width
        let heightRatio = targetSize.height / size.height
        let newSize = CGSize(width: size.width * min(widthRatio, heightRatio),
                             height: size.height * min(widthRatio, heightRatio))
        UIGraphicsBeginImageContextWithOptions(newSize, false, 0.0)
        image.draw(in: CGRect(origin: .zero, size: newSize))
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return newImage
    }

    // Apply Sepia, Grain, and Scratch Effects
    func applyEffects(to image: UIImage, grainIntensity: Double, scratchIntensity: Double) -> UIImage? {
        // Resize input image for faster processing
        let targetSize = CGSize(width: 512, height: 512) // lower resolution for processing
        guard let resizedImage = resizeImage(image, targetSize: targetSize),
              let ciImage = CIImage(image: resizedImage) else { return nil }
        
        // Sepia Tone Filter
        let sepiaFilter = CIFilter.sepiaTone()
        sepiaFilter.inputImage = ciImage
        sepiaFilter.intensity = 1.0
        guard let sepiaCIImage = sepiaFilter.outputImage else { return nil }
        
        // Generate Noise for Grain and Scratches
        guard let noiseImage = generateRandomNoise() else { return nil }
        
        // Apply Grain
        let whitenVector = CIVector(x: 0, y: 1, z: 0, w: 0)
        let fineGrain = CIVector(x: 0, y: scaleIntensity(grainIntensity) / 5000, z: 0, w: 0)
        let zeroVector = CIVector(x: 0, y: 0, z: 0, w: 0)
        
        let whiteningFilter = CIFilter.colorMatrix()
        whiteningFilter.inputImage = noiseImage
        whiteningFilter.rVector = whitenVector
        whiteningFilter.gVector = whitenVector
        whiteningFilter.bVector = whitenVector
        whiteningFilter.aVector = fineGrain
        whiteningFilter.biasVector = zeroVector
        guard let whiteSpecks = whiteningFilter.outputImage else { return nil }
        
        let speckCompositor = CIFilter.sourceOverCompositing()
        speckCompositor.inputImage = whiteSpecks
        speckCompositor.backgroundImage = sepiaCIImage
        guard let speckledImage = speckCompositor.outputImage else { return nil }
        
        // Apply Scratches
        let verticalScale = CGAffineTransform(scaleX: 1.5, y: 25)
        let transformedNoise = noiseImage.transformed(by: verticalScale)
        
        let darkenVector = CIVector(x: 4, y: 0, z: 0, w: 0)
        let darkenBias = CIVector(x: 0, y: 1, z: 1, w: 1)
        
        let darkeningFilter = CIFilter.colorMatrix()
        darkeningFilter.inputImage = transformedNoise
        darkeningFilter.rVector = darkenVector
        darkeningFilter.gVector = zeroVector
        darkeningFilter.bVector = zeroVector
        darkeningFilter.aVector = zeroVector
        darkeningFilter.biasVector = darkenBias
        guard let randomScratches = darkeningFilter.outputImage else { return nil }
        
        let grayscaleFilter = CIFilter.minimumComponent()
        grayscaleFilter.inputImage = randomScratches
        guard let darkScratches = grayscaleFilter.outputImage else { return nil }
        
        let oldFilmCompositor = CIFilter.multiplyCompositing()
        oldFilmCompositor.inputImage = darkScratches
        oldFilmCompositor.backgroundImage = speckledImage
        guard let oldFilmImage = oldFilmCompositor.outputImage else { return nil }
        
        // Crop the final image to original size
        let finalImage = oldFilmImage.cropped(to: ciImage.extent)
        
        // Convert CIImage to UIImage
        let context = CIContext(options: nil)
        if let cgImage = context.createCGImage(finalImage, from: finalImage.extent) {
            return UIImage(cgImage: cgImage)
        }
        
        return nil
    }
    
    // Non-linear intensity scaling
    func scaleIntensity(_ value: Double) -> Double {
        return pow(value / 100, 2.0) // Non-linear scaling (quadratic)
    }
}
