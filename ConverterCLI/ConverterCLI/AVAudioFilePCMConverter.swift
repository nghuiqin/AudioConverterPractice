//
//  AVAudioFilePCMConverter.swift
//  ConverterCLI
//
//  Created by Hui Qin Ng on 2019/7/18.
//  Copyright © 2019 Hui Qin Ng. All rights reserved.
//

import AVFoundation

struct AVAudioFilePCMConverter {
    static func convertToPCMFormat(fileURL: URL, destinationURL: URL) {
        do {
            let audioFile = try AVAudioFile(forReading: fileURL)
            let destinationFile = try AVAudioFile(forWriting: destinationURL, settings: [
                AVFormatIDKey: kAudioFormatLinearPCM,
                AVSampleRateKey: 44100,
                AVNumberOfChannelsKey: 2
                ], commonFormat: .pcmFormatFloat32, interleaved: false)

            let pcmFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 44100, channels: 2, interleaved: false)!

            var offset: UInt32 = 0
            let audioFileLength = AVAudioFrameCount(audioFile.length)
            var size = AVAudioFrameCount(4096)
            while offset <= audioFile.length {
                if audioFileLength - offset < size {
                    size = audioFileLength - size
                }

                print("Current offset:", offset)
                print("Current size:", size)
                print("Audio file length:", audioFileLength)

                let buffer = AVAudioPCMBuffer(pcmFormat: pcmFormat, frameCapacity: size)!
                try audioFile.read(into: buffer, frameCount: size)

                print("Read buffer frame length:", buffer.frameLength)
                print("Read buffer content:", buffer.floatChannelData![0].pointee)

                try destinationFile.write(from: buffer)

                offset += size
            }

        } catch {
            print("Failed to convert audiofile with error:", error.localizedDescription)
        }
    }
}
