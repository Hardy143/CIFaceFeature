//
//  VideoCamera.swift
//  CIFaceFeatureTest
//
//  Created by Vicki Larkin on 31/07/2018.
//  Copyright © 2018 Vicki Hardy. All rights reserved.
//

import Foundation
import UIKit
import AVFoundation
import ImageIO

class SessionHandler: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    
    static let sharedSession = SessionHandler()
    let videoRecorder = VideoRecorder.sharedVideo
    
    // AVCaptureSession
    var cameraSession = AVCaptureSession()
    var videoDataOutput = AVCaptureVideoDataOutput()
    //var previewLayer: AVCaptureVideoPreviewLayer?
    let layer = AVSampleBufferDisplayLayer()
    
    // Face Detector
    var faceDetector = CIDetector(ofType: CIDetectorTypeFace, context: nil, options: [CIDetectorAccuracy : CIDetectorAccuracyHigh,
                                                                                      CIDetectorTracking : true])
    var isFaceDetected = false
    
    
    // MARK: Set up the camera
    func setupCamera() {
        
        // size of video output
        cameraSession.sessionPreset = .high
        
        // set up camera
        let captureDevice: AVCaptureDevice!
        captureDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: AVMediaType.video, position: .front)
        
        // set up microphone
        let audioDevice = AVCaptureDevice.default(.builtInMicrophone, for: AVMediaType.audio, position: .unspecified)
        
        do {
            cameraSession.beginConfiguration()
            
            // add camera to session
            let deviceInput = try AVCaptureDeviceInput(device: captureDevice!)
            if cameraSession.canAddInput(deviceInput) {
                cameraSession.addInput(deviceInput)
            }
            
            // add microphone to session
            let audioInput = try AVCaptureDeviceInput(device: audioDevice!)
            if cameraSession.canAddInput(audioInput) {
                cameraSession.addInput(audioInput)
                print("audio input added")
            }
            
            // define output data
            let queue = DispatchQueue(label: "data-output-queue")
            
            // define video output
            videoDataOutput.videoSettings = [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            ]
            
            videoDataOutput.alwaysDiscardsLateVideoFrames = true
            
            if cameraSession.canAddOutput(videoDataOutput) {
                videoDataOutput.setSampleBufferDelegate(self, queue: queue)
                cameraSession.addOutput(videoDataOutput)
            }
            
            cameraSession.commitConfiguration()
            
            // present the preview of video
//            previewLayer = AVCaptureVideoPreviewLayer(session: cameraSession)
//            previewLayer?.frame = CGRect(x: 0, y: 0, width: self.view.frame.size.width, height: self.view.frame.size.height)
//            previewLayer?.videoGravity = AVLayerVideoGravity.resizeAspectFill
//            previewView.layer.addSublayer(previewLayer!)
            
            // start running the session
            cameraSession.startRunning()
            
        } catch {
            print(error.localizedDescription)
        }
    }
    
   
    
    // MARK: Face Detection
    func faceDetection(sampleBuffer: CMSampleBuffer) {
        
        // convert current frame to CIImage
        let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)
        let attachments = CMCopyDictionaryOfAttachments(kCFAllocatorDefault, pixelBuffer!, CMAttachmentMode(kCMAttachmentMode_ShouldPropagate)) as? [String: Any]
        let ciImage = CIImage(cvImageBuffer: pixelBuffer!, options: attachments)
        
        // Detects faces based on your ciimage
        let features = faceDetector?.features(in: ciImage, options: [CIDetectorEyeBlink : true,
                                                                     ]).compactMap({ $0 as? CIFaceFeature })
        
        //If no face is detected start counter
        guard !features!.isEmpty else {
            
            // cancel the recording if no face is detected
            if videoRecorder.isRecording {
                videoRecorder.faceFrameCounter += 1
                print(videoRecorder.faceFrameCounter)
                if videoRecorder.faceFrameCounter == 50 {
                    videoRecorder.cancel()
                    videoRecorder.faceFrameCounter = 0
                }
            }
            
            return
        }
        
        for feature in features! {
            if videoRecorder.phase == 0 {
                let name = Notification.Name(rawValue: phase0)
                NotificationCenter.default.post(name: name, object: nil)
                if feature.rightEyeClosed {
                    videoRecorder.rightEyeCounter += 1
                    //print(rightEyeCounter)
                    if videoRecorder.rightEyeCounter == 25 {
                        videoRecorder.phase = 1
                        let name = Notification.Name(rawValue: phase1)
                        NotificationCenter.default.post(name: name, object: nil)
                    }
                } else {
                    videoRecorder.rightEyeCounter = 0
                }
            } else if videoRecorder.phase == 1 {
                if feature.leftEyeClosed {
                    videoRecorder.leftEyeCounter += 1
                    print(videoRecorder.leftEyeCounter)
                    if videoRecorder.leftEyeCounter == 25 {
                        videoRecorder.phase = 2
                        let name = Notification.Name(rawValue: phase2)
                        NotificationCenter.default.post(name: name, object: nil)
                    }
                } else {
                    videoRecorder.leftEyeCounter = 0
                }
            }
        }
    }
    
    
    // MARK: AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioOutputSampleBufferDelegate
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        
        let writable = videoRecorder.canWrite()
        
        if CMSampleBufferDataIsReady(sampleBuffer) == false {
            print("not ready")
            return
        }
        
        if writable {
            
            if videoRecorder.sessionAtSourceTime == nil {
                // Start Writing
                videoRecorder.sessionAtSourceTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
                videoRecorder.videoWriter.startSession(atSourceTime: videoRecorder.sessionAtSourceTime!)
                print("video session started")
            }
            
            if output == videoDataOutput {
                if videoRecorder.videoWriterInput.isReadyForMoreMediaData {
                    // write video buffer
                    videoRecorder.videoWriterInput.append(sampleBuffer) 
                    //print("video buffering")
                }
            }
        }
        
        // processing on the images, not audio
        if output == videoDataOutput {
            connection.videoOrientation = .portrait
            
            if connection.isVideoMirroringSupported {
                connection.isVideoMirrored = true
            }
            
            DispatchQueue.main.sync {
                self.faceDetection(sampleBuffer: sampleBuffer)
            }
            layer.enqueue(sampleBuffer)
            
            // Draw face masks
            //            DispatchQueue.main.async { [weak self] in
            //                UIView.animate(withDuration: 0.2) {
            //                self?.drawFaceMasksFor(features: features!, bufferFrame: bufferFrame)
            //                }
            //            }
            
        }
        
    }
}
