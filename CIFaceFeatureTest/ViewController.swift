//
//  ViewController.swift
//  CIFaceFeatureTest
//
//  Created by Vicki Larkin on 17/07/2018.
//  Copyright © 2018 Vicki Hardy. All rights reserved.
//

import UIKit
import AVFoundation
import ImageIO

class ViewController: UIViewController, AVCaptureAudioDataOutputSampleBufferDelegate, AVCaptureVideoDataOutputSampleBufferDelegate {
    
    
    @IBOutlet weak var previewView: UIView!
    @IBOutlet weak var recordButton: UIButton!

    // AVCaptureSession
    var cameraSession = AVCaptureSession()
    var videoDataOutput = AVCaptureVideoDataOutput()
    var audioDataOutput = AVCaptureAudioDataOutput()
    var previewLayer: AVCaptureVideoPreviewLayer?
    var globalSampleBuffer: CMSampleBuffer!
    
    // Face Detector
    var faceDetector = CIDetector(ofType: CIDetectorTypeFace, context: nil, options: [CIDetectorAccuracy : CIDetectorAccuracyHigh,
                                                                                      CIDetectorTracking : true])
    var isFaceDetected = false
    var faceFrameCounter = 0
    
    // AVAssetWriter for video
    var isRecording = false
    var videoWriter: AVAssetWriter!
    var videoWriterInput: AVAssetWriterInput!
    //var audioWriterInput: AVAssetWriterInput!
    var sessionAtSourceTime: CMTime?
    var outputFileLocation: URL?
    var videoWriterInputPixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor!
    var sDeviceRgbColorSpace = CGColorSpaceCreateDeviceRGB()
    var bitmapInfo = CGBitmapInfo.byteOrder32Little.union(CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipFirst.rawValue))
    
    //AVAssetWriter for audio
    var audioWriter: AVAssetWriter!
    var audioWriterInput: AVAssetWriterInput!
    var audioOutputUrl: URL?
    var sessionAtSourceTime2: CMTime?

    override func viewDidLoad() {
        super.viewDidLoad()

        recordButton.isHidden = true
        setupCamera()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        cameraSession.startRunning()
    }
    
    @IBAction func recordButtonPressed(_ sender: Any) {
        if !isRecording {
            start()
            recordButton.setTitle("Recording", for: .normal)
        } else {
            stop()
            recordButton.setTitle("Record", for: .normal)
        }
    }
    
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
            
            // define audio output
            if cameraSession.canAddOutput(audioDataOutput) {
                audioDataOutput.setSampleBufferDelegate(self, queue: queue)
                cameraSession.addOutput(audioDataOutput)
                print("audio output added")
            }
            
            cameraSession.commitConfiguration()
            
            // present the preview of video
            previewLayer = AVCaptureVideoPreviewLayer(session: cameraSession)
            previewLayer?.frame = CGRect(x: 0, y: 0, width: self.view.frame.size.width, height: self.view.frame.size.height)
            previewLayer?.videoGravity = AVLayerVideoGravity.resizeAspectFill
            previewView.layer.addSublayer(previewLayer!)
            
            // start running the session
            cameraSession.startRunning()
            
        } catch {
            print(error.localizedDescription)
        }
    }
    
    // Mark: Set up AssetWriter
    func setupWriter() {
        
        do {
            outputFileLocation = videoFileLocation()
            audioOutputUrl = audioFileLocation()
            videoWriter = try AVAssetWriter(outputURL: outputFileLocation!, fileType: AVFileType.mp4)
            audioWriter = try AVAssetWriter(outputURL: audioOutputUrl!, fileType: AVFileType.m4a)
            
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
            
            // add audio input
            audioWriterInput = AVAssetWriterInput(mediaType: AVMediaType.audio, outputSettings: [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVSampleRateKey: 44100,
                AVNumberOfChannelsKey: 2,
                AVEncoderBitRateKey: 192000] as [String: Any])

            audioWriterInput.expectsMediaDataInRealTime = true

            if audioWriter.canAdd(audioWriterInput) {
                audioWriter.add(audioWriterInput)
                print("audio input added")
            } else {
                print("no audio input added")
            }
            
            videoWriterInputPixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: videoWriterInput, sourcePixelBufferAttributes: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,kCVPixelFormatOpenGLESCompatibility as String: true,])
            
            
            videoWriter.startWriting()
            audioWriter.startWriting()
            
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
    
    func audioFileLocation() -> URL {
        let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0] as NSString
        let audioOutputUrl = URL(fileURLWithPath: documentsPath.appendingPathComponent("audioFile")).appendingPathExtension("m4a")
        do {
            if FileManager.default.fileExists(atPath: audioOutputUrl.path) {
                try FileManager.default.removeItem(at: audioOutputUrl)
                print("file removed")
            }
        } catch {
            print(error)
        }
        
        return audioOutputUrl
    }
    
    // MARK: Function to check if the AssetWriter can write or not
    func canWrite() -> Bool {
        return isRecording && videoWriter != nil && videoWriter?.status == .writing
    }
    func videoCanWrite() -> Bool {
        return isRecording && videoWriter != nil && videoWriter!.status == .writing
    }
    func audioCanWriter() -> Bool {
        return isRecording && audioWriter != nil && audioWriter!.status == .writing
    }
    
    // MARK: Start recording
    func start() {
        guard !isRecording else { return }
        isRecording = true
        sessionAtSourceTime = nil
        sessionAtSourceTime2 = nil
        print("here")
        setupWriter()
        print(isRecording)
        print(videoWriter)
        print(audioWriter)
        
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
        
        if audioWriter.status == .writing {
            print("status writing")
        } else if audioWriter.status == .failed {
            print("status failed")
        } else if audioWriter.status == .cancelled {
            print("status cancelled")
        } else if audioWriter.status == .unknown {
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
        audioWriterInput.markAsFinished()
        
        videoWriter.finishWriting { [weak self] in
            self?.sessionAtSourceTime = nil
            print("video writer done")
        }
        
        audioWriter.finishWriting { [weak self] in
            self?.sessionAtSourceTime2 = nil
            print("audio writer done")
        }
        
        //print("finished writing \(self.outputFileLocation)")
        cameraSession.stopRunning()
        performSegue(withIdentifier: "previewVideo", sender: nil)
    }
    
    //MARK: Cancel recording
    func cancel() {
        
        videoWriter.cancelWriting()
        print("cancelled")
        recordButton.setTitle("Record", for: .normal)
        isRecording = false
        recordButton.isHidden = true
        
        let alert = UIAlertController(title: "Error", message: "Please ensure your face is infront of the camera", preferredStyle: .alert)
        let alertAction = UIAlertAction(title: "Ok", style: .default, handler: nil)
        alert.addAction(alertAction)
        present(alert, animated: true, completion: nil) 
        
    }
    
    // MARK: Face Detection
    func faceDetection(sampleBuffer: CMSampleBuffer) {
        
        // convert current frame to CIImage
        let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)
        let attachments = CMCopyDictionaryOfAttachments(kCFAllocatorDefault, pixelBuffer!, CMAttachmentMode(kCMAttachmentMode_ShouldPropagate)) as? [String: Any]
        let ciImage = CIImage(cvImageBuffer: pixelBuffer!, options: attachments)
        
        // Retreive frame of your buffer
        //            let desc = CMSampleBufferGetFormatDescription(sampleBuffer)
        //            let bufferFrame = CMVideoFormatDescriptionGetCleanAperture(desc!, false)
        
        // Detects faces based on your ciimage
        let features = faceDetector?.features(in: ciImage, options: [CIDetectorSmile : true,
                                                                     CIDetectorEyeBlink : true,
                                                                     ]).compactMap({ $0 as? CIFaceFeature })
        
        //If no face is detected start counter
        guard !features!.isEmpty else {
            
            // cancel the recording if no face is detected
            if isRecording {
                faceFrameCounter += 1
                print(faceFrameCounter)
                if faceFrameCounter == 50 {
                    cancel()
                    faceFrameCounter = 0
                }
            }
            
            return
        }
        
        for feature in features! {
            if feature.leftEyeClosed,
                feature.rightEyeClosed {
                DispatchQueue.main.sync {
                    recordButton.isHidden = false
                }
            }
        }
    }
    
    
    // MARK: AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioOutputSampleBufferDelegate
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        
        //let writable = canWrite()
        let videoWriable = videoCanWrite()
        let audioWritable = audioCanWriter()
        
        if CMSampleBufferDataIsReady(sampleBuffer) == false {
            print("not ready")
            return
        }
        
        if videoWriable {
            
            if sessionAtSourceTime == nil {
                // Start Writing
                sessionAtSourceTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
                videoWriter.startSession(atSourceTime: sessionAtSourceTime!)
                print("video session started")
            }
            
            if output == videoDataOutput {
                if videoWriterInput.isReadyForMoreMediaData {
                    // write video buffer
                    videoWriterInput.append(sampleBuffer)
                    //print("video buffering")
                }
            }
        }
        
        if audioWritable {
            
            if sessionAtSourceTime2 == nil {
                sessionAtSourceTime2 = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
                audioWriter.startSession(atSourceTime: sessionAtSourceTime2!)
            }

            if output == audioDataOutput {
                if audioWriterInput.isReadyForMoreMediaData {
                    // write audio buffer
                    audioWriterInput.append(sampleBuffer)
                    //print("audio buffering")
                } else {
                    print("not ready")
                }
            }
        }

        // processing on the images, not audio
        if output == videoDataOutput {
            connection.videoOrientation = .portrait
            
            if connection.isVideoMirroringSupported {
                connection.isVideoMirrored = true
            }
            
            self.faceDetection(sampleBuffer: sampleBuffer)

            // Draw face masks
//            DispatchQueue.main.async { [weak self] in
//                UIView.animate(withDuration: 0.2) {
//                self?.drawFaceMasksFor(features: features!, bufferFrame: bufferFrame)
//                }
//            }
            
        }

    }
    

    
    // MARK: show faces on screen
    func drawFaceMasksFor(features: [CIFaceFeature], bufferFrame: CGRect) {
        
        CATransaction.begin()
        CATransaction.setValue(kCFBooleanTrue, forKey: kCATransactionDisableActions)
        
        //Hide all current masks
        view.layer.sublayers?.filter({ $0.name == "MaskFace" }).forEach { $0.isHidden = true }
        
        //Do nothing if no face is dected
        guard !features.isEmpty else {
            CATransaction.commit()
            return
        }
        
        //The problem is we detect the faces on video image size
        //but when we show on the screen which might smaller or bigger than your video size
        //so we need to re-calculate the faces bounds to fit to your screen
        
        let xScale = view.frame.width / bufferFrame.width
        let yScale = view.frame.height / bufferFrame.height
        let transform = CGAffineTransform(rotationAngle: .pi).translatedBy(x: -bufferFrame.width,
                                                                           y: -bufferFrame.height)
        
        for feature in features {
            var faceRect = feature.bounds.applying(transform)
            faceRect = CGRect(x: faceRect.minX * xScale,
                              y: faceRect.minY * yScale,
                              width: faceRect.width * xScale,
                              height: faceRect.height * yScale)

            //Reuse the face's layer
//            var faceLayer = view.layer.sublayers?
//                .filter { $0.name == "MaskFace" && $0.isHidden == true }
//                .first
//            if faceLayer == nil {
//                // prepare layer
//                faceLayer = CALayer()
//                faceLayer?.name = "MaskFace"
//                faceLayer?.backgroundColor = UIColor.clear.cgColor
//                faceLayer?.borderColor = UIColor.red.cgColor
//                faceLayer?.borderWidth = 3.0
//                faceLayer?.frame = faceRect
//                faceLayer?.masksToBounds = true
//                faceLayer?.contentsGravity = kCAGravityResizeAspectFill
//                view.layer.addSublayer(faceLayer!)
//
//            } else {
//                faceLayer?.frame = faceRect
//                faceLayer?.isHidden = false
//            }
            
            if feature.leftEyeClosed,
                feature.rightEyeClosed {
                recordButton.isHidden = false
            }
        }
        
        CATransaction.commit()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.destination is VideoPreviewViewController {
            let preview = segue.destination as? VideoPreviewViewController
            preview?.fileLocation = self.outputFileLocation
        }
    }

}
