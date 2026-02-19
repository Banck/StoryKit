//
//  BGDetector.swift
//  StoryKit
//
//  Created by Orlov Maxim on 08.07.2025.
//

import SwiftUI
import AVFoundation
import CoreImage
import CoreImage.CIFilterBuiltins

private enum BackgroundDetectorError: Error {
	
	case failedLoadImageFromVideo
}

struct BackgroundDetector: Sendable {
	
	private let defaultValue: CGFloat = 0

	private let ciContext = CIContext()
	private let avgFilter = CIFilter.areaAverage()
	
	func detect(
		from pageContent: PageView.ContentType,
		viewSize: CGSize,
		croppedFrame: CGRect
	) async -> CGFloat {
		await Task.yield()
		let ciImage: CIImage
		switch pageContent {
		case .image(let image):
			guard
				let ci = CIImage(image: image)
			else { return defaultValue }
			ciImage = ci
		case .video(let url):
			do {
				ciImage = try await getImage(fromVideo: url)
			} catch {
				return defaultValue
			}
		}
		let roi = roiRectInImageCoords(
			viewSize: viewSize,
			imageSize: ciImage.extent.size,
			buttonFrame: croppedFrame
		)
		
		return computeBrightness(from: ciImage, roi: roi)
	}

	private func computeBrightness(from ciImage: CIImage, roi: CGRect) -> CGFloat {
        var safeRoi = roi.integral
        if safeRoi.width < 2 { safeRoi.size.width = 2 }
        if safeRoi.height < 2 { safeRoi.size.height = 2 }

        let cropped = ciImage.cropped(to: safeRoi)

		avgFilter.inputImage = cropped
		avgFilter.extent = cropped.extent

		guard
			let output = avgFilter.outputImage,
			let bitmap = ciContext.renderToBitmap(
				output,
				rowBytes: 4,
				bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
				format: .RGBA8,
				colorSpace: CGColorSpaceCreateDeviceRGB()
			)
		else {
			return defaultValue
		}

		let r = CGFloat(bitmap[0]) / 255
		let g = CGFloat(bitmap[1]) / 255
		let b = CGFloat(bitmap[2]) / 255
		return 0.299 * r + 0.587 * g + 0.114 * b
	}
	
	private func getImage(fromVideo url: URL) async throws -> CIImage {
		let asset = AVAsset(url: url)
		let imgGen = AVAssetImageGenerator(asset: asset)
		imgGen.appliesPreferredTrackTransform = true
		let time = CMTime(seconds: 0.001, preferredTimescale: 600)
		return try await withCheckedThrowingContinuation { cont in
			imgGen
				.generateCGImagesAsynchronously(
					forTimes: [NSValue(time: time)]
				) { _, cgImg, _, _, _ in
				guard let cg = cgImg else {
					cont.resume(
						throwing: BackgroundDetectorError.failedLoadImageFromVideo
					)
					return
				}
				cont.resume(returning: CIImage(cgImage: cg))
			}
		}
	}
	
	private func roiRectInImageCoords(viewSize: CGSize, imageSize: CGSize, buttonFrame: CGRect) -> CGRect {
		let scale = max(
			viewSize.width  / imageSize.width,
			viewSize.height / imageSize.height
		)

		let scaledImageSize = CGSize(
			width:  imageSize.width  * scale,
			height: imageSize.height * scale
		)

		let xOverflow = (scaledImageSize.width  - viewSize.width)  / 2
		let yOverflow = (scaledImageSize.height - viewSize.height) / 2

		let imageX = (buttonFrame.minX + xOverflow) / scale
		let imageY = (buttonFrame.minY + yOverflow) / scale
		let imageW = buttonFrame.width  / scale
		let imageH = buttonFrame.height / scale

		let invertedY = imageSize.height - (imageY + imageH)
		
		return CGRect(
			x: imageX,
			y: invertedY,
			width: imageW,
			height: imageH
		)
	}
}

private extension CIContext {
	
	func renderToBitmap(_ image: CIImage,
						rowBytes: Int,
						bounds: CGRect,
						format: CIFormat,
						colorSpace: CGColorSpace) -> [UInt8]? {
		var bitmap = [UInt8](repeating: 0, count: Int(rowBytes * Int(bounds.height)))
		self.render(
			image,
			toBitmap: &bitmap,
			rowBytes: rowBytes,
			bounds: bounds,
			format: format,
			colorSpace: colorSpace
		)
		return bitmap
	}
}
