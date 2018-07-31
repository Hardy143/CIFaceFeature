//
//  AudioRecorder.swift
//  CIFaceFeatureTest
//
//  Created by Vicki Larkin on 31/07/2018.
//  Copyright © 2018 Vicki Hardy. All rights reserved.
//

import Foundation
import UIKit
import AVFoundation

class AudioRecorder: NSObject, AVAudioRecorderDelegate {

    var recordingSession: AVAudioSession!
    var audioRecorder: AVAudioRecorder!
    var numberOfRecords = 0
    
    func setUpAudioSession() {
        recordingSession = AVAudioSession.sharedInstance()
        AVAudioSession.sharedInstance().recordPermission()
    }
    
    func recordAudio() {
        // Check if we have an active recorder
        if audioRecorder == nil {
            numberOfRecords += 1
            let fileName = getDirectory().appendingPathComponent("\(numberOfRecords).flac")
            
            let settings = [AVFormatIDKey: Int(kAudioFormatFLAC),
                            AVSampleRateKey: 16000,
                            AVNumberOfChannelsKey: 1,
                            AVLinearPCMBitDepthKey: 16,
                            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
                            AVLinearPCMIsBigEndianKey: false,
                            AVLinearPCMIsFloatKey: false] as [String : Any]
            
            // Start Audio Recording
            do {
                audioRecorder = try AVAudioRecorder(url: fileName, settings: settings)
                try recordingSession.setCategory(AVAudioSessionCategoryRecord)
                audioRecorder.delegate = self
                audioRecorder.record()
                print("audio recording")
            } catch {
                print("Audio recording hasn't worked")
            }
        }
    }
    
    func stopRecordingAudio() {
        
        if audioRecorder != nil {
            audioRecorder.stop()
            do {
                try recordingSession.setCategory(AVAudioSessionCategoryPlayback)
            } catch {
                print(error) 
            }
            print("audio stopped recording")
            audioRecorder = nil
        }
    }
    
    // directory for audio recording
    func getDirectory() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let documentDirectory = paths[0]
        return documentDirectory
    }
    


    
}



