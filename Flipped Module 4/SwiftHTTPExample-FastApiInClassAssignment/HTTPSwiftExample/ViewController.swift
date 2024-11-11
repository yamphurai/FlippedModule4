//  Created by Eric Larson on 3/30/15.
//  Copyright (c) 2015 Eric Larson. All rights reserved.
//  Updated 2024

// This example is meant to be run with the python example:
//              fastapi_turicreate.py
//              from the course GitHub repository


import UIKit
import CoreMotion

class ViewController: UIViewController, ClientDelegate, UITextFieldDelegate {
    
    // MARK: Class Properties
    
    // interacting with server
    let client = MlaasModel()
    
    // operation queues
    let motionOperationQueue = OperationQueue()      //handling motion updates
    let calibrationOperationQueue = OperationQueue()  //handling calibration tasks
    
    // motion data properties
    var ringBuffer = RingBuffer()
    let motion = CMMotionManager()
    var magThreshold = 0.1
    
    // state variables
    var isCalibrating = false   //track calibration status
    var isWaitingForMotionData = false   //indicate if app is ready to process motion data
    
    // User Interface properties
    let animation = CATransition()
    @IBOutlet weak var dsidLabel: UILabel!
    @IBOutlet weak var upArrow: UILabel!
    @IBOutlet weak var rightArrow: UILabel!
    @IBOutlet weak var downArrow: UILabel!
    @IBOutlet weak var leftArrow: UILabel!
    @IBOutlet weak var largeMotionMagnitude: UIProgressView!
    
    //Part 2
    @IBOutlet weak var ipAddressTextField: UITextField! // Add an IBOutlet for the text field
    
    // MARK: Class Properties with Observers
    
    //enumeration with different stages of calibration
    enum CalibrationStage:String {
        case notCalibrating = "notCalibrating"
        case up = "up"
        case right = "right"
        case down = "down"
        case left = "left"
    }
    
    //call the method for setting the interface for clibration stage if notClibrating changes
    var calibrationStage:CalibrationStage = .notCalibrating {
        didSet{
            self.setInterfaceForCalibrationStage()
        }
    }
     
    //updates magThreshold when a slider's value changes.
    @IBAction func magnitudeChanged(_ sender: UISlider) {
        self.magThreshold = Double(sender.value)
    }
    
    
    //Part 2: update the default IP address with one that the user enters
    @IBAction func ipAddressTextFieldEditingDidEnd(_ sender: UITextField) {
        
        //if the new IP is the one that the user enters (checks if not empty)
        if let newIp = sender.text, !newIp.isEmpty {
            
            //update the IP with the user entered IP
            if client.setServerIp(ip: newIp) {
                        print("IP address updated successfully.")
                    } else {
                        print("Invalid IP address provided.")
                    }
                }
    }
    
    
    //Part 2: UITextFieldDelegate method to dismiss the keyboard when the user hits enter
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
    
    
    // MARK: View Controller Life Cycle
    override func viewDidLoad() {
        super.viewDidLoad()

        // create reusable animation
        animation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeInEaseOut)
        animation.type = CATransitionType.fade
        animation.duration = 0.5
        
        // setup core motion handlers to start motion updates
        startMotionUpdates()
        
        // use delegation for interacting with client
        client.delegate = self
        client.updateDsid(5) // set default dsid to start with
        
        //Part 2
        ipAddressTextField.delegate = self   // Set the view controller as the delegate for the text field
        
        // Add a toolbar with a done button to dismiss the number pad
        let toolbar = UIToolbar()
        toolbar.sizeToFit()
        
        let doneButton = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(doneButtonTapped))
        toolbar.setItems([doneButton], animated: false)
                
        ipAddressTextField.inputAccessoryView = toolbar
    }
    
    
    //MARK: UI Buttons
    
    //to get new dataset ID from the server
    @IBAction func getDataSetId(_ sender: AnyObject) {
        client.getNewDsid() // protocol used to update dsid
    }
    
    //start the calibration process
    @IBAction func startCalibration(_ sender: AnyObject) {
        self.isWaitingForMotionData = false // dont do anything yet
        nextCalibrationStage() // kick off the calibration stages
        
    }
    
    //tell the client to train the model
    @IBAction func makeModel(_ sender: AnyObject) {
        client.trainModel()
    }
    
    //Part 2
    @objc func doneButtonTapped() {
        view.endEditing(true)
    }
    


}

