//
//  ViewController.swift
//  HintsightFHE
//
//  Created by Luo Kaiwen on 15/7/24.
//

import UIKit
import AVFoundation
import Combine


class SpeakerVerificationVC: UIViewController, AVAudioRecorderDelegate {
    
    let verifyButton = HSTintedButton(color: UIColor(hexString: Colors.green.rawValue, alpha: 1) ?? .systemGreen,
                                      title: "VERIFY", systemImageName: "")
    let resetButton = HSTintedButton(color: UIColor(hexString: Colors.pink.rawValue, alpha: 1) ?? .systemPink,
                                     title: "RESET", systemImageName: "")
    let recordButton = UIButton()
    var waveformImageView1 = UIImageView()
    var waveformImageView2 = UIImageView()
    var waveformImageView3 = UIImageView()
    
    private let usernameTextField = HSTextField(text: "Enter your name here")
    private let timeTextView = HSTimerView(time: "00:05")
    private let baseUrl = "<SERVER_URL"
    private let AUDIO_LEN_IN_SEC = 5
    private let SAMPLE_RATE = 16000
    private let extractor = SVFeatureExtractor()
//    private let networkManager = NetworkManager()
    
    public var username: String = ""
    private var recordYPadding: CGFloat = 0.0
    private var screenHeight = 0.0
    private var screenWidth = 0.0
    private var featureBuffer = [Float32]()
    private var encryptedStringFeature = ""
    private var encryptedStringResult = ""
    private var seconds: Double = 5.0
    private var timer = Timer()
    private var audioRecorder: AVAudioRecorder!
    private var audioFileUrl: URL!
    private var cancellables = Set<AnyCancellable>()
    

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(hexString: Colors.background.rawValue, alpha: 1) ?? .white
        navigationController?.navigationBar.prefersLargeTitles = false
        navigationController?.navigationBar.tintColor = UIColor(hexString: Colors.green.rawValue, alpha: 1) ?? .systemGreen
        navigationItem.title = "Speaker Verification"
        view.addSubviews(recordButton, timeTextView, waveformImageView1, waveformImageView2, waveformImageView3, usernameTextField, verifyButton, resetButton)
        
