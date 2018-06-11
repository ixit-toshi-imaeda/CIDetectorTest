//
//  ViewController.swift
//  CIDetectorTest
//
//  Created by 今枝 稔晴 on 2018/06/11.
//  Copyright © 2018年 iXIT Corporation. All rights reserved.
//

import UIKit
import AVFoundation

class ViewController: UIViewController {
    
    @IBOutlet weak var frameView: UIView!
    @IBOutlet weak var imageView: UIImageView!
    let captureSession = AVCaptureSession()
    let videoDevice = ViewController.getVideoDevice(position: .back)
    let audioDevice = AVCaptureDevice.default(for: AVMediaType.audio)
    
    let videoOutput = AVCaptureVideoDataOutput()
    
    let rectView = UIView()

    override func viewDidLoad() {
        super.viewDidLoad()
        
        rectView.layer.borderColor = UIColor.blue.cgColor
        rectView.layer.borderWidth = 3
        rectView.frame = CGRect.zero
        
        // 各デバイスの登録（audioは実際は不要）
        do {
            guard let videoDevice = videoDevice else {
                let ac = UIAlertController(title: "カメラが使用できません", message: "お使いの端末ではカメラが起動できません", preferredStyle: .alert)
                ac.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                present(ac, animated: true, completion: nil)
                return
            }
            let videoInput = try AVCaptureDeviceInput(device: videoDevice)
            captureSession.addInput(videoInput)
        } catch let error {
            print(error)
        }
        
        // ピクセルフォーマットを 32bit BGR + A とする
        videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)]
        
        // フレーム毎に呼び出すデリゲート登録
        videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue.main)
        
        // キューがブロックされているときに新しいフレームが来たら削除
        videoOutput.alwaysDiscardsLateVideoFrames = true
        
        captureSession.addOutput(videoOutput)
        
        let videoLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        videoLayer.frame = imageView.bounds
        videoLayer.videoGravity = AVLayerVideoGravity.resizeAspectFill
        imageView.layer.addSublayer(videoLayer)
        
        // カメラ向き
        for connection in videoOutput.connections {
            if connection.isVideoOrientationSupported {
                // 縦向きで固定
                connection.videoOrientation = .portrait
            }
        }
        
        captureSession.startRunning()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
}

// MARK: - fileprivate

