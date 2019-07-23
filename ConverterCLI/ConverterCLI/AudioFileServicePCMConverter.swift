//
//  AudioFileServicePCMConverter.swift
//  ConverterCLI
//
//  Created by Hui Qin Ng on 2019/7/19.
//  Copyright © 2019 Hui Qin Ng. All rights reserved.
//

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

private let converterInputDataProc: AudioConverterComplexInputDataProc = { inConvertor, ioNumberDataPackets, ioData, outDataPacketDescription, inUserData in

    let userDataPtr = inUserData!.assumingMemoryBound(to: ConverterInputUserData.self)
    let userData = userDataPtr.pointee

    // Figure out how much to read
    let maxPackets = userData.sourceBufferSize / userData.sourceSizePerPacket

    if ioNumberDataPackets.pointee > maxPackets {
        ioNumberDataPackets.pointee = maxPackets
    }

    // read from the file
    var outNumBytes = maxPackets * userData.sourceSizePerPacket

    print("File Pointer:", userData.filePositionPointer)
    // My issue was using pointer to set pointer =.=
    var status = AudioFileReadPacketData(userData.sourceFileID, false, &outNumBytes, userData.packetDescriptionPointer, userData.filePositionPointer, ioNumberDataPackets, userData.bufferPointer)
    if status == eofErr { status = noErr }
    guard status == noErr else {
        print("AudioFileReadPacketData failed")
        return status
    }

    // Have to use userDataPtr rather than userData, if not filePositionPointer value will not be referenced.
    userDataPtr.pointee.filePositionPointer += Int64(ioNumberDataPackets.pointee)

    // Must write buffer into ioData pointer
    let ioDataPtr = UnsafeMutableAudioBufferListPointer(ioData)
    ioDataPtr[0].mData = UnsafeMutableRawPointer(userData.bufferPointer)
    ioDataPtr[0].mNumberChannels = 0
    ioDataPtr[0].mDataByteSize = outNumBytes

    // Must set outDataPacketDescription or !pkd error
    if let outDataPacketDescription = outDataPacketDescription {
        if userData.packetDescriptionPointer != nil {
            outDataPacketDescription.pointee = userData.packetDescriptionPointer
        } else {
            outDataPacketDescription.pointee = nil
        }
    }

    return noErr
}

private struct ConverterInputUserData {
    var sourceFileID: AudioFileID
    var sourceBufferSize: UInt32
    var sourceSizePerPacket: UInt32
    var filePositionPointer: Int64
    var bufferPointer: UnsafeMutablePointer<CChar>
    var packetDescriptionPointer: UnsafeMutablePointer<AudioStreamPacketDescription>?
}

struct AudioFileServicePCMConverter {
    static func convertToPCMFormat(fileURL: URL, fileFormat: AudioFileTypeID, destinationURL: URL) {
        var audioFileID: AudioFileID? = nil
        var destFileID: AudioFileID? = nil
        var converter: AudioConverterRef? = nil

        print("Get sourceFileID & destinationFileID")
        var status = AudioFileOpenURL(fileURL as CFURL, .readPermission, fileFormat, &audioFileID)
        assert(status == noErr, "Failed to open fileURL")

        var destinationFormat = SignedIntLinearPCMStreamDescription
        status = AudioFileCreateWithURL(destinationURL as CFURL, kAudioFileCAFType, &destinationFormat, AudioFileFlags.eraseFile, &destFileID)

        guard
            let sourceFileID = audioFileID,
            let destinationFileID = destFileID
        else {
            fatalError("Failed to get sourceFileID and destinationFileID")
        }

        var sourceFormat = AudioStreamBasicDescription()
        var size = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)

        print("Get sourceFile format")
        status = AudioFileGetProperty(sourceFileID, kAudioFilePropertyDataFormat, &size, &sourceFormat)
        assert(status == noErr, "AudioFileGetProperty get sourcefile AudioStreamBasicDescription failed")

        print("Create converter with both sourceFormat & destinationFormat")
        AudioConverterNew(&sourceFormat, &destinationFormat, &converter)
        guard let audioConverter = converter else {
            fatalError("Failed to new a converter")
        }

        let bufferSize = 4096
        let outputSize = UInt32(bufferSize)

        print("Get MP3 packet size upperBound")
        var sizePerPacket: UInt32 = 0
        size = UInt32(MemoryLayout<UInt32>.size)
        // MP3's mBytesPerPackets = 0, need get its PacketSizeUpperBound
        status = AudioFileGetProperty(sourceFileID, kAudioFilePropertyPacketSizeUpperBound, &size, &sizePerPacket)
        assert(status == noErr, "Failed to get MP3's kAudioFilePropertyPacketSizeUpperBound")

        var outputPacketDesc = AudioStreamPacketDescription()
        let bufferPointer = UnsafeMutablePointer<CChar>.allocate(capacity: bufferSize)

        var inUserData = ConverterInputUserData(
            sourceFileID: sourceFileID,
            sourceBufferSize: outputSize,
            sourceSizePerPacket: sizePerPacket,
            filePositionPointer: 0,
            bufferPointer: bufferPointer,
            packetDescriptionPointer: &outputPacketDesc
        )

        var bufferList = AudioBufferList()
        bufferList.mNumberBuffers = 1
        bufferList.mBuffers.mNumberChannels = destinationFormat.mChannelsPerFrame
        bufferList.mBuffers.mData = malloc(bufferSize)
        bufferList.mBuffers.mDataByteSize = outputSize

        var outputFilePosition: Int64 = 0
        var numberOutputPackets = outputSize / destinationFormat.mBytesPerPacket

        while true {
            status = AudioConverterFillComplexBuffer(audioConverter, converterInputDataProc, &inUserData, &numberOutputPackets, &bufferList, nil)
            assert(status == noErr, "AudioConverterFillComplexBuffer failed")

            print("Number outputPackets:", numberOutputPackets)
            print("OutputFilePosition", outputFilePosition)
            if numberOutputPackets == 0 {
                print("EOF")
                break
            }

            let inNumBytes = bufferList.mBuffers.mDataByteSize
            status = AudioFileWritePackets(destinationFileID, false, inNumBytes, inUserData.packetDescriptionPointer, outputFilePosition, &numberOutputPackets, bufferList.mBuffers.mData!)
            assert(status == noErr, "AudioFileWritePackets failed")

            outputFilePosition += Int64(numberOutputPackets)
        }

        free(bufferList.mBuffers.mData)
        bufferPointer.deallocate()
        AudioFileClose(sourceFileID)
        AudioFileClose(destinationFileID)
        if converter != nil { AudioConverterDispose(converter!) }
    }
}
