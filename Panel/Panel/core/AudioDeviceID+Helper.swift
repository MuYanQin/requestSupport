//
//  AudioDeviceID+Helper.swift
//  Panel
//
//  Created by peanut on 2023/12/23.
//

import Cocoa
import SimplyCoreAudio
import CoreAudio
import AudioToolbox

extension AudioDeviceID{
    
    
    @discardableResult
    /// 设置当前设备是系统的默认输出 还是输出
    /// - Parameter output:
    /// - Returns:
    func setPropertyDataDefaultDevice(_ output:Bool) -> OSStatus {
        var propAddress = AudioObjectPropertyAddress()
        propAddress.mSelector = output ? kAudioHardwarePropertyDefaultOutputDevice : kAudioHardwarePropertyDefaultInputDevice
        propAddress.mScope = kAudioObjectPropertyScopeGlobal;
        propAddress.mElement = kAudioObjectPropertyElementMain;
        
        let propertySize = UInt32(MemoryLayout<AudioDeviceID>.size)
        var pid :AudioDeviceID = self
        return AudioObjectSetPropertyData(AudioObjectID(kAudioObjectSystemObject),
                                                  &propAddress,
                                                  0,nil,propertySize,
                                            &pid)
    }
    
    @discardableResult
    func addPropertyVolumeScalarListener(_ callBack:AudioObjectPropertyListenerProc,_ inClientData: UnsafeMutableRawPointer?) -> OSStatus {
        var propAddress = AudioObjectPropertyAddress()
        propAddress.mSelector = kAudioDevicePropertyVolumeScalar;
        propAddress.mScope = kAudioObjectPropertyScopeOutput;
        propAddress.mElement = 0;
        return AudioObjectAddPropertyListener(self,&propAddress, callBack, inClientData)
    }
    
    @discardableResult
    func getGetPropertyDataVolumeScalar(_ output:Bool) -> Float32 {
        var propAddress = AudioObjectPropertyAddress()
        propAddress.mSelector = kAudioDevicePropertyVolumeScalar;
        propAddress.mScope = output ? kAudioObjectPropertyScopeOutput : kAudioObjectPropertyScopeInput
        propAddress.mElement = 0;
        var scalar: Float32 = 0.0
        var propertySize = UInt32(MemoryLayout<Float32>.size)
        AudioObjectGetPropertyData(self, &propAddress, 0, nil, &propertySize, &scalar)
        return scalar
    }
    
    
    @discardableResult
    func getPropertyDataBufferFrameSize(_ scope:ObjectScopeType) -> UInt32 {
        var propertyAddress = AudioObjectPropertyAddress()
        propertyAddress.mSelector = kAudioDevicePropertyBufferFrameSize
        var scopeType: AudioObjectPropertyScope  = 0
        ConstantEnum.relayObjectScopeTypeEnum(scope, &scopeType)
        propertyAddress.mScope = scopeType
        propertyAddress.mElement = kAudioObjectPropertyElementMain
        var size = UInt32(MemoryLayout<UInt32>.size)
        var value: UInt32 = 0
        AudioObjectGetPropertyData(self, &propertyAddress, UInt32(0), nil, &size, &value)
        return value
    }
    
    @discardableResult
    func getPropertyDataSafetyOffset(_ scope:ObjectScopeType) -> UInt32 {
        var propertyAddress = AudioObjectPropertyAddress()
        propertyAddress.mSelector = kAudioDevicePropertySafetyOffset
        var scopeType: AudioObjectPropertyScope  = 0
        ConstantEnum.relayObjectScopeTypeEnum(scope, &scopeType)
        propertyAddress.mScope = scopeType
        propertyAddress.mElement = kAudioObjectPropertyElementMain
        var value: UInt32 = 0
        if AudioObjectHasProperty(self, &propertyAddress) {
            var size = UInt32(MemoryLayout<UInt32>.size)
            AudioObjectGetPropertyData(self, &propertyAddress, UInt32(0), nil, &size, &value)
        }
        return value
    }
}