        configureRecordButton()
        configureTimeTextView()
        configureWaveformImageView()
        configureUsernameTextField()
        configureVerifyButton()
        configureResetButton()
        setupKeyboardHiding()
    }
    
    init(screenWidth: CGFloat = 0.0, screenHeight: CGFloat = 0.0) {
        super.init(nibName: nil, bundle: nil)
        self.screenHeight = screenHeight
        self.screenWidth = screenWidth
        self.recordYPadding = screenHeight / 4.9
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc func recordTapped(_ sender: UIButton) {
        AVAudioApplication.requestRecordPermission(completionHandler: { [weak self] (granted: Bool)-> Void in
            if granted {
                DispatchQueue.main.async {
                    self?.recordButton.isHidden = true
                    self?.startTimer()
                }
            } else{
                self?.presentHSAlert(title: "Record Permission", message: "Record permission needs to be granted", buttonLabel: "OK", titleLabelColor: .black)
            }
        })
        
        let audioSession = AVAudioSession.sharedInstance()
        
        do {
            try audioSession.setCategory(AVAudioSession.Category.record)
            try audioSession.setActive(true)
        } catch {
            self.presentHSAlert(title: "Record Error", message: "Recording error is encountered. Please try again!", buttonLabel: "OK", titleLabelColor: .black)
            return
        }

        let settings = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: SAMPLE_RATE,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsFloatKey: false,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ] as [String : Any]

        do {
            audioFileUrl = getDocumentsDirectory().appendingPathComponent("sv_user_audio.wav")
            audioRecorder = try AVAudioRecorder(url: audioFileUrl, settings: settings)
            audioRecorder.delegate = self
            audioRecorder.record(forDuration: TimeInterval(AUDIO_LEN_IN_SEC))
        } catch let error {
            self.presentHSAlert(title: "Record Error", message: "error: " + error.localizedDescription, buttonLabel: "OK", titleLabelColor: .black)
        }
    }
    
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if flag {
            verifyButton.isEnabled = true
            resetButton.isHidden = false
            waveformImageView1.isHidden = false
            waveformImageView2.isHidden = false
            waveformImageView3.isHidden = false
        } else {
            self.presentHSAlert(title: "Record Error", message: "Recording error is encountered. Please try again!", buttonLabel: "OK", titleLabelColor: .black)
        }
    }
    
        
    private func startTimer() {
        timer.invalidate()
        timeTextView.isHidden = false
        timer = Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(count), userInfo: nil, repeats: true)
    }
    
    @objc func count() {
        seconds -= 1
        timeTextView.text = seconds.toTimeString
        if timeTextView.text == "00:00" {
            seconds = 5.0
            timeTextView.text = seconds.toTimeString
            timer.invalidate()
            timeTextView.isHidden = true
        }
    }
    
    @objc func verifyTapped(_ sender: UIButton) {
        if (username.isEmpty) {
            let message = "Please press done after username is entered."
            self.presentHSAlert(title: "Empty Username", message: message, buttonLabel: "OK", titleLabelColor: .systemPink)
        } else {
            guard let rlwePkPath = Bundle.main.path(forResource: "rlwe_pk", ofType: "txt") else {
                fatalError("Can't find rlwe_pk.txt file!")
            }
            guard let rlweSkPath = Bundle.main.path(forResource: "rlwe_sk", ofType: "txt") else {
                fatalError("Can't find rlwe_sk.txt file!")
            }
            
            DispatchQueue.main.async() {
                self.verifyButton.isEnabled = false
                self.verifyButton.setTitle("VERIFYING...", for: .normal)
            }
            
            let file = try! AVAudioFile(forReading: audioFileUrl)
            let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: file.fileFormat.sampleRate, channels: 1, interleaved: false)
            let buf = AVAudioPCMBuffer(pcmFormat: format!, frameCapacity: AVAudioFrameCount(file.length))
            try! file.read(into: buf!)
            
            let floatArray = Array(UnsafeBufferPointer(start: buf?.floatChannelData![0], count:Int(buf!.frameLength)))
            featureBuffer = floatArray
            //            var roundedArray = floatArray.map{ $0 > 0 ? round($0 * 32767) : round($0 * 32768) }
            
            DispatchQueue.global().async {
                print("running feature extractor")
                let dateID = setDateFormat(as: "MM-dd-yyy_HH:mm:ss:SSS")
                let output = self.extractor.module.audioFeatureExtract(wavBuffer: self.featureBuffer, bufLength: Int32(self.AUDIO_LEN_IN_SEC * self.SAMPLE_RATE), filePath: rlwePkPath)
                let body = [
                    "id": dateID,
                    "name": self.username+"_audio",
                    "feature_vector": output ?? []
                ] as [String : Any]
                
                self.encryptedStringFeature = (output![0].map{ $0.stringValue }).joined(separator: ",")
                self.encryptedStringFeature += (output![1].map{ $0.stringValue }).joined(separator: ",")
                
                // ====================== POST REQUEST ======================
                var request = URLRequest(url: URL(string: self.baseUrl)!)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.httpBody = try? JSONSerialization.data(withJSONObject: body, options: .fragmentsAllowed)
                
                let task = URLSession.shared.dataTask(with: request) { data, _, error in
                    guard let data = data, error == nil else {
                        DispatchQueue.main.async() {
                            self.presentHSAlert(title: "Something Went Wrong", message: HSNetError.invalidResponse.rawValue, buttonLabel: "OK", titleLabelColor: .black)
                        }
                        return
                    }
                    
//                    do {
//                        _ = try JSONDecoder().decode(UserEncBio.self, from: data)
//                        print("POST SUCCESS")
//                    } catch {
//                        DispatchQueue.main.async() {
//                            self.presentHSAlert(title: "Something Went Wrong", message: HSNetError.invalidResponse.rawValue, buttonLabel: "OK", titleLabelColor: .black)
//                        }
//                    }
                    
                    // ====================== GET REQUEST ======================
                    let urlString = self.baseUrl + "/" + self.username + "_audio_" + dateID + ".json"
                    let url = URL(string: urlString)!
                    typealias DataTaskOutput = URLSession.DataTaskPublisher.Output
                    
                    let dataTaskPublisher = URLSession.shared.dataTaskPublisher(for: url)
                        .tryMap({ (dataTaskOutput: DataTaskOutput) -> Result<DataTaskOutput, Error> in
                            guard let httpResponse = dataTaskOutput.response as? HTTPURLResponse else {
                                return .failure(HSNetError.invalidResponse)
                            }
                            
                            if httpResponse.statusCode == 404 {
                                throw HSNetError.invalidData
                            }
                            
                            return .success(dataTaskOutput)
                        })
                    
                    dataTaskPublisher
                        .catch({ (error: Error) -> AnyPublisher<Result<URLSession.DataTaskPublisher.Output, Error>, Error> in
                            
                            switch error {
                            case HSNetError.invalidData:
                                print("Received a retryable error")
                                return Fail(error: error)
                                    .delay(for: 0.05, scheduler:  DispatchQueue.global())
                                    .eraseToAnyPublisher()
                            default:
                                print("Received a non-retryable error")
                                return Just(.failure(error))
                                    .setFailureType(to: Error.self)
                                    .eraseToAnyPublisher()
                            }
                        })
                            .retry(50)
                            .tryMap({ result in
                                let response = try result.get()
                                let json = try JSONDecoder().decode(UserEncResult.self, from: response.data)
                                return json
                            })
                                .sink(receiveCompletion:  { _ in
                                    DispatchQueue.main.async {
                                        self.verifyButton.setTitle("VERIFY", for: .normal)
                                        self.verifyButton.isEnabled = true
                                        print("end of verification...")
                                    }
                                }, receiveValue: { value in
                                    DispatchQueue.main.async() {
                                        print("value")
                                        let vector: [Int64] = value.result
                                        self.encryptedStringResult = vector.map{ String($0) }.joined(separator: ",")
                                        let matchResult = self.extractor.module.audioDecrypt(vector: vector.map { NSNumber(value: $0) }, fileAtPath: rlweSkPath)
                                        
                                        if (matchResult == "no") {
                                            let message = "Speaker is not a match with " + self.username + ". Please try again!"
                                            self.presentHSAlert(title: "Verification Failed", message: message, buttonLabel: "OK", titleLabelColor: .systemPink)
                                        } else {
                                            let message = "Speaker is a match with " + self.username + "!"
                                            self.presentHSAlert(title: "Verification Passed!", message: message, buttonLabel: "OK", titleLabelColor: .systemGreen)
                                        }
                                        
                                    }
                                })
                                    .store(in: &self.cancellables)
                                
                } //post request
                task.resume()
            }
        }
    }
    
    @objc func resetTapped(_ sender: UIButton) {
        waveformImageView1.isHidden = true
        waveformImageView2.isHidden = true
        waveformImageView3.isHidden = true
        resetButton.isHidden = true
        
        recordButton.isHidden = false
        verifyButton.isEnabled = false

        username = ""
        encryptedStringFeature = ""
        encryptedStringResult = ""
        usernameTextField.text = ""
        usernameTextField.placeholder = "Enter your name here"
    }

    
    
    private func configureRecordButton() {
        recordButton.addTarget(self, action: #selector(recordTapped), for: .touchUpInside)

        let recordConfig = UIImage.SymbolConfiguration(pointSize: 40)
        recordButton.configuration = .tinted()
        recordButton.configuration?.baseBackgroundColor = .clear
        recordButton.tintColor = UIColor(hexString: Colors.green.rawValue, alpha: 1) ?? .systemGreen
        recordButton.configuration?.image = UIImage(systemName: "mic", withConfiguration: recordConfig)
        
        recordButton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            recordButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            recordButton.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -recordYPadding)
        ])
    }
    
    private func configureTimeTextView() {
        timeTextView.textAlignment = .center
        timeTextView.textColor = UIColor(hexString: Colors.green.rawValue, alpha: 1) ?? .systemGreen
        timeTextView.backgroundColor = UIColor(hexString: Colors.background.rawValue, alpha: 1) ?? .white
        timeTextView.font = UIFont(name: "Menlo-Regular", size: 40)
        timeTextView.isHidden = true
        timeTextView.isEditable = false

        NSLayoutConstraint.activate([
            timeTextView.centerYAnchor.constraint(equalTo: view.centerYAnchor,constant: -recordYPadding),
            timeTextView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: self.screenWidth/4.3),
            timeTextView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -self.screenWidth/4.3),
            timeTextView.heightAnchor.constraint(equalToConstant: self.screenHeight/11.65) //80
        ])
    }

    private func configureWaveformImageView() {
        let waveformConfig = UIImage.SymbolConfiguration(pointSize: 50)
        waveformImageView1.image = UIImage(systemName: "waveform", withConfiguration: waveformConfig)
        waveformImageView1.tintColor = UIColor(hexString: Colors.green.rawValue, alpha: 1) ?? .systemGreen
        waveformImageView1.isHidden = true
        
        waveformImageView1.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            waveformImageView1.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            waveformImageView1.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -recordYPadding)
        ])
        
        waveformImageView2.image = UIImage(systemName: "waveform", withConfiguration: waveformConfig)
        waveformImageView2.tintColor = UIColor(hexString: Colors.green.rawValue, alpha: 1) ?? .systemGreen
        waveformImageView2.isHidden = true
        
        waveformImageView2.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            waveformImageView2.centerXAnchor.constraint(equalTo: view.centerXAnchor, constant: -50),
            waveformImageView2.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -recordYPadding)
        ])
        
        waveformImageView3.image = UIImage(systemName: "waveform", withConfiguration: waveformConfig)
        waveformImageView3.tintColor = UIColor(hexString: Colors.green.rawValue, alpha: 1) ?? .systemGreen
        waveformImageView3.isHidden = true
        
        waveformImageView3.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            waveformImageView3.centerXAnchor.constraint(equalTo: view.centerXAnchor, constant: 50),
            waveformImageView3.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -recordYPadding)
        ])
    }
    
    private func configureUsernameTextField() {
        usernameTextField.delegate = self
        usernameTextField.layer.masksToBounds = true
        usernameTextField.layer.cornerRadius = 26
        usernameTextField.layer.borderWidth = 1
        usernameTextField.backgroundColor = UIColor(hexString: Colors.green.rawValue, alpha: 0.3) ?? .lightGray
        usernameTextField.layer.borderColor = UIColor(hexString: Colors.background.rawValue, alpha: 1)?.cgColor
        
        NSLayoutConstraint.activate([
            usernameTextField.bottomAnchor.constraint(equalTo: view.centerYAnchor),
            usernameTextField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: self.screenWidth/8.6), //50
            usernameTextField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -self.screenWidth/8.6),
            usernameTextField.heightAnchor.constraint(equalToConstant: self.screenHeight/18.64) //50
        ])
    }
    
    private func configureResetButton() {
        resetButton.addTarget(self, action: #selector(resetTapped), for: .touchUpInside)
        resetButton.isHidden = true

        NSLayoutConstraint.activate([
            resetButton.topAnchor.constraint(equalTo: usernameTextField.bottomAnchor, constant: self.screenHeight/31.1), //30
            resetButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: self.screenWidth/4.3),
            resetButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -self.screenWidth/4.3),
            resetButton.heightAnchor.constraint(equalToConstant: self.screenHeight/18.64)
        ])
    }
    
    private func configureVerifyButton() {
        verifyButton.addTarget(self, action: #selector(verifyTapped), for: .touchUpInside)
        verifyButton.isEnabled = false

        NSLayoutConstraint.activate([
            verifyButton.topAnchor.constraint(equalTo: resetButton.bottomAnchor, constant: self.screenHeight/31.1),
            verifyButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: self.screenWidth/4.3),
            verifyButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -self.screenWidth/4.3),
            verifyButton.heightAnchor.constraint(equalToConstant: self.screenHeight/18.64)
        ])
    }
    
}