//MARK: Protocol Required Functions
extension ViewController {
    
    //update the dsid label on the main thread
    func updateDsid(_ newDsid:Int){
        
        // delegate function completion handler
        DispatchQueue.main.async{
            self.dsidLabel.layer.add(self.animation, forKey: nil)  //update the label with animation
            self.dsidLabel.text = "Current DSID: \(newDsid)"   //update the label to current dsid
        }
    }
    
    
    //handle the received prediction from the server
    func receivedPrediction(_ prediction:[String:Any]){
        
        //if the response has the prediction
        if let labelResponse = prediction["prediction"] as? String{
            print(labelResponse)
            self.displayLabelResponse(labelResponse)
        }
        else{
            print("Received prediction data without label.")
        }
    }
}


//MARK: Motion Extension Functions
extension ViewController {
    
    // Core Motion Updates
    func startMotionUpdates(){
        
        //if device motion is available
        if self.motion.isDeviceMotionAvailable{
            self.motion.deviceMotionUpdateInterval = 1.0/200  //setting the update interval
            self.motion.startDeviceMotionUpdates(to: motionOperationQueue, withHandler: self.handleMotion )  //specify the handler metho
        }
    }
    
    
    //handle the motion updates from the device
    func handleMotion(_ motionData:CMDeviceMotion?, error:Error?){
        
        //if motion is available, get the accelarations in x,y,z axes (excluding gravity) caused by user's movement
        if let accel = motionData?.userAcceleration {
            self.ringBuffer.addNewData(xData: accel.x, yData: accel.y, zData: accel.z)  //store new accleration data to the buffer for recent motion update
            let mag = fabs(accel.x)+fabs(accel.y)+fabs(accel.z)  //compute mag of acceleration vector
            
            //update the UI on main thread showing current accelaration mag
            DispatchQueue.main.async{
                self.largeMotionMagnitude.progress = Float(mag)/0.2  //divided by 2 to normalize the mg for display purpose
            }
            
            //if the computed mag > threshold
            if mag > self.magThreshold {
                
                //to buffer more motion data using 0.05s delay before processing the event
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05, execute: {
                    self.calibrationOperationQueue.addOperation {
                        self.largeMotionEventOccurred()  // indicate that significant motion event has occured & further processing can be done
                    }
                })
            }
        }
    }
    
    
    // significant motion event has occurred and needs to be processed so send to server
    func largeMotionEventOccurred(){
        
        //if the system if in calibration mode
        if(self.isCalibrating){
            
            //if the system is actively calibrating & ready to process new motion data
            if(self.calibrationStage != .notCalibrating && self.isWaitingForMotionData)
            {
                self.isWaitingForMotionData = false  //system is no longer waiting for new motion data
                
                // send buffered motion data to the server with label indicating the current calibration stage
                self.client.sendData(self.ringBuffer.getDataAsVector(), withLabel: self.calibrationStage.rawValue)
                
                self.nextCalibrationStage()  //go to next clibration process
            }
        }
        
        //if the system is not in calibration mode
        else
        {
            //check if the system is waiting for motion data
            if(self.isWaitingForMotionData)
            {
                self.isWaitingForMotionData = false  //indicate that the system no longer is waiting for new motion data
                self.client.sendData(self.ringBuffer.getDataAsVector())  //send buffered motion data to server without label for predicting label based on received data
                setDelayedWaitingToTrue(2.0)  //preventing immediate subsequent predictions and allowing a cooldown period.
            }
        }
    }
}

//MARK: Calibration UI Functions
extension ViewController {
    
