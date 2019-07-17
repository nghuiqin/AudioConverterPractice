//
//  ViewController.swift
//  AVAudioEnginePractice
//
//  Created by Hui Qin Ng on 2019/7/17.
//  Copyright © 2019 Hui Qin Ng. All rights reserved.
//

import UIKit
import AVFoundation
import AudioToolbox

private let SignedIntLinearPCMStreamDescription: AudioStreamBasicDescription = {
    var destinationFormat = AudioStreamBasicDescription()
    destinationFormat.mSampleRate = 44100
    destinationFormat.mFormatID = kAudioFormatLinearPCM
    destinationFormat.mFormatFlags = kLinearPCMFormatFlagIsSignedInteger
    destinationFormat.mFramesPerPacket = 1
    destinationFormat.mBytesPerPacket = 4
    destinationFormat.mBytesPerFrame = 4
    destinationFormat.mChannelsPerFrame = 2
    destinationFormat.mBitsPerChannel = 16
    destinationFormat.mReserved = 0
    return destinationFormat
}()

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        convertWithAVAudioFile()
    }
    
    
    /// AVFoundation
    /// Refer to https://stackoverflow.com/a/39215201
    private func convertWithAVAudioFile() {
        guard let fileURL = Bundle.main.url(forResource: "bensound-summer", withExtension: "mp3") else {
            fatalError("Given URL is not available")
        }
        
        do {
            let audioFile = try AVAudioFile(forReading: fileURL)
            let pcmFormat = AVAudioFormat(commonFormat: .pcmFormatInt32, sampleRate: audioFile.fileFormat.sampleRate, channels: audioFile.fileFormat.channelCount, interleaved: false)!
            let buffer = AVAudioPCMBuffer(pcmFormat: pcmFormat, frameCapacity: AVAudioFrameCount(audioFile.length))!
            try audioFile.read(into: buffer)
            
            // Audio Buffer list in memory
            let mAudioBufferList = Array(UnsafeBufferPointer(start: buffer.audioBufferList, count: Int(buffer.audioBufferList.pointee.mNumberBuffers)))
            let mBuffers = mAudioBufferList[0].mBuffers
            let mDataList = Array(UnsafeMutableRawBufferPointer(start: mBuffers.mData, count: Int(mBuffers.mDataByteSize)))
            
        } catch {
            print("Failed to load audioFile")
        }
    }
    
    /// AudioToolbox
    /// Extended Audio File Services
    /// Referred to https://github.com/ooper-shlab/ExtendedAudioFileConvertTest-Swift
    private func convertWithExtAudioFileService() {
        guard let fileURL = Bundle.main.url(forResource: "bensound-summer", withExtension: "mp3") else {
            fatalError("Given URL is not available")
        }
        
        // ExtAudioFile is higher level of Audio File API
        var audioFileRef: ExtAudioFileRef? = nil
        ExtAudioFileOpenURL(fileURL as CFURL, &audioFileRef)
        guard let sourceFile = audioFileRef else {
            fatalError("source file does not exist")
        }
        
        var sourceFormat = AudioStreamBasicDescription()
        var size = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
        
        ExtAudioFileGetProperty(sourceFile, kExtAudioFileProperty_FileDataFormat, &size, &sourceFormat)
        
        var destinationFormat = SignedIntLinearPCMStreamDescription
        
        printFormatDescription(sourceFormat)
        printFormatDescription(destinationFormat)
    }
}

extension ViewController {
    private func printFormatDescription(_ format: AudioStreamBasicDescription) {
        print("mSampleRate:", format.mSampleRate)
        print("mFormatID:", format.mFormatID)
        print("mFormatFlag:", format.mFormatFlags)
        print("mBytesPerPacket:", format.mBytesPerPacket)
        print("mFramesPerPacket:", format.mFramesPerPacket)
        print("mBytesPerFrame:", format.mBytesPerFrame)
        print("mChannelsPerFrame:", format.mChannelsPerFrame)
        print("mBitsPerChannel:", format.mBitsPerChannel)
        print("mReserved:", format.mReserved)
        print("------------------------------------------")
    }
}
