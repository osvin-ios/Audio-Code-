//
//  RecordAudioView.swift
//  SunSoft
//
//  Created by osvinuser on 12/09/17.
//  Copyright © 2017 osvinusercom.osvin.com. All rights reserved.
//

import UIKit
import AVFoundation
import CoreAudioKit
import ObjectMapper

//MARK:- custom delegates
protocol RecordAudioViewDelegate {
    
    func reloadeTable()
}

class RecordAudioView: UIView,ShowAlert {
    
    //MARK:- Outlets
    @IBOutlet weak var gradientView: UIView!
    @IBOutlet weak var time_label: UILabel!
    @IBOutlet weak var startAndPlayObj: UIButton!
    @IBOutlet weak var tapToStartAudio_Label: UILabel!
    @IBOutlet weak var closeButton: UIButton!
    
    //MARK:- Variables
    var delegate: RecordAudioViewDelegate!
    var second:Int?
    var FromList:Bool = false
    var audioUrlOfList:URL?
    var durationOfAudio:Double = 0
    var durationValueee:Double = 0
    var recorder: AVAudioRecorder!
    var player:AVAudioPlayer!
    var meterTimer:Timer!
    var soundFileURL:URL!
    var  idCount: Int!
    var recordedSoundArray = [RecordingModelClass]()
    
    //MARK:- View Life cycle
    override init(frame: CGRect) {
        super.init(frame: frame)
        loadViewFromNib ()
    }
    
    required init?(coder aDecoder: NSCoder) {
        
        super.init(coder: aDecoder)
        loadViewFromNib ()
    }
    
    func loadViewFromNib() {
        let view = UINib(nibName: "RecordAudioView", bundle: Bundle(for: type(of: self))).instantiate(withOwner: self, options: nil)[0] as! UIView
        view.frame = bounds
        view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        self.addSubview(view)
        
        let gradientLayer: CAGradientLayer = CAGradientLayer()
        gradientLayer.frame = gradientView.bounds
        
        // for gradient colour
        let colorTop = UIColor(red: 240.0 / 255.0, green: 152.0 / 255.0, blue: 25.0 / 255.0, alpha: 1.0).cgColor
        let colorBottom = UIColor(red: 235.0 / 255.0, green: 222.0 / 255.0, blue: 43.0 / 255.0, alpha: 1.0).cgColor
        gradientLayer.colors = [colorTop, colorBottom]
        self.gradientView.layer.addSublayer(gradientLayer)
        print(audioUrlOfList ?? "")
    }
    
    //MARK:- Play audio from list
    func playAudioFromList() {
        
        // if there is any audio in the core audio list, it will play
        do {
            self.player = try AVAudioPlayer(contentsOf: audioUrlOfList!)
            player.delegate = self
            player.prepareToPlay()
            player.volume = 20.0
            player.play()
            self.startAndPlayObj.setTitle("Pause", for: .normal)
            self.tapToStartAudio_Label.isHidden = true
            self.meterTimer = Timer.scheduledTimer(timeInterval: 0.1,
                                                   target:self,
                                                   selector:#selector(self.updateAudioMeter(_:)),
                                                   userInfo:nil,
                                                   repeats:true)
            
        } catch {
            self.player = nil
            print(error.localizedDescription)
        }
    }
    
