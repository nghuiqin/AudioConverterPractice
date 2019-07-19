//
//  AudioFileServicePCMConverter.swift
//  ConverterCLI
//
//  Created by Hui Qin Ng on 2019/7/19.
//  Copyright © 2019 Hui Qin Ng. All rights reserved.
//

import AudioToolbox
import CommonCrypto

typealias AudioConverterInputDataProc = (
    _ converter: AudioConverterRef,
    _ inNumberDataPackets: UnsafeMutablePointer<UInt32>,
    _ ioData: UnsafeMutablePointer<AudioBufferList>,
    _ outDataPacketDescription: UnsafeMutablePointer<UnsafeMutablePointer<AudioStreamPacketDescription>?>?,
    _ inUserData: UnsafeMutableRawPointer?
    ) -> OSStatus

private let SignedIntLinearPCMStreamDescription: AudioStreamBasicDescription = {
    var destinationFormat = AudioStreamBasicDescription()
    destinationFormat.mSampleRate = 44100
    destinationFormat.mFormatID = kAudioFormatLinearPCM
    destinationFormat.mFormatFlags = kLinearPCMFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsPacked
    destinationFormat.mFramesPerPacket = 1
    destinationFormat.mBytesPerPacket = 4
    destinationFormat.mBytesPerFrame = 4
    destinationFormat.mChannelsPerFrame = 2
    destinationFormat.mBitsPerChannel = 16
    destinationFormat.mReserved = 0
    return destinationFormat
}()

private let converterInputDataProc: AudioConverterInputDataProc = { inConvertor, ioNumberDataPackets, ioData, outDataPacketDescription, inUserData in

    return noErr
}

struct AudioFileServicePCMConverter {
    static func convertToPCMFormat(fileURL: URL, fileFormat: AudioFileTypeID, destinationURL: URL) {
        var audioFileID: AudioFileID? = nil
        var destinationFileID: AudioFileID? = nil
        var converter: AudioConverterRef? = nil

        defer {
            if converter != nil { AudioConverterDispose(converter!) }
        }

        var status = AudioFileOpenURL(fileURL as CFURL, .readPermission, fileFormat, &audioFileID)
        assert(status == noErr, "Failed to open fileURL")

        guard let sourceFile = audioFileID else {
            fatalError("No such file compatible to AudioFileID")
        }

        var sourceFormat = AudioStreamBasicDescription()
        var size = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)

        status = AudioFileGetProperty(sourceFile, kAudioFilePropertyDataFormat, &size, &sourceFormat)
        assert(status == noErr, "AudioFileGetProperty get sourcefile AudioStreamBasicDescription failed")

        var destinationFormat = SignedIntLinearPCMStreamDescription
        size = UInt32(MemoryLayout.stride(ofValue: destinationFormat))

        status = AudioFileCreateWithURL(destinationURL as CFURL, kAudioFileCAFType, &destinationFormat, AudioFileFlags.eraseFile, &destinationFileID)
        assert(status == noErr, "AudioFileCreateWithURL failed to create file")

        AudioConverterNew(&sourceFormat, &destinationFormat, &converter)
        guard let audioConverter = converter else {
            fatalError("Failed to new a converter")
        }

        let bufferSize = 4096 * 4
        var outputSize = UInt32(bufferSize)
        var bufferList = AudioBufferList()
        bufferList.mBuffers.mNumberChannels = destinationFormat.mChannelsPerFrame
        bufferList.mBuffers.mData = malloc(bufferSize)
        bufferList.mBuffers.mDataByteSize = outputSize
        let numberOfFrames = UInt32(bufferSize) / sourceFormat.mBytesPerPacket
//        TODO: Send a buffer pointer into AudioConverterFillComplexBuffer function
//        UnsafeMutableBufferPointer<Int>(start: &bufferList, &)

        while true {
//            AudioConverterFillComplexBuffer(audioConverter, converterInputDataProc, /* TODO */, &outputSize, &bufferList, &destinationFormat)
            if numberOfFrames == 0 {
                print("EOF")
                break
            }
        }

        free(bufferList.mBuffers.mData)
    }

}
