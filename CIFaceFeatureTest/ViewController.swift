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

let phase0 = "vicki.hardy.phase0"
let phase1 = "vicki.hardy.phase1"
let phase2 = "vicki.hardy.phase2"
let cancelRecording = "vicki.hardy.cancel"

class ViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
    
    let sessionHandler = SessionHandler.sharedSession
    let videoRecorder = VideoRecorder.sharedVideo
    
    @IBOutlet weak var previewView: UIView!
    @IBOutlet weak var recordButton: UIButton!
    @IBOutlet weak var instructionPhrase: UILabel!
    @IBOutlet weak var jsonSentence: UITextView!
    
    // JSON sentence variables
    var phrase = ""
    var phraseCounter = 0
    
    let phrase0 = Notification.Name(rawValue: phase0)
    let phrase1 = Notification.Name(rawValue: phase1)
    let noPhrase = Notification.Name(rawValue: phase2)
    let cancelAlert = Notification.Name(rawValue: cancelRecording)
    
    deinit {
         NotificationCenter.default.removeObserver(self)
    }

    // AVAudio
    let audioRecorder = AudioRecorder()

    override func viewDidLoad() {
        super.viewDidLoad()
        
        recordButton.isHidden = true 
        instructionPhrase.isHidden = true
        jsonSentence.isHidden = true
        sessionHandler.setupCamera()
        audioRecorder.setUpAudioSession()
        createObservers()
        
        let layer = sessionHandler.layer
        layer.frame = previewView.bounds
        previewView.layer.addSublayer(layer)
        view.layoutIfNeeded()
        
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        sessionHandler.cameraSession.startRunning()
        videoRecorder.phase = 0
        
        jsonSentence.isHidden = true
        if let x = UserDefaults.standard.object(forKey: "phraseCounter") as? Int {
            phraseCounter = x
            print("Phrase count: \(phraseCounter)")
        }
    }
    
    @IBAction func recordButtonPressed(_ sender: Any) {
        if !videoRecorder.isRecording {
            videoRecorder.start()
            audioRecorder.recordAudio()
            recordButton.setTitle("Recording", for: .normal)
            
            jsonSentence.isHidden = false
            let array = getFromJSON()
            for a in array {
                phrase.append("\(a)\n")
            }
            
            jsonSentence.text = phrase
            
        } else {
            videoRecorder.stop()
            audioRecorder.stopRecordingAudio()
            recordButton.setTitle("Record", for: .normal)
            performSegue(withIdentifier: "previewVideo", sender: nil)
        }
    }
    
    // MARK: Parse JSON file
    func getFromJSON() -> [String] {
        
        phrase = ""
        var array: [String] = []
        
        do {
            let jsonURL = Bundle.main.url(forResource: "script", withExtension: "json")
            let jsonDecoder = JSONDecoder()
            let jsonData = try Data(contentsOf: jsonURL!)
            let jsonSentence = try jsonDecoder.decode([[String]].self, from: jsonData)
            
            for (index, sentence) in jsonSentence.enumerated() {
                if index == phraseCounter {
                    for s in sentence {
                        array.append(s)
                    }
                }
            }
        } catch {
            print(error)
        }
        
        phraseCounter += 1
        print(phraseCounter)
        
        if phraseCounter == 209 {
            phraseCounter = 0
        }
        
        UserDefaults.standard.set(phraseCounter, forKey: "phraseCounter")
        
        return array
    }
    
    // MARK: Observer Functions
    func createObservers() {
        // Visability
        NotificationCenter.default.addObserver(self, selector: #selector(ViewController.updateInstructionPhrase(notification:)), name: phrase0, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(ViewController.updateInstructionPhrase(notification:)), name: phrase1, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(ViewController.showRecordButton(notification:)), name: noPhrase, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(ViewController.showAlert(notification:)), name: cancelAlert, object: nil)
    }
    
    @objc func updateInstructionPhrase(notification: NSNotification) {
        let isPhrase0 = notification.name == phrase0
        let phrase = isPhrase0 ? "Close your right eye" : "Close your left eye"
        instructionPhrase.isHidden = false
        instructionPhrase.text = phrase
        print(videoRecorder.phase)
        recordButton.isHidden = true
    }
    
    @objc func showRecordButton(notification: NSNotification) {
        instructionPhrase.isHidden = true
        recordButton.isHidden = false
        print(videoRecorder.phase)
    }
    
    @objc func showAlert(notification: NSNotification) {
        instructionPhrase.isHidden = true
        recordButton.isHidden = true
        
        let alert = UIAlertController(title: "Error", message: "Please ensure your face is infront of the camera", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Ok", style: .default, handler: nil))
        present(alert, animated: true, completion: nil) 
    }
    
    // MARK: show faces on screen
//    func drawFaceMasksFor(features: [CIFaceFeature], bufferFrame: CGRect) {
//
//        CATransaction.begin()
//        CATransaction.setValue(kCFBooleanTrue, forKey: kCATransactionDisableActions)
//
//        //Hide all current masks
//        view.layer.sublayers?.filter({ $0.name == "MaskFace" }).forEach { $0.isHidden = true }
//
//        //Do nothing if no face is dected
//        guard !features.isEmpty else {
//            CATransaction.commit()
//            return
//        }
//
//        //The problem is we detect the faces on video image size
//        //but when we show on the screen which might smaller or bigger than your video size
//        //so we need to re-calculate the faces bounds to fit to your screen
//
//        let xScale = view.frame.width / bufferFrame.width
//        let yScale = view.frame.height / bufferFrame.height
//        let transform = CGAffineTransform(rotationAngle: .pi).translatedBy(x: -bufferFrame.width,
//                                                                           y: -bufferFrame.height)
//
//        for feature in features {
//            var faceRect = feature.bounds.applying(transform)
//            faceRect = CGRect(x: faceRect.minX * xScale,
//                              y: faceRect.minY * yScale,
//                              width: faceRect.width * xScale,
//                              height: faceRect.height * yScale)
//
//            //Reuse the face's layer
////            var faceLayer = view.layer.sublayers?
////                .filter { $0.name == "MaskFace" && $0.isHidden == true }
////                .first
////            if faceLayer == nil {
////                // prepare layer
////                faceLayer = CALayer()
////                faceLayer?.name = "MaskFace"
////                faceLayer?.backgroundColor = UIColor.clear.cgColor
////                faceLayer?.borderColor = UIColor.red.cgColor
////                faceLayer?.borderWidth = 3.0
////                faceLayer?.frame = faceRect
////                faceLayer?.masksToBounds = true
////                faceLayer?.contentsGravity = kCAGravityResizeAspectFill
////                view.layer.addSublayer(faceLayer!)
////
////            } else {
////                faceLayer?.frame = faceRect
////                faceLayer?.isHidden = false
////            }
//
//            if feature.leftEyeClosed,
//                feature.rightEyeClosed {
//                recordButton.isHidden = false
//            }
//        }
//
//        CATransaction.commit()
//    }
    
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
            preview?.fileLocation = videoRecorder.outputFileLocation
        }
    }

}
