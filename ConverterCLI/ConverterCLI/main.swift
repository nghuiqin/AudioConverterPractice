//
//  main.swift
//  ConverterCLI
//
//  Created by Hui Qin Ng on 2019/7/18.
//  Copyright © 2019 Hui Qin Ng. All rights reserved.
//

import Foundation
import AVFoundation

let fileURL = URL(fileURLWithPath: "/Users/huiqinng/Downloads/bensound-summer.mp3")
let destinationURL = URL(fileURLWithPath: "/Users/huiqinng/Downloads/test.caf")

//AVAudioFilePCMConverter.convertToPCMFormat(
//    fileURL: fileURL,
//    destinationURL: destinationURL
//)

AudioFileServicePCMConverter.convertToPCMFormat(
    fileURL: fileURL,
    fileFormat: kAudioFileMP3Type,
    destinationURL: destinationURL
)
