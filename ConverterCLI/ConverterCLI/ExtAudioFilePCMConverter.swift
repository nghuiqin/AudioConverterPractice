//
//  ExtAudioFilePCMConverter.swift
//  ConverterCLI
//
//  Created by Hui Qin Ng on 2019/7/18.
//  Copyright © 2019 Hui Qin Ng. All rights reserved.
//

import AVFoundation
import AudioToolbox

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

struct ExAudioFilePCMConverter {

    static func convertToPCMFormat(fileURL: URL, destinationURL: URL) {
        var audioFileRef: ExtAudioFileRef? = nil
        var destinationFileRef: ExtAudioFileRef? = nil

        ExtAudioFileOpenURL(fileURL as CFURL, &audioFileRef)
        print("ExtAudioFileOpenURL")

        guard let sourceFile = audioFileRef else {
            fatalError("source file doesn't exist")
        }

        var sourceFormat = AudioStreamBasicDescription()
        var size = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)

        ExtAudioFileGetProperty(sourceFile, kExtAudioFileProperty_FileDataFormat, &size, &sourceFormat)
        print("ExtAudioFileGetProperty read source data format")
        print("SourceFormat:", sourceFormat)

        var destinationFormat = SignedIntLinearPCMStreamDescription
        size = UInt32(MemoryLayout.stride(ofValue: destinationFormat))
        ExtAudioFileSetProperty(sourceFile, kExtAudioFileProperty_ClientDataFormat, size, &destinationFormat)
        print("ExtAudioFileSetProperty set ClientDataFormat to sourceFile")

        ExtAudioFileCreateWithURL(destinationURL as CFURL, kAudioFileCAFType, &destinationFormat, nil, AudioFileFlags.eraseFile.rawValue, &destinationFileRef)
        print("Create destination file with URL")

        guard let destinationFile = destinationFileRef else {
            fatalError("Can't create destination file")
        }

        let bufferSize = 4096
        var bufferList = AudioBufferList()
        bufferList.mNumberBuffers = 1
        bufferList.mBuffers.mNumberChannels = 2
        bufferList.mBuffers.mData = malloc(bufferSize)
        bufferList.mBuffers.mDataByteSize = UInt32(bufferSize)

        while true {
            var numberOfFrames = UInt32(bufferSize) / destinationFormat.mBytesPerFrame

            ExtAudioFileRead(sourceFile, &numberOfFrames, &bufferList)

            if numberOfFrames == 0 {
                print("end of file")
                break
            }

            print("ExtAudioFileRead read sourceFile into buffer")
            print("Number of frame:", numberOfFrames)

            ExtAudioFileWrite(destinationFile, numberOfFrames, &bufferList)
            print("ExtAudioFileWrite write file into destinationFile")
        }

        free(bufferList.mBuffers.mData)
        if destinationFileRef != nil { ExtAudioFileDispose(destinationFileRef!) }
        if audioFileRef != nil { ExtAudioFileDispose(audioFileRef!) }
    }
}