    //delay time: tell the system is ready to wait for motion data after the delay
    func setDelayedWaitingToTrue(_ time:Double){
        DispatchQueue.main.asyncAfter(deadline: .now() + time, execute: {
            self.isWaitingForMotionData = true
        })
    }
    
    
    //label update for calibration state
    func setAsCalibrating(_ label: UILabel){
        label.layer.add(animation, forKey:nil)
        label.backgroundColor = UIColor.red
    }
    
    
    // set the label background for normal state
    func setAsNormal(_ label: UILabel){
        label.layer.add(animation, forKey:nil)
        label.backgroundColor = UIColor.white
    }
    
    // bliking effect of UIlabel, set label background to red, delay of 1s, reset label background to white for blinking effect
    func blinkLabel(_ label:UILabel){
        DispatchQueue.main.async {
            self.setAsCalibrating(label)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: {
                self.setAsNormal(label)
            })
        }
    }
    
    
    //make the corresponding arrow blink based on direction indicated by the response
    func displayLabelResponse(_ response:String){
        switch response {
        case "['up']","up":
            blinkLabel(upArrow)  //make up arrow label blink
            break
        case "['down']","down":
            blinkLabel(downArrow)  //make down arrow label blink
            break
        case "['left']","left":
            blinkLabel(leftArrow)  //make left arrow label blink
            break
        case "['right']","right":
            blinkLabel(rightArrow)  //make right arrow label blink
            break
        default:
            print("Unknown")
            break
        }
    }
    
    
    //update the UI based on current calibration stage by adjusting the appearance of arrow labels
    func setInterfaceForCalibrationStage(){
        
        //handle various cases based on the value of the calibration stage
        switch calibrationStage {
        
        //if the calibration stage is up
        case .up:
            self.isCalibrating = true  //calibrating state is true
            DispatchQueue.main.async{
                self.setAsCalibrating(self.upArrow)  //indcate the up calibration stage
                self.setAsNormal(self.rightArrow)  //indicate that right arrow is not currently being calibrated
                self.setAsNormal(self.leftArrow)   //indicate that left arrow is not currently being calibrated
                self.setAsNormal(self.downArrow)   //indicate that down arrow is not currently being calibrated
            }
            break
        case .left:
            self.isCalibrating = true
            DispatchQueue.main.async{
                self.setAsNormal(self.upArrow)
                self.setAsNormal(self.rightArrow)
                self.setAsCalibrating(self.leftArrow)
                self.setAsNormal(self.downArrow)
            }
            break
        case .down:
            self.isCalibrating = true
            DispatchQueue.main.async{
                self.setAsNormal(self.upArrow)
                self.setAsNormal(self.rightArrow)
                self.setAsNormal(self.leftArrow)
                self.setAsCalibrating(self.downArrow)
            }
            break
            
        case .right:
            self.isCalibrating = true
            DispatchQueue.main.async{
                self.setAsNormal(self.upArrow)
                self.setAsCalibrating(self.rightArrow)
                self.setAsNormal(self.leftArrow)
                self.setAsNormal(self.downArrow)
            }
            break
        case .notCalibrating:
            self.isCalibrating = false
            DispatchQueue.main.async{
                self.setAsNormal(self.upArrow)
                self.setAsNormal(self.rightArrow)
                self.setAsNormal(self.leftArrow)
                self.setAsNormal(self.downArrow)
            }
            break
        }
    }
    
    
    //udpate the calibration state to show progress through different stages of calibration
    func nextCalibrationStage(){
        switch self.calibrationStage {
        
        //if not calibrating
        case .notCalibrating:
            self.calibrationStage = .up  //state that calibration should start with up arrow
            setDelayedWaitingToTrue(1.0)  //delay the next calibration step by 1s
            break
        case .up:
            //go to right arrow
            self.calibrationStage = .right
            setDelayedWaitingToTrue(1.0)
            break
        case .right:
            //go to down arrow
            self.calibrationStage = .down
            setDelayedWaitingToTrue(1.0)
            break
        case .down:
            //go to left arrow
            self.calibrationStage = .left
            setDelayedWaitingToTrue(1.0)
            break
            
        case .left:
            self.calibrationStage = .notCalibrating  //calibration process is complete
            setDelayedWaitingToTrue(1.0)
            break
        }
    }

}


