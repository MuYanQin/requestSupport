//
//  ViewController.swift
//  Panel
//
//  Created by peanut on 2023/12/18.
//

import Cocoa
import SimplyCoreAudio
import CoreAudio
import AudioToolbox
let loopback_name =  "IXIMega Device"
let m2_input_name =  "Built-in Microphone"
let m2_output_name = "Built-in Output"

class ViewController: NSViewController {
    var buffer: CircularBuffer<Int32>?
    var buffer2: CircularBuffer<Int32>?
    
    
    var inputBuffer:UnsafeMutableAudioBufferListPointer?
    var inputBuffer2:UnsafeMutableAudioBufferListPointer?
    

    var inputLatestSampleTime: Int64 = -1
    var outputLatestSampleTime: Int64 = -1
    var safetyOffset: Double = 0
    var sampleOffset: Double = 0
    
    var inputLatestSampleTime1: Int64 = -1
    var outputLatestSampleTime1: Int64 = -1
    var safetyOffset1: Double = 0
    var sampleOffset1: Double = 0
    
    let simply = SimplyCoreAudio()
    var fileId : ExtAudioFileRef?

    //输入相关
    var inputUnit:AudioUnit?
    var recordedUnit:AudioUnit?
    var outputUnit:AudioUnit?
    var mixerUnit:AudioUnit?
    var graph:AUGraph?
    var streamFormat  = AudioStreamBasicDescription()
    var recordUnitASBD  = AudioStreamBasicDescription()
    //输出相关
    var loopDevice:AudioDevice?
    var M2OutDevice:AudioDevice?
    var M2InDevice:AudioDevice?
    @objc func btnClick() -> Void {
        ExtAudioFileDispose(fileId!);
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        
        //创建按钮停止写入录音
        let btn = NSButton()
        btn.frame = CGRectMake(100, 100, 100, 100)
        btn.target = self
        btn.action = #selector(btnClick)
        self.view.addSubview(btn)
        
        //创建音频输入单元
        createInputAudionUnit(&inputUnit)
        //创建mic输单元
         createInputAudionUnit(&recordedUnit)
        //获取虚拟设备 和M2设备
        findLoopAndM2Device()
        
        //inputUnit关联虚拟设备到输入单元
        var deviceid = loopDevice?.id ?? kAudioObjectUnknown
        checkErr(inputUnit!.setPropertyCurrentDevice(&deviceid))
        
        //recordedUnit关联M2输入设备
        deviceid = M2InDevice?.id ?? kAudioObjectUnknown
        checkErr(recordedUnit!.setPropertyCurrentDevice(&deviceid))

        
        /**
            采样率不同的话可能会导致噪音、蜂鸣 所以需要保证采样率一致。所有的单元都适用输入的采样率
            因为每个总线的输出和输入的采样率可能不一样 所以获取 输入的采样率 设置给输出
         */
        //获取inputunit 1bus的输出采样率
        checkErr(inputUnit!.getPropertyStreamFormat(&streamFormat,.output,1))
        streamFormat.mChannelsPerFrame = loopDevice!.channels(scope: .output)

        
        var deviceFormat = AudioStreamBasicDescription()
        checkErr(inputUnit!.getPropertyStreamFormat(&deviceFormat, .input, 1))
  
        print("inputUnit =  1bus input rate \(deviceFormat.mSampleRate),1bus ouput rate \(streamFormat.mSampleRate)\n")
        streamFormat.mSampleRate = deviceFormat.mSampleRate
        checkErr(inputUnit!.setPropertyStreamFormat(&streamFormat, .output,1))

        //获取recordUnit 1bus 输出采样率
        checkErr(recordedUnit!.getPropertyStreamFormat(&recordUnitASBD, .output, 1))
        print("recordedUnit = 1bus ouput rate \(streamFormat.mSampleRate)\n")
        //使用与系统相同的采样率 保持采样率一致
        recordUnitASBD.mSampleRate = streamFormat.mSampleRate
        recordUnitASBD.mChannelsPerFrame = streamFormat.mChannelsPerFrame
        checkErr(recordedUnit!.setPropertyStreamFormat(&recordUnitASBD, .output, 1))
        

        //获取InputUnit单元多少个缓冲帧
        var bufferSizeFrames : UInt32 = 0
        checkErr(inputUnit!.getPropertyBufferFrameSize(&bufferSizeFrames, .global))
        
        //获取recordedUnit单元多少个缓冲帧
        var rbufferSizeFrames : UInt32 = 0
        checkErr(recordedUnit!.getPropertyBufferFrameSize(&rbufferSizeFrames, .global))
        
        //初始化环形缓冲区 、缓冲区
        inputUnit!.setInputBuffer(&inputBuffer, streamFormat, bufferSizeFrames)
        recordedUnit!.setInputBuffer(&inputBuffer2, streamFormat, rbufferSizeFrames)
        
        
        buffer = CircularBuffer<Int32>(channelCount: Int(streamFormat.mChannelsPerFrame), capacity: Int(bufferSizeFrames) * 2048)
        buffer2 = CircularBuffer<Int32>(channelCount: Int(streamFormat.mChannelsPerFrame), capacity: Int(rbufferSizeFrames) * 2048)

        
        inputUnit!.setPropertySetInputCallback(MyRenderIn, Unmanaged.passUnretained(self).toOpaque())

        recordedUnit!.setPropertySetInputCallback(MyRenderIn1, Unmanaged.passUnretained(self).toOpaque())


        // MARK: - 设置录音的ASBD -
        //在这里创建路径下 并获取 AudioFileId
        var asbd = AudioStreamBasicDescription()
        asbd.mFormatID = kAudioFormatLinearPCM;
        asbd.mFormatFlags = kLinearPCMFormatFlagIsBigEndian | kLinearPCMFormatFlagIsSignedInteger;
        asbd.mSampleRate = streamFormat.mSampleRate;
        asbd.mFormatFlags = streamFormat.mFormatFlags;
        asbd.mBytesPerPacket = streamFormat.mBytesPerPacket;
        asbd.mFramesPerPacket = streamFormat.mFramesPerPacket;
        asbd.mBytesPerFrame = streamFormat.mBytesPerFrame;
        asbd.mChannelsPerFrame = 1;
        asbd.mBitsPerChannel = streamFormat.mBitsPerChannel;


        // create the audio file
        let directory = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true).last!
        let filePath = "\(directory)/test.caf"
        let myFileURL = URL(fileURLWithPath: filePath)
        //打印函数
        print(myFileURL as Any)
        checkErr(ExtAudioFileCreateWithURL(myFileURL as CFURL, kAudioFileCAFType, &asbd, nil, AudioFileFlags.eraseFile.rawValue, &fileId))

