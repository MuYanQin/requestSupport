//
//  AUGraph+Helper.swift
//  Panel
//
//  Created by peanut on 2023/12/22.
//

import Cocoa
import SimplyCoreAudio
import CoreAudio
import AudioToolbox

extension AUGraph {
    
    @discardableResult
    func getNode(_ node: inout AUNode, _ type: ComponentType = .output,_ subType: ComponentSubType  = .HALOutput) -> OSStatus {
        var inputAcd = AudioComponentDescription()
        var ctype :OSType = 0
        var cstype :OSType = 0
        ConstantEnum.relayComponentTypeEnum(type, &ctype)
        ConstantEnum.relayComponentSubTypeEnum(subType, &cstype)
        inputAcd.componentType = ctype;
        inputAcd.componentSubType = cstype;
        inputAcd.componentManufacturer = kAudioUnitManufacturer_Apple;
        let err =  AUGraphAddNode(self, &inputAcd, &node)
        return err
    }
    @discardableResult
    func getUnit(_ node: AUNode ,_ unit: inout AudioUnit?) -> OSStatus {
        let err =    AUGraphNodeInfo(self, node, nil, &unit)
        return err
    }
    @discardableResult
    func setInputCallback(_ inputProcCallback: AURenderCallback,_ inputProcRefCon : UnsafeMutableRawPointer?,_ node :AUNode,_ bus:UInt32) -> OSStatus {
        var outputCallback = AURenderCallbackStruct()
        outputCallback.inputProc = inputProcCallback
        outputCallback.inputProcRefCon = inputProcRefCon
        //mixer获取系统音频的回调函数
        return AUGraphSetNodeInputCallback(self, node, bus, &outputCallback)
    }
}
