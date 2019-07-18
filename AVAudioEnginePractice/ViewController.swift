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

    private var fileURL: URL = {
        guard let fileURL = Bundle.main.url(forResource: "bensound-summer", withExtension: "mp3") else {
            fatalError("Given URL is not available")
        }
        return fileURL
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        convertWithAVAudioFile()
        convertWithExtAudioFileService()
    }
    
    /// AVFoundation
    /// Refer to https://stackoverflow.com/a/39215201
    private func convertWithAVAudioFile() {
        do {
            let audioFile = try AVAudioFile(forReading: fileURL)
            let pcmFormat = AVAudioFormat(commonFormat: .pcmFormatInt32, sampleRate: audioFile.fileFormat.sampleRate, channels: audioFile.fileFormat.channelCount, interleaved: false)!
            let buffer = AVAudioPCMBuffer(pcmFormat: pcmFormat, frameCapacity: AVAudioFrameCount(audioFile.length))!
            try audioFile.read(into: buffer)
            
            // Audio Buffer list in memory
            let mAudioBufferList = Array(UnsafeBufferPointer(start: buffer.audioBufferList, count: Int(buffer.audioBufferList.pointee.mNumberBuffers)))
            let mBuffers = mAudioBufferList[0].mBuffers
            let array = Array(UnsafeMutableRawBufferPointer(start: mBuffers.mData, count: Int(mBuffers.mDataByteSize)))
            print("AVAudioFile convert result:", array.prefix(10))
        } catch {
            print("Failed to load audioFile")
        }
    }
    
    /*  AudioToolbox
     *  Extended Audio File Services
     *  References:
     *  Core Audio Book: https://cz-it.gitbooks.io/play-and-record-with-coreaudio/content/audiotoolbox/file/extaudiofile.html
     *  Github ExtendedAudioFileConvertTest-Swift sample code: https://github.com/ooper-shlab/ExtendedAudioFileConvertTest-Swift
     */
    private func convertWithExtAudioFileService() {
        // ExtAudioFile is higher level of Audio File Service API
        var audioFileRef: ExtAudioFileRef? = nil
        var converter: AudioConverterRef? = nil
        ExtAudioFileOpenURL(fileURL as CFURL, &audioFileRef)
        print("ExtAudioFileOpenURL")

        guard let sourceFile = audioFileRef else {
            fatalError("source file does not exist")
        }

        var sourceFormat = AudioStreamBasicDescription()
        var size = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
        
        ExtAudioFileGetProperty(sourceFile, kExtAudioFileProperty_FileDataFormat, &size, &sourceFormat)
        print("ExtAudioFileGetProperty get sourceFile format")

        var destinationFormat = SignedIntLinearPCMStreamDescription
        size = UInt32(MemoryLayout.stride(ofValue: destinationFormat))
        
        printFormatDescription(sourceFormat)
        printFormatDescription(destinationFormat)

        ExtAudioFileSetProperty(sourceFile, kExtAudioFileProperty_ClientDataFormat, size, &destinationFormat)
        print("ExtAudioFileSetProperty set destinationFormat to clientDataFormat")

        // Get AudioConverter (In reference, he handles interruption in converter)
        size = UInt32(MemoryLayout<AudioConverterRef>.size)
        ExtAudioFileGetProperty(sourceFile, kExtAudioFileProperty_AudioConverter, &size, &converter)
        print("ExtAudioFileGetProperty get AudioConverter")

        // Create AudioBufferList
        let bufferSize = 4096 * 4
        var bufferList = AudioBufferList()
        bufferList.mNumberBuffers = 1
        bufferList.mBuffers.mNumberChannels = destinationFormat.mChannelsPerFrame
        bufferList.mBuffers.mDataByteSize = UInt32(bufferSize)
        bufferList.mBuffers.mData = malloc(bufferSize)
        print("AudioBufferList is initialzed")

        // Read...
        var numberOfFrames = UInt32(bufferSize) / destinationFormat.mBytesPerFrame
        ExtAudioFileRead(sourceFile, &numberOfFrames, &bufferList)
        print("ExtAudioFileRead read source into buffer")

        print("Number of frames:", numberOfFrames)

        let array = Array(UnsafeMutableRawBufferPointer(start: bufferList.mBuffers.mData, count: Int(bufferList.mBuffers.mDataByteSize)))
        print("ExtAudioFileService result:", array.prefix(10))
    }

    /// Wait comfirmation with zonble
    private func convertWithAudioFileServices() {
        
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