    // MARK: - IBActions
    @IBAction func startAction(_ sender: UIButton) {
        
        // if the buttons current title is pause
        if sender.currentTitle == "Pause" {
            
            if FromList == true {
                player?.stop()
                meterTimer.invalidate()
                meterTimer = nil
            } else {
                player.pause()

            }
            self.startAndPlayObj.setTitle("Resume", for: .normal)
            
        }else if sender.currentTitle == "Resume" {
            
            if FromList == true {
                player.play()
                self.meterTimer = Timer.scheduledTimer(timeInterval: 0.1,
                                                       target:self,
                                                       selector:#selector(self.updateAudioMeter(_:)),
                                                       userInfo:nil,
                                                       repeats:true)
            } else {
                player.play()
            }
            
            self.startAndPlayObj.setTitle("Pause", for: .normal)
            
        } else if sender.currentTitle == "Play again" {
            
            if FromList == true {
              self.playAudioFromList()
            }
        
        } else if sender.currentTitle == "Start" {
            
            self.startAndPlayObj.setTitle("Stop", for: .normal)
            self.recordAudio()
            print("start")
            
        } else if sender.currentTitle == "Stop" {
            if second! <= 3{
                let alertController = UIAlertController(title: Constants.appTitle.alertTitle, message: "Too early to stop", preferredStyle: .alert)
                alertController.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                UIApplication.shared.keyWindow?.rootViewController?.present(alertController, animated: true, completion: nil)
                
            }else {
                self.startAndPlayObj.setTitle("Play", for: .normal)
                self.stopRecording()
                self.insertRecordSoundIntoTable()
            }
            print("stop")
        } else if sender.currentTitle == "Play" {
            self.tapToStartAudio_Label.isHidden = true
            self.startAndPlayObj.setTitle("Play", for: .normal)
            self.startAndPlayObj.isEnabled = false
            self.startAndPlayObj.backgroundColor = UIColor.lightGray
            self.playRecording()
            print("play")
        }
    }
    
    // MARK:- Inserting data to CoreData Database
    internal func insertRecordSoundIntoTable() {
        
        // Get current user Data
        guard let userInfoModel = Methods.sharedInstance.getUserInfoData() else {
            return
        }
        
        let idValue = String(idCount)
        let userId = userInfoModel.id ?? "0"
        let fileName = soundFileURL.absoluteString.components(separatedBy: "Documents/")
        print(fileName[1])
        
        let param : [String : Any] = ["id": String(idValue) ?? "","recordingType": String("0") ?? "","fileName":fileName[1],"filePath":fileName[1],"ratingValue": String("0") ?? "","userId": "\(userId)"]
        print(param)
        QueriesClass.InstanceObject.insertDataIntoTable(tableName: Constants.TableName.prepareTowinTable, dict: param, success: { (isInsert) in
            guard isInsert == true else {
                return
            }
            print("successfully done")
        })  {(error) in
            print(error ?? "sorry")
        }
    }
    