        ExtAudioFileSetProperty(fileId!, kExtAudioFileProperty_ClientDataFormat, UInt32(MemoryLayout<AudioStreamBasicDescription>.size), &asbd)
        // MARK: - 输出代码 -

        //创建图形
        checkErr(NewAUGraph(&graph))
        checkErr(AUGraphInitialize(graph!))
        //创建输出单元
        var outNode : AUNode = 0
        checkErr(graph!.getNode(&outNode))
        //创建混音单元
        var mixerNode :AUNode = 0
        checkErr(graph!.getNode(&mixerNode,.mixer,.matrixMixer))
        checkErr(AUGraphOpen(graph!))
        checkErr(graph!.getUnit(outNode , &outputUnit))
        
        //设置输出单元的采样率
        checkErr(outputUnit!.setPropertyStreamFormat(&streamFormat, .input, 0))
        
        //获取混音单元
        checkErr(graph!.getUnit(mixerNode, &mixerUnit))

        var data : UInt32 = 2
        AudioUnitSetProperty(  mixerUnit!,
                               kAudioUnitProperty_MeteringMode,
                               kAudioUnitScope_Global,
                               0,
                               &data,
                               UInt32(MemoryLayout<UInt32>.size))
        var busNum : UInt32 = 2
        checkErr(mixerUnit!.setPropertyElementCount(true, &busNum))
        busNum  = 1
        checkErr(mixerUnit!.setPropertyElementCount(false, &busNum))

