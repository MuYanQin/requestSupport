//
//  AudioUnit+Helper.swift
//  Panel
//
//  Created by peanut on 2023/12/21.
//

import Cocoa
import SimplyCoreAudio
import CoreAudio
import AudioToolbox

extension AudioUnit {
    
    @discardableResult
    static func createAudionUnit(_ unit: inout AudioUnit? , _ type: ComponentType = .output,_ subType: ComponentSubType  = .HALOutput)  -> OSStatus{
        var inputAcd = AudioComponentDescription()
        var ctype :OSType = 0
        var cstype :OSType = 0
        ConstantEnum.relayComponentTypeEnum(type, &ctype)
        ConstantEnum.relayComponentSubTypeEnum(subType, &cstype)
        inputAcd.componentType = ctype;
        inputAcd.componentSubType = cstype;
        inputAcd.componentManufacturer = kAudioUnitManufacturer_Apple;
        let comp =  AudioComponentFindNext(nil, &inputAcd);
        //输入单元
        var audioUnit: AudioUnit?
        AudioComponentInstanceNew(comp!, &audioUnit)
        let err = AudioUnitInitialize(audioUnit!)
        unit = audioUnit!
        return err
    }
    
    
    @discardableResult
    func setPropertySetInputCallback(_ inputProcCallback: AURenderCallback,_ inputProcRefCon : UnsafeMutableRawPointer?) ->OSStatus {
        
        var callback = AURenderCallbackStruct()
        callback.inputProc = inputProcCallback
        callback.inputProcRefCon = inputProcRefCon

        let err =  AudioUnitSetProperty(self,kAudioOutputUnitProperty_SetInputCallback,kAudioUnitScope_Input, 0,
            &callback,UInt32(MemoryLayout<AURenderCallbackStruct>.size))
        return err
    }
    
    func setInputBuffer(_ inputBuffer: inout UnsafeMutableAudioBufferListPointer?,_ asbd: AudioStreamBasicDescription,_ bufferSizeFrames :UInt32)  {
        /**
         如果是非交错格式，那么需要为每个声道分配独立的缓冲区。
         这里使用AudioBufferList结构体来存储缓冲区，并为每个声道分配相应大小的缓冲区空间。

         如果是交错格式，那么只需要一个缓冲区来存储所有声道的采样点。
         同样，使用AudioBufferList结构体来存储缓冲区，并为其分配相应大小的缓冲区空间。
         
         交错模式：数字音频信号存储的方式。数据以连续帧的方式存放，即首先记录帧1的左声道样本和右声道样本，再开始帧2的记录。
         非交错模式：首先记录的是一个周期内所有帧的左声道样本，再记录所有右声道样本。

         */
        let bufferSizeBytes =  bufferSizeFrames * asbd.mBytesPerFrame
        if (asbd.mFormatFlags & kAudioFormatFlagIsNonInterleaved) != 0{
            print("处理非交错格式音频数据")
            let propsize = MemoryLayout<AudioBufferList>.offset(of: \.mBuffers)! + (MemoryLayout<AudioBuffer>.size * Int(asbd.mChannelsPerFrame))
            //给inputBuffer 最大多少个缓冲区
            inputBuffer = AudioBufferList.allocate(maximumBuffers: Int(propsize))
            //这里设置缓冲区 asbd.mChannelsPerFrame 个
            inputBuffer!.count = Int(asbd.mChannelsPerFrame)

            for i in 0 ..< inputBuffer!.count {
                inputBuffer![i].mNumberChannels = 1
                inputBuffer![i].mDataByteSize = bufferSizeBytes
                inputBuffer![i].mData = nil
            }
        }else{
            print("处理交错格式音频数据")
            let propsize = MemoryLayout<AudioBufferList>.offset(of: \.mBuffers)! + (MemoryLayout<AudioBuffer>.size * 1)
            inputBuffer = AudioBufferList.allocate(maximumBuffers: propsize)
            inputBuffer!.count = 1
            inputBuffer![0].mNumberChannels = asbd.mChannelsPerFrame
            inputBuffer![0].mDataByteSize = bufferSizeBytes
            inputBuffer![0].mData = malloc(Int(bufferSizeBytes))
        }
    }
    

    
    