fileprivate extension ViewController {
    
    static func getVideoDevice(position: AVCaptureDevice.Position) -> AVCaptureDevice? {
        return AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
    }
    
    func imageFromSampleBuffer(sampleBuffer: CMSampleBuffer) -> UIImage?  {
        
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return nil
        }
        // バッファを取得したらそのバッファをロックする
        // ロックしないとカメラから送られてくるデータで次々と書き換えられてしまうことになる
        CVPixelBufferLockBaseAddress(imageBuffer, CVPixelBufferLockFlags(rawValue: 0))
        let baseAddress = CVPixelBufferGetBaseAddressOfPlane(imageBuffer, 0)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer)
        let width = CVPixelBufferGetWidth(imageBuffer)
        let height = CVPixelBufferGetHeight(imageBuffer)
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = (CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue)
        let context = CGContext(data: baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: bytesPerRow, space: colorSpace, bitmapInfo: bitmapInfo)
        let imageRef = context!.makeImage()

        CVPixelBufferUnlockBaseAddress(imageBuffer, CVPixelBufferLockFlags(rawValue: 0))
        let resultImage = UIImage(cgImage: imageRef!)

        return resultImage
    }
    
    func rectFaces(faceFeatures: [CIFaceFeature], image: UIImage) {
        
        frameView.subviews.forEach { subview in
            subview.removeFromSuperview()
        }

        faceFeatures.forEach { feature in
            
            // -------------------------
            // 解析
            // -------------------------
            print("================================")
            print(feature.bounds) // yの位置が上下が反転している
            print(feature.hasLeftEyePosition)
            print(feature.leftEyePosition)
            print(feature.hasRightEyePosition)
            print(feature.rightEyePosition)
            print(feature.hasMouthPosition)
            print(feature.mouthPosition)
            print(feature.hasTrackingID)
            print(feature.trackingID)
            print(feature.hasTrackingFrameCount)
            print(feature.trackingFrameCount)
            print(feature.hasFaceAngle)
            print(feature.faceAngle)
            print(feature.hasSmile)
            print(feature.leftEyeClosed)
            print(feature.rightEyeClosed)
            print("================================")
            
            // 顔全体について
            let faceView = getFrameView(color: .blue)
            faceView.frame = getConvertedRect(feature: feature, type: .face, image: image)
            frameView.addSubview(faceView)
            
            // 左目
            if feature.hasLeftEyePosition {
                let faceView = getFrameView(color: .red)
                faceView.frame = getConvertedRect(feature: feature, type: .leftEye, image: image)
                frameView.addSubview(faceView)
            }
            
            // 右目
            if feature.hasRightEyePosition {
                let faceView = getFrameView(color: .red)
                faceView.frame = getConvertedRect(feature: feature, type: .rightEye, image: image)
                frameView.addSubview(faceView)
            }
            
            // 口
            if feature.hasMouthPosition {
                let faceView = getFrameView(color: .red)
                faceView.frame = getConvertedRect(feature: feature, type: .mouth, image: image)
                frameView.addSubview(faceView)
            }
        }
    }
    
    func getConvertedRect(feature: CIFaceFeature, type: facePartsType, image: UIImage) -> CGRect {
        
        var faceRect : CGRect = feature.bounds
        switch type {
        case .leftEye:
            faceRect.origin = feature.leftEyePosition
            faceRect.size = CGSize(width: feature.bounds.width * 1/6, height: feature.bounds.height * 1/6)
            faceRect.origin.x -= faceRect.size.width/2
            faceRect.origin.y -= faceRect.size.height/2
            break
        case .rightEye:
            faceRect.origin = feature.rightEyePosition
            faceRect.size = CGSize(width: feature.bounds.width * 1/6, height: feature.bounds.height * 1/6)
            faceRect.origin.x -= faceRect.size.width/2
            faceRect.origin.y -= faceRect.size.height/2
            break
        case .mouth:
            faceRect.origin = feature.mouthPosition
            faceRect.size = CGSize(width: feature.bounds.width * 1/3, height: feature.bounds.height * 1/6)
            faceRect.origin.x -= faceRect.size.width/2
            faceRect.origin.y -= faceRect.size.height
            break
        default:
            break
        }
        let widthPer = (self.imageView.bounds.width/image.size.width)
        let heightPer = (self.imageView.bounds.height/image.size.height)
        
        // 原点の位置が異なるため、修正する
        faceRect.origin.x = image.size.width - faceRect.origin.x - faceRect.size.width
        faceRect.origin.y = image.size.height - faceRect.origin.y - faceRect.size.height
        
        //倍率変換
        faceRect.origin.x = faceRect.origin.x * widthPer
        faceRect.origin.y = faceRect.origin.y * heightPer
        faceRect.size.width = faceRect.size.width * widthPer
        faceRect.size.height = faceRect.size.height * heightPer
        
        return faceRect
    }
    
    func getFrameView(color: UIColor) -> UIView {
        let frameView = UIView()
        frameView.layer.borderColor = color.cgColor
        frameView.layer.borderWidth = 3
        return frameView
    }
}

extension ViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    
    func captureOutput(_ output: AVCaptureOutput, didDrop sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        
        DispatchQueue.main.async {[unowned self] in

            //バッファーをUIImageに変換
            guard let image = self.imageFromSampleBuffer(sampleBuffer: sampleBuffer) else {
                return
            }
            let ciimage:CIImage! = CIImage(image: image)

            //CIDetectorAccuracyHighだと高精度（使った感じは遠距離による判定の精度）だが処理が遅くなる
            let detector : CIDetector = CIDetector(ofType: CIDetectorTypeFace, context: nil, options:[CIDetectorAccuracy: CIDetectorAccuracyHigh] )!
            guard let faces = detector.features(in: ciimage) as? [CIFaceFeature] else {
                return
            }
            self.rectFaces(faceFeatures: faces, image: image)
        }
    }
}

enum facePartsType {
    case face
    case leftEye
    case rightEye
    case mouth
}

