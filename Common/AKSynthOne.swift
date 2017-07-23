//
//  AKSynthOne.swift
//  AudioKit
//
//  Created by Aurelius Prochazka, revision history on Github.
//  Copyright © 2017 Aurelius Prochazka. All rights reserved.
//

import AudioKit

/// Pulse-Width Modulating Oscillator Bank
///
open class AKSynthOne: AKPolyphonicNode, AKComponent {
    public typealias AKAudioUnitType = AKSynthOneAudioUnit
    /// Four letter unique description of the node
    public static let ComponentDescription = AudioComponentDescription(instrument: "aks1")

    // MARK: - Properties

    public var internalAU: AKAudioUnitType?
    public var token: AUParameterObserverToken?
    public var viewControllers: Set<SynthOneViewController> = []

    fileprivate var waveformArray = [AKTable]()

    fileprivate var auParameters: [AUParameter] = []
    open var parameters: [Double] {
        get {
            var result: [Double] = []
            if let floatParameters = internalAU?.parameters as? [NSNumber] {
                for number in floatParameters {
                    result.append(number.doubleValue)
                }
            }
            return result
        }
        set {
//            internalAU?.parameters = newValue
            // for each parameter, check if it has changed and then see about changing via parameter tree
//            if parameters != newValue {
            if internalAU?.isSetUp() ?? false {
                    if let existingToken = token {
                        for (index, parameter) in auParameters.enumerated() {
                            if Double(parameter.value) != newValue[index] {
                                internalAU?.parameterTree?.parameter(withAddress:UInt64(index))?.value = Float(newValue[index])
                                parameter.setValue(Float(newValue[index]), originator: existingToken)
                                internalAU?.parameters[index] = Float(newValue[index])
                            }
                        }
                    }
                } else {
                    AKLog("Setting directly")
                    internalAU?.parameters = newValue
                }
//            }
        }
    }


    
//    open var parameterValues: [Double] = []


    /// Ramp Time represents the speed at which parameters are allowed to change
    open dynamic var rampTime: Double = AKSettings.rampTime {
        willSet {
            internalAU?.rampTime = newValue
        }
    }

    // MARK: - Initialization

    /// Initialize the synth with defaults
    public convenience override init() {
        self.init(waveformArray: [AKTable(.triangle), AKTable(.square), AKTable(.sine), AKTable(.sawtooth)])
    }

    /// Initialize this synth
    ///
    /// - Parameters:
    ///   - waveformArray:      An array of 4 waveforms
    ///
    public init(waveformArray: [AKTable]) {
        
        self.waveformArray = waveformArray
        _Self.register()

        super.init()
        AVAudioUnit._instantiate(with: _Self.ComponentDescription) { [weak self] avAudioUnit in

            self?.avAudioNode = avAudioUnit
            self?.midiInstrument = avAudioUnit as? AVAudioUnitMIDIInstrument
            self?.internalAU = avAudioUnit.auAudioUnit as? AKAudioUnitType
            
            for (i, waveform) in waveformArray.enumerated() {
                self?.internalAU?.setupWaveform(UInt32(i), size: Int32(UInt32(waveform.count)))
                for (j, sample) in waveform.enumerated() {
                    self?.internalAU?.setWaveform(UInt32(i), withValue: sample, at: UInt32(j))
                }
            }
        }

        guard let tree = internalAU?.parameterTree else {
            return
        }
        auParameters = tree.allParameters

        token = tree.token(byAddingParameterObserver: { [weak self] address, value in

            guard let param: AKSynthOneParameter = AKSynthOneParameter(rawValue: Int(address)) else {
                return
            }

            DispatchQueue.main.async {
                for vc in self!.viewControllers {
                switch param {
                case .morph1PitchOffset:
                    vc.osc1SemiKnob?.value = Double(value)
                    vc.displayLabel?.text = vc.osc1SemiKnob?.statusText
                case .morph2PitchOffset:
                    vc.osc2SemiKnob?.value = Double(value)
                    vc.displayLabel?.text = vc.osc2SemiKnob?.statusText
                case .detuningMultiplier:
                    vc.osc2DetuneKnob?.value = Double(value)
                    vc.displayLabel?.text = vc.osc2DetuneKnob?.statusText
                case .morphBalance:
                    vc.oscMixKnob?.value = Double(value)
                    vc.displayLabel?.text = vc.oscMixKnob?.statusText
                case .morph1Mix:
                    vc.osc1VolKnob?.value = Double(value)
                    vc.displayLabel?.text = vc.osc1VolKnob?.statusText
                case .morph2Mix:
                    vc.osc2VolKnob?.value = Double(value)
                    vc.displayLabel?.text = vc.osc2VolKnob?.statusText
                case .resonance:
                    vc.rezKnob?.value = Double(value)
                    vc.displayLabel?.text = vc.rezKnob?.statusText
                case .subOscMix:
                    vc.subMixKnob?.value = Double(value)
                    vc.displayLabel?.text = vc.subMixKnob?.statusText
                case .fmMix:
                    vc.fmMixKnob?.value = Double(value)
                    vc.displayLabel?.text = vc.fmMixKnob?.statusText
                case .fmMod:
                    vc.fmModKnob?.value = Double(value)
                    vc.displayLabel?.text = vc.fmModKnob?.statusText
                case .noiseMix:
                    vc.noiseMixKnob?.value = Double(value)
                    vc.displayLabel?.text = vc.noiseMixKnob?.statusText
                default:
                    _ = 0
                    // do nothing
                }
                }
            }
        })
        for index in 0 ..< parameters.count {
//            parameters[index] = Double(auParameters[index].value)
        }
        internalAU?.parameters = parameters
//        internalAU?.index1 = Float(index1)
// ...
//        internalAU?.detuningMultiplier = Float(detuningMultiplier)
    }

    /// stops all notes
    open func reset() {
        internalAU?.reset()
    }

    // MARK: - AKPolyphonic

    // Function to start, play, or activate the node at frequency
    open override func play(noteNumber: MIDINoteNumber, velocity: MIDIVelocity, frequency: Double) {
        internalAU?.startNote(noteNumber, velocity: velocity, frequency: Float(frequency))
    }

    /// Function to stop or bypass the node, both are equivalent
    open override func stop(noteNumber: MIDINoteNumber) {
        internalAU?.stopNote(noteNumber)
    }
}