        checkErr(mixerUnit!.setPropertyStreamFormat(&streamFormat, .input, 0))
        checkErr(mixerUnit!.setPropertyStreamFormat(&streamFormat, .input, 1))
        checkErr(mixerUnit!.setPropertyStreamFormat(&streamFormat, .output, 0))
    
        
        //设置回调函数
        //mixer获取系统音频的回调函数
        checkErr(graph!.setInputCallback(MyRenderOut, Unmanaged.passUnretained(self).toOpaque(), mixerNode, 0))
        
        //mixer获取mic音频的回调函数
        checkErr(graph!.setInputCallback(MyRenderOut1, Unmanaged.passUnretained(self).toOpaque(), mixerNode, 1))
        
        //连接mixer 与输出单元、录音单元
        checkErr(AUGraphConnectNodeInput(graph!, mixerNode, 0, outNode, 0))
        
        var dims: [UInt32] = [0, 0]
        var theSize = UInt32(MemoryLayout<UInt32>.size * 2)
        checkErr(AudioUnitGetProperty(mixerUnit!,
                                      kAudioUnitProperty_MatrixDimensions,
                                      kAudioUnitScope_Global,
                                      0,
                                      &dims,
                                      &theSize))
        checkErr(AudioUnitSetParameter(mixerUnit!, kMatrixMixerParam_Volume, kAudioUnitScope_Global, 0xFFFFFFFF, 1.0, 0))
        //设置初始化的声音 都是1
        for i in 0..<4 {
            /* Set input volumes */
            checkErr(AudioUnitSetParameter(mixerUnit!, kMatrixMixerParam_Volume, kAudioUnitScope_Input,UInt32(i), 1.0, 0))

            for j in 0..<4 {
                /* Set output volumes (only one outer iteration necessary) */
                if i == 0 {
                    checkErr(AudioUnitSetParameter(mixerUnit!, kMatrixMixerParam_Volume, kAudioUnitScope_Output, UInt32(j), 1.0, 0))
                }

                /* Set cross point volumes - 1.0 for corresponding inputs/outputs, otherwise 0.0 */
                let crossPoint = (i << 16) | (j & 0x0000FFFF)
                checkErr(AudioUnitSetParameter(mixerUnit!, kMatrixMixerParam_Volume, kAudioUnitScope_Global, UInt32(crossPoint),  1.0 , 0))
            }
        }
        print(mixerUnit!.matrixLevels)

        deviceid = M2OutDevice?.id ?? kAudioObjectUnknown
        //绑定输出设备到output输出单元
        outputUnit!.setPropertyCurrentDevice(&deviceid)
        
        // MARK: - 添加mixerUnit单元的监听 -
//        AudioUnitAddRenderNotify(
//            mixerUnit!,
//            mixerCallback,
//            Unmanaged.passUnretained(self).toOpaque()
//        )
        
        //设置loopDevice为默认输出设备
        loopDevice!.id.setPropertyDataDefaultDevice(true)
        
        let scalar: Float32 = loopDevice!.id.getGetPropertyDataVolumeScalar(true)
        print("Volume(Scalar) for BGM = \(scalar)")
        loopDevice!.id.addPropertyVolumeScalarListener(volumeCallBack,Unmanaged.passUnretained(M2OutDevice!).toOpaque())
        
