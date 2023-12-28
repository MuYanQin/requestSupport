//
//  ConstantEnume.swift
//  Panel
//
//  Created by peanut on 2023/12/22.
//

import Cocoa
import SimplyCoreAudio
import CoreAudio
import AudioToolbox

enum ObjectScopeType {
    case output,input,global
}
enum ScopeType {
    case output,input,global
}
enum ComponentType {
    case output,mixer,effect
}
enum ComponentSubType {
    case HALOutput,defaultOutput,systemOutput,stereoMixer,multiChannelMixer,matrixMixer,spatialMixer,splitter,multiSplitter
}

class ConstantEnum {
     static func relayComponentTypeEnum(_ type:  ComponentType,_ ctype: inout OSType) {
         switch type {
         case .output:
             ctype = kAudioUnitType_Output
             break
         case .mixer:
             ctype = kAudioUnitType_Mixer
             break
         case .effect:
             ctype = kAudioUnitType_Effect
             break
         }
     }
    
     static func relayComponentSubTypeEnum(_ type:  ComponentSubType,_ subtype: inout OSType) {
        switch type {
        case .HALOutput:
            subtype = kAudioUnitSubType_HALOutput
            break
        case .defaultOutput:
            subtype = kAudioUnitSubType_DefaultOutput
            break
        case .systemOutput:
            subtype = kAudioUnitSubType_SystemOutput
            break
        case .stereoMixer:
            subtype = kAudioUnitSubType_StereoMixer
            break
        case .multiChannelMixer:
            subtype = kAudioUnitSubType_MultiChannelMixer
            break
        case .matrixMixer:
            subtype = kAudioUnitSubType_MatrixMixer
            break
        case .spatialMixer:
            subtype = kAudioUnitSubType_SpatialMixer
            break
        case .splitter:
            subtype = kAudioUnitSubType_Splitter
            break
        case .multiSplitter:
            subtype = kAudioUnitSubType_MultiSplitter
            break
        }
         
     }
    static func relayScopeTypeEnum(_ type:  ScopeType,_ scope: inout AudioUnitScope) {
        switch type {
        case .output:
            scope = kAudioUnitScope_Output
            break
        case .input:
            scope = kAudioUnitScope_Input
            break
        case .global:
            scope = kAudioUnitScope_Global
            break
        }
    }
    static func relayObjectScopeTypeEnum(_ type:  ObjectScopeType,_ scope: inout AudioObjectPropertyScope) {
        switch type {
        case .output:
            scope = kAudioObjectPropertyScopeOutput
            break
        case .input:
            scope = kAudioObjectPropertyScopeInput
            break
        case .global:
            scope = kAudioObjectPropertyScopeGlobal
            break
        }
    }
}
