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
    @IBOutlet weak var faceDetectedLabel: UILabel!

    // AVCaptureSession
    var cameraSession = AVCaptureSession()
    var videoDataOutput = AVCaptureVideoDataOutput()
    var audioDataOutput = AVCaptureAudioDataOutput()
    var previewLayer: AVCaptureVideoPreviewLayer?
    
    // Face Detector
    var faceDetector = CIDetector(ofType: CIDetectorTypeFace, context: nil, options: [CIDetectorAccuracy : CIDetectorAccuracyHigh,
                                                                                      CIDetectorTracking : true])
    var isFaceDetected = false
    var haveEyesBlinked = false
    
    // AVAssetWriter
    var isRecording = false
    var videoWriter: AVAssetWriter!
    var videoWriterInput: AVAssetWriterInput!
    var audioWriterInput: AVAssetWriterInput!
    var sessionAtSourceTime: CMTime?
    var outputFileLocation: URL?
    var videoWriterInputPixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor!
    var sDeviceRgbColorSpace = CGColorSpaceCreateDeviceRGB()
    var bitmapInfo = CGBitmapInfo.byteOrder32Little.union(CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipFirst.rawValue))
    

    override func viewDidLoad() {
        super.viewDidLoad()

        faceDetectedLabel.isHidden = true
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
        let audioDevice = AVCaptureDevice.default(for: AVMediaType.audio)
        
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
            videoWriter = try AVAssetWriter(outputURL: outputFileLocation!, fileType: AVFileType.mov)
            
            // add video input
            videoWriterInput = AVAssetWriterInput(mediaType: AVMediaType.video, outputSettings: [
                AVVideoCodecKey : AVVideoCodecType.h264,
                AVVideoWidthKey : 720,
                AVVideoHeightKey : 1280,
                AVVideoCompressionPropertiesKey : [
                    AVVideoAverageBitRateKey : 2300000,
                ],
                ])
            
            videoWriterInput.expectsMediaDataInRealTime = true
            
            if videoWriter.canAdd(videoWriterInput) {
                videoWriter.add(videoWriterInput)
                print("video input added")
            } else {
                print("no input added")
            }
            
            // add audio input
            audioWriterInput = AVAssetWriterInput(mediaType: AVMediaType.audio, outputSettings: [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVNumberOfChannelsKey: 1,
                AVSampleRateKey: 44100,
                AVEncoderBitRateKey: 64000,
                ])
            
            audioWriterInput.expectsMediaDataInRealTime = true
            
            if videoWriter.canAdd(audioWriterInput) {
                videoWriter.add(audioWriterInput)
                print("audio input added")
            }
            
            videoWriterInputPixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: videoWriterInput, sourcePixelBufferAttributes: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
//                                                                                                                                                          kCVPixelBufferWidthKey as String: Constant.Configuration.DefaultAssetSize.width,
//                                                                                                                                                          kCVPixelBufferHeightKey as String: Constant.Configuration.DefaultAssetSize.height,
                                                                                                                                                          kCVPixelFormatOpenGLESCompatibility as String: true,])
            
            
            videoWriter.startWriting()
            
        } catch let error {
            debugPrint(error.localizedDescription)
        }
    }
    
    //video file location method
    func videoFileLocation() -> URL {
        let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0] as NSString
        let videoOutputUrl = URL(fileURLWithPath: documentsPath.appendingPathComponent("videoFile")).appendingPathExtension("mov")
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
        print("marked as finished")
        videoWriter.finishWriting { [weak self] in
            self?.sessionAtSourceTime = nil
        }
        //print("finished writing \(self.outputFileLocation)")
        cameraSession.stopRunning()
        performSegue(withIdentifier: "previewVideo", sender: nil)
    }
    
    // MARK: AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioOutputSampleBufferDelegate
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {

        let writable = canWrite()
        if writable {
           // print("Writable")
        }
        
        if writable,
            sessionAtSourceTime == nil {
            // Start Writing
            sessionAtSourceTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
            videoWriter.startSession(atSourceTime: sessionAtSourceTime!)
            print("session started")
        }
        

        // processing on the images, not audio
        if output == videoDataOutput {
            connection.videoOrientation = .portrait
            if connection.isVideoMirroringSupported {
                connection.isVideoMirrored = true
            }
            
            // convert current frame to CIImage
            let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)
            let attachments = CMCopyDictionaryOfAttachments(kCFAllocatorDefault, pixelBuffer!, CMAttachmentMode(kCMAttachmentMode_ShouldPropagate)) as? [String: Any]
            let ciImage = CIImage(cvImageBuffer: pixelBuffer!, options: attachments)

            // Detects faces based on your ciimage
            let features = faceDetector?.features(in: ciImage, options: [CIDetectorSmile : true,
                                                                         CIDetectorEyeBlink : true,
                                                                         ]).compactMap({ $0 as? CIFaceFeature })

            // Retreive frame of your buffer
//            let desc = CMSampleBufferGetFormatDescription(sampleBuffer)
//            let bufferFrame = CMVideoFormatDescriptionGetCleanAperture(desc!, false)
            
            DispatchQueue.main.async {
                self.faceDetection(features: features!)
            }
            

            // Draw face masks
//            DispatchQueue.main.async { [weak self] in
//                UIView.animate(withDuration: 0.2) {
//                self?.drawFaceMasksFor(features: features!, bufferFrame: bufferFrame)
//                }
//            }
        }
        
        if writable,
            output == videoDataOutput,
            (videoWriterInput.isReadyForMoreMediaData) {
            // write video buffer
            videoWriterInput.append(sampleBuffer)
            //print("video buffering")
        } else if writable,
            output == audioDataOutput,
            (audioWriterInput.isReadyForMoreMediaData) {
            // write audio buffer
            audioWriterInput?.append(sampleBuffer)
            //print("audio buffering")
        }
  
    }
    
    //MARK: face detector method
    func faceDetection(features: [CIFaceFeature]) {
        
        //Do nothing if no face is dected
        guard !features.isEmpty else {
            faceDetectedLabel.isHidden = false
            return
        }
        
        for feature in features {
            if feature.leftEyeClosed,
                feature.rightEyeClosed {
                haveEyesBlinked = true
                recordButton.isHidden = false
                faceDetectedLabel.isHidden = true
            }
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
            faceDetectedLabel.isHidden = false
            CATransaction.commit()
            return
        }
        
        faceDetectedLabel.isHidden = true
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
                haveEyesBlinked = true
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