        checkErr(AudioOutputUnitStart(inputUnit!))
        checkErr(AudioOutputUnitStart(recordedUnit!))
        checkErr(AUGraphStart(graph!))
        
        
    }
    // MARK: - 录音混音后的音频 -
    let mixerCallback: AURenderCallback = {
        (inRefCon: UnsafeMutableRawPointer,
         ioActionFlags: UnsafeMutablePointer<AudioUnitRenderActionFlags>,
         inTimeStamp:  UnsafePointer<AudioTimeStamp>,
         inBusNumber: UInt32,
         inNumberFrames: UInt32,
         ioData: UnsafeMutablePointer<AudioBufferList>?) -> OSStatus in
        
        let vc = Unmanaged<ViewController>.fromOpaque(inRefCon).takeUnretainedValue()
        /**
         其他方法将取代节点连接，但此方法不会 - 因此即使您添加了回调，您的音频单元也可以保持连接。
         回调运行后，如果您发现缓冲区 (ioData) 中没有数据，请将此代码包含在回调代码中：
         if (*ioActionFlags == kAudioUnitRenderAction_PostRender) {
             // your code
         }
         这是必需的，因为以这种方式添加的回调在音频单元渲染其音频之前和之后运行，但您只想在渲染之后运行代码。
         */
        #warning("暂时直接返回写入")
        return noErr

        if ioActionFlags.pointee == AudioUnitRenderActionFlags.unitRenderAction_PostRender{
            // your code
            let tbuffer = UnsafeMutableAudioBufferListPointer.init(ioData)
            let writeBuffer = AudioBufferList.allocate(maximumBuffers: MemoryLayout<AudioBufferList>.size)
            writeBuffer.count = 1
            for i in 0 ..< writeBuffer.count {
                writeBuffer[i].mNumberChannels = 1
                writeBuffer[i].mDataByteSize = tbuffer![i].mDataByteSize
                writeBuffer[i].mData = tbuffer![i].mData
            }
            checkErr(ExtAudioFileWrite(vc.fileId!, inNumberFrames, writeBuffer.unsafePointer))
        }
        return noErr
    }
    // MARK: - 监听loopback虚拟设备音量 设置系统音量 -
    let volumeCallBack: AudioObjectPropertyListenerProc = {
        (inObjectID : AudioObjectID,
         inNumberAddresses :UInt32,
         inAddresses :UnsafePointer<AudioObjectPropertyAddress>,
         inClientData:UnsafeMutableRawPointer?)-> OSStatus in
        
        print("volume changed")
        var scalar: Float32 = inObjectID.getGetPropertyDataVolumeScalar(true)
        print("loopBackDevice scalar =  : \(scalar)")
        
        /*
         Some devices support volume control only via master channel. (BGM)
         Some devices support volume control only via each channel.  (Built-In Output)
         Some devices support both of master or channels.
         
         */
        /**
         当 mSelector 是kAudioDevicePropertyVolumeScalar、kAudioUnitProperty_Volume时
         mElement代表着通道index channel。0 就是主音量
         */
        var propAddress = AudioObjectPropertyAddress()
        propAddress.mSelector = kAudioDevicePropertyVolumeScalar;
        propAddress.mScope = kAudioObjectPropertyScopeOutput;
        propAddress.mElement = 1; //use 1 and 2 for build in output
        let device = Unmanaged<AudioDevice>.fromOpaque(inClientData!).takeUnretainedValue()
        let propertySize = UInt32(MemoryLayout<Float32>.size)
        AudioObjectSetPropertyData(device.id, &propAddress, 0, nil, propertySize, &scalar)
        propAddress.mElement = 2;
        AudioObjectSetPropertyData(device.id, &propAddress, 0, nil, propertySize, &scalar)
        
        propAddress.mElement = 0;
        AudioObjectSetPropertyData(device.id, &propAddress, 0, nil, propertySize, &scalar)

        return noErr
    }
    // MARK: - inputUnit单元获取音频写入环形缓冲区 -
    let MyRenderIn: AURenderCallback = {
      (inRefCon: UnsafeMutableRawPointer,
       ioActionFlags: UnsafeMutablePointer<AudioUnitRenderActionFlags>,
       inTimeStamp:  UnsafePointer<AudioTimeStamp>,
       inBusNumber: UInt32,
       inNumberFrames: UInt32,
       ioData: UnsafeMutablePointer<AudioBufferList>?) -> OSStatus in
        
        let vc = Unmanaged<ViewController>.fromOpaque(inRefCon).takeUnretainedValue()

        AudioUnitRender(vc.inputUnit!,
                        ioActionFlags,
                        inTimeStamp,
                        inBusNumber,
                        inNumberFrames,
                        vc.inputBuffer!.unsafeMutablePointer);
        let start = inTimeStamp.pointee.mSampleTime.int64Value
        let sampleTime =  inTimeStamp.pointee.mSampleTime.int64Value
        let end = start + Int64(inNumberFrames)
        

        if (vc.inputLatestSampleTime == -1) {
            vc.inputLatestSampleTime = sampleTime
            vc.computeOffset()
            let abl = UnsafeMutableAudioBufferListPointer(vc.inputBuffer!.unsafeMutablePointer)
            makeBufferSilent(abl)
          return noErr
        }
        vc.inputLatestSampleTime = sampleTime
        _ = vc.buffer!.write(from: vc.inputBuffer!.unsafeMutablePointer, start: start, end: end)
      return noErr
    }
    // MARK: - recorderUnit单元获取音频写入环形缓冲区 -
    let MyRenderIn1: AURenderCallback = {
      (inRefCon: UnsafeMutableRawPointer,
       ioActionFlags: UnsafeMutablePointer<AudioUnitRenderActionFlags>,
       inTimeStamp:  UnsafePointer<AudioTimeStamp>,
       inBusNumber: UInt32,
       inNumberFrames: UInt32,
       ioData: UnsafeMutablePointer<AudioBufferList>?) -> OSStatus in
        
        let vc = Unmanaged<ViewController>.fromOpaque(inRefCon).takeUnretainedValue()

        AudioUnitRender(vc.recordedUnit!,
                        ioActionFlags,
                        inTimeStamp,
                        inBusNumber,
                        inNumberFrames,
                        vc.inputBuffer2!.unsafeMutablePointer);
        let start = inTimeStamp.pointee.mSampleTime.int64Value
        let sampleTime =  inTimeStamp.pointee.mSampleTime.int64Value
        let end = start + Int64(inNumberFrames)
        
        if (vc.inputLatestSampleTime1 == -1) {
            vc.inputLatestSampleTime1 = sampleTime
            vc.computeOffset1()
            let abl = UnsafeMutableAudioBufferListPointer(vc.inputBuffer2!.unsafeMutablePointer)
            makeBufferSilent(abl)
          return noErr
        } else {
            vc.inputLatestSampleTime1 = sampleTime
        }
        _ = vc.buffer2!.write(from: vc.inputBuffer2!.unsafeMutablePointer, start: start, end: end)

      return noErr
    }
    // MARK: - mixer bus 0 获取音频 -
    let MyRenderOut: AURenderCallback = {
      (inRefCon: UnsafeMutableRawPointer,
       ioActionFlags: UnsafeMutablePointer<AudioUnitRenderActionFlags>,
       inTimeStamp:  UnsafePointer<AudioTimeStamp>,
       inBusNumber: UInt32,
       inNumberFrames: UInt32,
       ioData: UnsafeMutablePointer<AudioBufferList>?) -> OSStatus in
        let vc = Unmanaged<ViewController>.fromOpaque(inRefCon).takeUnretainedValue()
        let sampleTime = inTimeStamp.pointee.mSampleTime
        
        if (vc.outputLatestSampleTime == -1) {
            vc.outputLatestSampleTime = sampleTime.int64Value
            vc.computeOffset()
            let abl = UnsafeMutableAudioBufferListPointer(vc.inputBuffer2!.unsafeMutablePointer)
            makeBufferSilent(abl)
          return noErr
        } else {
            vc.outputLatestSampleTime = sampleTime.int64Value
        }
        let from = Int64(sampleTime + vc.sampleOffset - vc.safetyOffset)
        let to = from + Int64(inNumberFrames)

        _ = vc.buffer!.read(into: ioData!, from: from, to: to)

      return noErr
    }
    // MARK: - mixer bus 1 获取音频 -
    let MyRenderOut1: AURenderCallback = {
      (inRefCon: UnsafeMutableRawPointer,
       ioActionFlags: UnsafeMutablePointer<AudioUnitRenderActionFlags>,
       inTimeStamp:  UnsafePointer<AudioTimeStamp>,
       inBusNumber: UInt32,
       inNumberFrames: UInt32,
       ioData: UnsafeMutablePointer<AudioBufferList>?) -> OSStatus in
        let vc = Unmanaged<ViewController>.fromOpaque(inRefCon).takeUnretainedValue()

        let sampleTime = inTimeStamp.pointee.mSampleTime
        
        if (vc.outputLatestSampleTime1 == -1) {
            vc.outputLatestSampleTime1 = sampleTime.int64Value
            vc.computeOffset1()
            let abl = UnsafeMutableAudioBufferListPointer(ioData)!
            makeBufferSilent(abl)
          return noErr
        } else {
            vc.outputLatestSampleTime1 = sampleTime.int64Value
        }
        let from = Int64(sampleTime + vc.sampleOffset1 - vc.safetyOffset1)
        let to = from + Int64(inNumberFrames)

        _ = vc.buffer2!.read(into: ioData!, from: from, to: to)
        
      return noErr
    }
    func createInputAudionUnit(_ inputUnit:inout AudioUnit?){
        //创建unit单元
        AudioUnit.createAudionUnit(&inputUnit)
        

        //获取的HALUnit 有输出输出bus 我们仅输入 所以打开输入 关闭输出
        //与之前的单元不同 之前的单元只有一个总线0  输入输出都是在总线0
        //I/O单元有个约定 1是硬件的输入流  0 是硬件的输出流
        //如果I/O单元  是仅输入的单元，您需要在总线1上启用I/O，并在总线0上禁用。
        var enableFlag = UInt32(1)
        var disableFlag = UInt32(0)
        let propertySize = UInt32(MemoryLayout<UInt32>.size)
        //开启输入通道
        checkErr(AudioUnitSetProperty(inputUnit!, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Input, 1, &enableFlag, propertySize))
        //关闭输出通道
        checkErr(AudioUnitSetProperty(inputUnit!, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Output, 0, &disableFlag, propertySize))
    }
    func findLoopAndM2Device() -> Void {
        //获取自己创建的虚拟设备
        let allDevices = simply.allDevices
        for item in allDevices {
            if item.name == loopback_name{
                loopDevice = item
            }
            if item.name == m2_input_name{
                M2InDevice = item
            }
            if item.name == m2_output_name{
                M2OutDevice = item
            }
        }
    }
    
    func computeOffset() {
        let inputOffset = loopDevice!.id.getPropertyDataSafetyOffset(.input)
        let inputBuffer = loopDevice!.id.getPropertyDataBufferFrameSize(.input)
        let outputOffset = M2OutDevice!.id.getPropertyDataSafetyOffset(.output)
        let outputBuffer = M2OutDevice!.id.getPropertyDataSafetyOffset(.output)
        safetyOffset = Double(inputOffset + outputOffset + inputBuffer + outputBuffer)// + pow(2, 12)
        sampleOffset = Double(inputLatestSampleTime - outputLatestSampleTime)

    }
    func computeOffset1() {

        let inputOffset = M2InDevice!.id.getPropertyDataSafetyOffset(.input)
        let inputBuffer = M2InDevice!.id.getPropertyDataBufferFrameSize(.input)
        let outputOffset = M2OutDevice!.id.getPropertyDataSafetyOffset(.output)
        let outputBuffer = M2OutDevice!.id.getPropertyDataSafetyOffset(.output)
        safetyOffset1 = Double(inputOffset + outputOffset + inputBuffer + outputBuffer)// + pow(2, 12)
        sampleOffset1 = Double(inputLatestSampleTime1 - outputLatestSampleTime1)
    }

}