    @discardableResult
    func setPropertyCurrentDevice(_ deviceid:inout AudioObjectID) ->OSStatus {
        
        let size = UInt32(MemoryLayout<AudioObjectID>.size)
        //关联设备直接把audioUnit单元关联到固定的设备。与inScope、inElement并没有关联所以值可以随便给
        let err = AudioUnitSetProperty(self, kAudioOutputUnitProperty_CurrentDevice, kAudioUnitScope_Global, 0, &deviceid, size)
        return err
    }
    
    
    /// 获取unit的ASBD
    /// - Parameters:
    ///   - asbd: 获取UnIt的asbd对象
    ///   - scope: ScopeType类型 对应AudioUnitScope类型
    /// - Returns: OSStatus
    @discardableResult
    func getPropertyStreamFormat(_ asbd: inout AudioStreamBasicDescription,_ scope:ScopeType,_ bus: UInt32) ->OSStatus {
        
        var size = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
        var scopeType: AudioUnitScope  = 0
        ConstantEnum.relayScopeTypeEnum(scope, &scopeType)
        /**
         /*
         AudioUnitGetProperty函数用于获取音频单元的属性值。

         参数含义如下：

         inUnit：要获取属性的音频单元。
         inID：要获取的属性的标识符。 比如要获取StreamFormat、bufferFrame 、SampleRate    等
         inScope：属性的作用域，指定属性适用的范围。例如，可以是输入范围、输出范围或全局范围。   指定获取输入通道、还是输出通道更或者是全局的bufferFrame 、SampleRate
         inElement：属性所属的元素，用于指定作用域内的特定元素。例如，对于输入范围，可以指定特定的输入通道。  指定获取哪个bus的  输入通道、还是输出通道
         outData：指向存储属性值的缓冲区的指针。
         ioDataSize：指向一个整数，表示缓冲区的大小。在调用函数之前，它包含缓冲区的大小，返回时将包含实际写入缓冲区的数据的大小。
         使用这些参数，可以通过调用AudioUnitGetProperty函数来获取音频单元的特定属性值。
         inScope、inElement
          有时候没有真实的语义 但是需要传输进入指 这时候就可以随便给了  比如 inId是kAudioOutputUnitProperty_CurrentDevice 绑定设备时候 等情况
          
          有时候是有寓意的比如获取StreamFormat 的时候可以指定哪个bus的输入、输出
          
         */
         */
        let err = AudioUnitGetProperty(self,
                              kAudioUnitProperty_StreamFormat,
                                       scopeType,bus,&asbd,&size)
        return err
    }
    @discardableResult
    func setPropertyStreamFormat(_ asbd:inout AudioStreamBasicDescription,_ scope:ScopeType,_ bus: UInt32) ->OSStatus {
        
        let size = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
        var scopeType: AudioUnitScope  = 0
        ConstantEnum.relayScopeTypeEnum(scope, &scopeType)
        let err = AudioUnitSetProperty(self,
                              kAudioUnitProperty_StreamFormat,
                                       scopeType,bus,&asbd,size)
        return err
    }
    
    /// 获取unit的BufferFrameSize
    /// - Parameters:
    ///   - bufferSizeFrames: 获取Unit的BufferFrameSize
    ///   - scope: ScopeType类型 对应AudioUnitScope类型
    /// - Returns: OSStatus
    @discardableResult
    func getPropertyBufferFrameSize(_ bufferSizeFrames: inout UInt32,_ scope:ScopeType) ->OSStatus{
        
        var size = UInt32(MemoryLayout<UInt32>.size)
        var scopeType: AudioUnitScope  = 0
        ConstantEnum.relayScopeTypeEnum(scope, &scopeType)
        let err =  AudioUnitGetProperty(self,
                            kAudioDevicePropertyBufferFrameSize,
                                      kAudioUnitScope_Global,
                                      0,
                                      &bufferSizeFrames,
                                      &size)
        return err
    }

    
    @discardableResult
    func setPropertyElementCount(_ input:Bool, _ busCount:inout UInt32) -> OSStatus {
       return AudioUnitSetProperty(    self,
                                kAudioUnitProperty_ElementCount,
                                  input ? kAudioUnitScope_Input:kAudioUnitScope_Output,
                                0,
                                &busCount,
                                 UInt32(MemoryLayout<UInt32>.size))
    }
    
    public var matrixLevels: [[Float32]] {
           let count = (8 + 1) * (4 + 1)
           var size = UInt32(count * MemoryLayout<Float32>.size)
           var volumes: [Float32] = Array(repeating: Float32(0), count: Int(count))

           AudioUnitGetProperty(
               self,
               kAudioUnitProperty_MatrixLevels,
               kAudioUnitScope_Global,
               0,
               &volumes,
               &size
           )
           let chunkSize = Int(4 + 1)
           return stride(from: 0, to: count, by: chunkSize).map {
               Array(volumes[Int($0)..<min(Int($0) + chunkSize, volumes.count)])
           }
       }
}