    func stopRecording() {
        
        print("\(#function)")
        
        recorder?.stop()
        player?.stop()
        meterTimer.invalidate()
        
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setActive(false)
            
        } catch {
            print("could not make session inactive")
            print(error.localizedDescription)
        }
    }
        
    //MARK:- Custom Alert methods
    func  showAlertForSaveRecording(_message:String) {
        
        let alertController = UIAlertController(title: Constants.appTitle.alertTitle, message: _message, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "No", style: .default, handler: nil))
        alertController.addAction(UIAlertAction(title: "Yes", style: UIAlertActionStyle.default)
        { action -> Void in
            
            // Save audio
            self.insertRecordSoundIntoTable()
            self.delegate.reloadeTable()
            self.removeFromSuperview()
            
        })
        UIApplication.shared.keyWindow?.rootViewController?.present(alertController, animated: true, completion: nil)
    }
    
    @IBAction func closeAction(_ sender: Any) {
        print(startAndPlayObj.currentTitle ?? "")
        
        if startAndPlayObj.currentTitle == "Stop" {
            self.stopRecording()
            showAlertForSaveRecording(_message: "Do you want to save this recording?")
            
        }else  if  startAndPlayObj.currentTitle == "Pause" || startAndPlayObj.currentTitle == "Resume" {
                player.stop()
    
        } else if self.closeButton.currentTitle == "Close" {
            
            if (player != nil) {
                player.stop()
            } 
            
        } else {
            
           self.delegate.reloadeTable()
        }
        self.removeFromSuperview()
    }
    
 
    //MARK: - Audio and video recording methods
    //playing a track in player
    func playRecording() {
        
        var url:URL?
        if self.recorder != nil {
            url = self.recorder.url
        } else {
            url = self.soundFileURL!
        }
        print("playing \(String(describing: url))")
        
       // self.soundFileURL = url
        
        do {
            self.player = try AVAudioPlayer(contentsOf: url!)
           
            player.delegate = self
            player.prepareToPlay()
            player.volume = 20.0
            player.play()
        } catch {
            self.player = nil
            print(error.localizedDescription)
        }
    }
    
    // creating and writing the file to locally or send you the error
    func setupRecorder() {
        print("\(#function)")
        
        let format = DateFormatter()
        format.dateFormat="yyyy-MM-dd-HH-mm-ss"
        let currentFileName = "recording-\(format.string(from: Date()))"
        print(currentFileName)
        
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        self.soundFileURL = documentsDirectory.appendingPathComponent(currentFileName)
        print("writing to soundfile url: '\(soundFileURL!)'")
        
        if FileManager.default.fileExists(atPath: soundFileURL.absoluteString) {
            // probably won't happen. want to do something about it?
            print("soundfile \(soundFileURL.absoluteString) exists")
        }
        
        let recordSettings:[String : Any] = [
            AVFormatIDKey:             kAudioFormatAppleIMA4,
            AVEncoderAudioQualityKey: AVAudioQuality.max.rawValue,
            AVEncoderBitRateKey :      32000,
            AVNumberOfChannelsKey:     2,
            AVSampleRateKey :          44100.0
        ]
        
        do {
            recorder = try AVAudioRecorder(url: soundFileURL, settings: recordSettings)
            recorder.delegate = self
            recorder.isMeteringEnabled = true
            recorder.prepareToRecord() // creates/overwrites the file at soundFileURL
        } catch {
            recorder = nil
            print(error.localizedDescription)
        }
    }
    
    // setting the session for the playback
    func setSessionPlayback() {
        print("\(#function)")
        let session = AVAudioSession.sharedInstance()
        
        do {
            try session.setCategory(AVAudioSessionCategoryPlayback, with: .defaultToSpeaker)
            
        } catch {
            print("could not set session category")
            print(error.localizedDescription)
        }
        
        do {
            try session.setActive(true)
        } catch {
            print("could not make session active")
            print(error.localizedDescription)
        }
    }
    
    // set permission for recording file
    func recordWithPermission(_ setup:Bool) {
        print("\(#function)")
        
        AVAudioSession.sharedInstance().requestRecordPermission() {
            [unowned self] granted in
            if granted {
                
                DispatchQueue.main.async {
                    print("Permission to record granted")
                    self.setSessionPlayAndRecord()
                    if setup {
                        self.setupRecorder()
                    }
                    
                    self.recorder.record()
                    
                    self.meterTimer = Timer.scheduledTimer(timeInterval: 0.1,
                                                           target:self,
                                                           selector:#selector(self.updateAudioMeter(_:)),
                                                           userInfo:nil,
                                                           repeats:true)
                }
            } else {
                print("Permission to record not granted")
            }
        }
        
        if AVAudioSession.sharedInstance().recordPermission() == .denied {
            print("permission denied")
        }
    }
    
    // recording audio method
    func recordAudio() {
        
        if player != nil && player.isPlaying {
            print("stopping")
            player.stop()
        }
        
        if recorder == nil {
            recordWithPermission(true)
            return
        } else {
            print("recording")
             recordWithPermission(false)
        }
    }
    
    //creating session of the audio and video file
    func setSessionPlayAndRecord() {
        print("\(#function)")
        
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(AVAudioSessionCategoryPlayAndRecord, with: .defaultToSpeaker)
        } catch {
            
            print("could not set session category")
            print(error.localizedDescription)
            
        }
        
        do {
            try session.setActive(true)
        } catch {
            print("could not make session active")
            print(error.localizedDescription)
        }
    }
    //updating audio view components
    func updateAudioMeter(_ timer:Timer) {
        if FromList {
            self.durationValueee += 0.1
            let min = Int(durationValueee / 60)
            let sec = Int(durationValueee.truncatingRemainder(dividingBy: 60))
            let s = String(format: "%02dM %02dS", min, sec)
            
            let attributedString = NSMutableAttributedString(string: s)
            if let font = UIFont(name: "SourceSansPro-ExtraLight", size: 50) {
                attributedString.addAttribute(NSFontAttributeName, value: font, range: NSRange(location:0, length: s.characters.count))
            }
            
            let highlightedWords = ["M", "S"]
            for highlightedWord in highlightedWords {
                let textRange = (s as NSString).range(of: highlightedWord)
                
                if let font = UIFont(name: "SourceSansPro-ExtraLight", size: 15) {
                    attributedString.addAttribute(NSFontAttributeName, value: font, range: textRange)
                }
            }
            time_label.attributedText = attributedString
            
        } else {
            if let recorder = self.recorder {
                if recorder.isRecording {
                    let min = Int(recorder.currentTime / 60)
                    let sec = Int(recorder.currentTime.truncatingRemainder(dividingBy: 60))
                    let s = String(format: "%02dM %02dS", min, sec)
                    
                    let attributedString = NSMutableAttributedString(string: s)
                    if let font = UIFont(name: "SourceSansPro-ExtraLight", size: 50) {
                        attributedString.addAttribute(NSFontAttributeName, value: font, range: NSRange(location:0, length: s.characters.count))
                    }
                    
                    let highlightedWords = ["M", "S"]
                    for highlightedWord in highlightedWords {
                        let textRange = (s as NSString).range(of: highlightedWord)
                        
                        if let font = UIFont(name: "SourceSansPro-ExtraLight", size: 15) {
                            attributedString.addAttribute(NSFontAttributeName, value: font, range: textRange)
                        }
                    }
                    
                    time_label.attributedText = attributedString
                    second = sec
                    recorder.updateMeters()
                    
                    if sec <= 5 {
                        // print("Not less then 5 ")
                        // showAlertForSaveRecording(_message: )
                        // stopRecording()
                    }
                }
            }
        }
    }
    
    // Get Duration of the file
    func duration(for resource: String) -> Double {
        let asset = AVURLAsset(url: URL(fileURLWithPath: resource))
        return Double(CMTimeGetSeconds(asset.duration))
    }
    
}
//ALERT CLASS
class alert {
    func msg(message: String, title: String = "")
    {
        let alertView = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alertView.addAction(UIAlertAction(title: "Done", style: .default, handler: nil))
        UIApplication.shared.keyWindow?.rootViewController?.present(alertView, animated: true, completion: nil)
    }
}

//MARK: AVAudioRecorder Delegate Methods
extension RecordAudioView : AVAudioRecorderDelegate {
    // success method the audio play
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        
    }
    // error handle during audio decode
    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        print("\(#function)")
        
        if let e = error {
            print("\(e.localizedDescription)")
        }
    }
}

// MARK: AVAudioPlayer Delegate Methods
extension RecordAudioView : AVAudioPlayerDelegate {
    //success method the video play
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        print("\(#function)")
        startAndPlayObj.isEnabled = true
        startAndPlayObj.backgroundColor = UIColor(red: 56.0 / 255.0, green: 186.0 / 255.0, blue: 195.0 / 255.0, alpha: 1.0)
        if FromList == true{
            self.meterTimer.invalidate()
            self.meterTimer = nil
            self.durationValueee = 0
                    
            startAndPlayObj.setTitle("Play again", for: .normal)
        }
    }
    
    // error handle during video decode
    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        print("\(#function)")
        
        if let e = error {
            print("\(e.localizedDescription)")
        }
    }
}

