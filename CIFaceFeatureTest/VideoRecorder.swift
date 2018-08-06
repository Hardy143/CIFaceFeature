//
//  VideoRecorder.swift
//  CIFaceFeatureTest
//
//  Created by Vicki Larkin on 06/08/2018.
//  Copyright © 2018 Vicki Hardy. All rights reserved.
//

import Foundation
import UIKit
import AVFoundation

class VideoRecorder: NSObject {
    
    static let sharedVideo = VideoRecorder()
    
    // AVAssetWriter for video
    var isRecording = false
    var videoWriter: AVAssetWriter!
    var videoWriterInput: AVAssetWriterInput!
    var sessionAtSourceTime: CMTime?
    var outputFileLocation: URL?
    var videoWriterInputPixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor!
    var sDeviceRgbColorSpace = CGColorSpaceCreateDeviceRGB()
    var bitmapInfo = CGBitmapInfo.byteOrder32Little.union(CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipFirst.rawValue))
    
    var faceFrameCounter = 0
    var rightEyeCounter = 0
    var leftEyeCounter = 0
    var phase = 0
    
    
    // Mark: Set up AssetWriter
    func setupWriter() {
        
        do {
            outputFileLocation = videoFileLocation()
            videoWriter = try AVAssetWriter(outputURL: outputFileLocation!, fileType: AVFileType.mp4)
            
            // add video input
            videoWriterInput = AVAssetWriterInput(mediaType: AVMediaType.video, outputSettings: [
                AVVideoCodecKey : AVVideoCodecType.h264,
                AVVideoWidthKey : 480,
                AVVideoHeightKey : 853,
                AVVideoCompressionPropertiesKey : [
                    AVVideoAverageBitRateKey : 500000,
                ],
                ])
            
            videoWriterInput.expectsMediaDataInRealTime = true
            
            if videoWriter.canAdd(videoWriterInput) {
                videoWriter.add(videoWriterInput)
                print("video input added")
            } else {
                print("no video input added")
            }
            
            videoWriterInputPixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: videoWriterInput, sourcePixelBufferAttributes: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,kCVPixelFormatOpenGLESCompatibility as String: true,])
            
            
            videoWriter.startWriting()
            
        } catch let error {
            debugPrint(error.localizedDescription)
        }
    }
    
    //video file location method
    func videoFileLocation() -> URL {
        let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0] as NSString
        let videoOutputUrl = URL(fileURLWithPath: documentsPath.appendingPathComponent("videoFile")).appendingPathExtension("mp4")
        do {
            if FileManager.default.fileExists(atPath: videoOutputUrl.path) {
                try FileManager.default.removeItem(at: videoOutputUrl)
                print("file removed")
            }
        } catch {
            print(error)
        }
        
        return videoOutputUrl
    }
    
    // MARK: Function to check if the AssetWriter can write or not
    func canWrite() -> Bool {
        return isRecording && videoWriter != nil && videoWriter?.status == .writing
    }
    
    // MARK: Start recording
    func start() {
        guard !isRecording else { return }
        isRecording = true
        sessionAtSourceTime = nil
        setupWriter()
        print(isRecording)
        print(videoWriter)
        
        if videoWriter.status == .writing {
            print("status writing")
        } else if videoWriter.status == .failed {
            print("status failed")
        } else if videoWriter.status == .cancelled {
            print("status cancelled")
        } else if videoWriter.status == .unknown {
            print("status unknown")
        } else {
            print("status completed")
        }
    }
    
    // MARK: Stop recording
    func stop() {
        guard isRecording else { return }
        isRecording = false
        videoWriterInput.markAsFinished()
        
        videoWriter.finishWriting { [weak self] in
            self?.sessionAtSourceTime = nil
            print("video writer done")
        }
        
        SessionHandler.sharedSession.cameraSession.stopRunning()
    }
    
    //MARK: Cancel recording
    func cancel() {
        
        videoWriter.cancelWriting()
        print("cancelled")
        isRecording = false
        phase = 0
        faceFrameCounter = 0
        rightEyeCounter = 0
        leftEyeCounter = 0
        
        let name = Notification.Name(rawValue: cancelRecording)
        NotificationCenter.default.post(name: name, object: nil)
        
    }
    
}
