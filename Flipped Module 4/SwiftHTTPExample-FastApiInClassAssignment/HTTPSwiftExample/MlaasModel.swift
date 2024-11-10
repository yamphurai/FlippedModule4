//
//  MlaasModel.swift
//  HTTPSwiftExample
//
//  Created by Eric Cooper Larson on 6/5/24.
//  Copyright © 2024 Eric Larson. All rights reserved.
//




/// This model uses delegation to interact with the main controller. The two functions below are for notifying the user that an update was completed successfully on the server. They must be implemented.
protocol ClientDelegate{
    func updateDsid(_ newDsid:Int)          // method to update the DSID
    func receivedPrediction(_ prediction:[String:Any])  // method to receive the prediction data.
}


// enum with four cases representing different HTTP methods (GET, PUT, POST, and DELETE)
enum RequestEnum:String {
    case get = "GET"
    case put = "PUT"
    case post = "POST"
    case delete = "DELETE"
}

import UIKit


// class to handle HTTP requests and manages the connection to a server.
class MlaasModel: NSObject, URLSessionDelegate{
    
    //MARK: Properties and Delegation
    private let operationQueue = OperationQueue()  //used to manage tasks
    
    // default ip, if you are unsure try: ifconfig |grep "inet " to see what your public facing IP address is
    var server_ip = "10.9.166.123" //default ip
    
    // create a delegate for using the protocol i.e. to communicate with the view controller
    var delegate:ClientDelegate?
    
    private var dsid:Int = 5  //private variable to store the DSID
    
    // public access methods
    
    // updates the DSID value
    func updateDsid(_ newDsid:Int){
        dsid = newDsid
    }
    
    //returns current DSID value
    func getDsid()->(Int){
        return dsid
    }
    
    // a URL session with custom configs to handle requests with a timeout and max number of connections
    lazy var session = {
        let sessionConfig = URLSessionConfiguration.ephemeral
        
        sessionConfig.timeoutIntervalForRequest = 5.0  //timeout for request
        sessionConfig.timeoutIntervalForResource = 8.0  //timeout for resource
        sessionConfig.httpMaximumConnectionsPerHost = 1  //max number of connections per host
        
        // initiate a temporary URS session with above configs. View controller is the delegate
        let tmp = URLSession(configuration: sessionConfig,
            delegate: self,
            delegateQueue:self.operationQueue)
        
        return tmp
        
    }()
    
    
    
    //MARK: Setters and Getters
    
    //check if the provided IP is valied and set it as the server IP
    func setServerIp(ip:String)->(Bool){
        
        // user is trying to set ip: make sure that it is valid ip address
        if matchIp(for:"((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)(\\.|$)){4}", in: ip){
            server_ip = ip
            return true  // return success
        }else{
            return false
        }
    }
    
    
    //MARK: Main Functions
    
    //to send data (array represents features to be sent to the server, label is the label of the associated data)
    func sendData(_ array:[Double], withLabel label:String){
        
        let baseURL = "http://\(server_ip):8000/labeled_data/"  //construct base URL for the request using "server_ip" property
        let postUrl = URL(string: "\(baseURL)")  //create a URL object from the baseURL string to specify the destination of the POST request.
        
        var request = URLRequest(url: postUrl!)  // create a custom HTTP POST request
        
        // create request body by serializing the data into JSON format. Pass features, labels of the data, and data identifier as keys.
        let requestBody:Data = try! JSONSerialization.data(withJSONObject: ["feature":array,
            "label":"\(label)",
            "dsid":self.dsid])
        
        
        // The Type of the request is given here
        request.httpMethod = "POST"   //set the HTTP method to POST, indicating that data will be sent to the server.
        
        //set the header of the request informing server that the body of request contains JSON data
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = requestBody  //sets the HTTP body of the request to the requestBody(contains serialized JSON data)
        
        //create the URL session data task that sends the HTTP request created above
        // the completion handler receives returned data, response data from server and any error encountered during the request
        let postTask : URLSessionDataTask = self.session.dataTask(with: request, completionHandler:{(data, response, error) in
            
            // if error occurs during the request, print this error statement
            if(error != nil){
                if let res = response{
                    print("Response:\n",res)
                }
            }
            else{
                let jsonDictionary = self.convertDataToDictionary(with: data)  //if no error: response data is passed to convert it into a dict
                
                //print features & labels keys of the dict. Values should match the data sent to the server
                print(jsonDictionary["feature"]!)
                print(jsonDictionary["label"]!)
            }
        })
        postTask.resume() // start the data task initiaing the HTTP request
    }
    
    
    
    // post data (containing JSON object: features & dsid) without a label. If request completes, process response data & send it to the delegate
    func sendData(_ array:[Double]){
        
        let baseURL = "http://\(server_ip):8000/predict_turi/"  //construct base URL for the request
        let postUrl = URL(string: "\(baseURL)")  //create URL object from base URL for HTTP post request
        
        var request = URLRequest(url: postUrl!)  // create a custom HTTP POST request to configure the HTTP request
        
        // create request body (JSON object with features and dsid as keys)
        let requestBody:Data = try! JSONSerialization.data(withJSONObject: ["feature":array,
            "dsid":self.dsid])
        
        request.httpMethod = "POST"  //indicates that data is being sent to the server
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")  //tells server that body of the request is in JSON format
        request.httpBody = requestBody  //assign the serialized request body as the body of the HTTP request
        
        //create the URL session data task that sends the HTTP request created above
        // the completion handler receives returned data, response object from server and any error encountered during the request
        let postTask : URLSessionDataTask = self.session.dataTask(with: request, completionHandler:{(data, response, error) in
            
            // if error occurs during the request, print this error statement
            if(error != nil){
                print("Error from server")
                if let res = response{
                    print("Response:\n",res)
                }
            }
            else{
                
                //check if delegate property is set to self
                if let delegate = self.delegate {
                    let jsonDictionary = self.convertDataToDictionary(with: data)  //received data from server is passed to convert raw response data into a dict
                    delegate.receivedPrediction(jsonDictionary) //pass the parsed JSON dict
                }
            }
        })
        postTask.resume() // start the task sending the request asynchronously to the server
    }
    
    
    // get and store a new DSID. Update the UI with new DSID
    func getNewDsid(){
        let baseURL = "http://\(server_ip):8000/max_dsid/"  //construct base URL
        let postUrl = URL(string: "\(baseURL)")  //create URL object from base URL
        var request = URLRequest(url: postUrl!)  // create a custom HTTP POST request to configure and sent HTTP request
        
        request.httpMethod = "GET"  //set HTTP method to GET (requesting data from server)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")  //tell the server that the client expects and will send data in JSON format.
        
        //create URL session data task that will perform the HTTP request asynchronously.
        let getTask : URLSessionDataTask = self.session.dataTask(with: request, completionHandler:{(data, response, error) in
            
            let jsonDictionary = self.convertDataToDictionary(with: data)  //convert raw data returned from server into a dict
             
            // check if the delegate has been set to the view controller
            if let delegate = self.delegate,
                
                //check if response from the server exists and the dict containts a vlid dsid field of type Int
                let resp=response,
                let dsid = jsonDictionary["dsid"] as? Int {
                
                // tell delegate to update interface for the Dsid
                self.dsid = dsid+1  //increase dsid value by 1 which represents new dsid
                delegate.updateDsid(self.dsid)  //update UI with new dsid
                
                print(resp)  //print response object for debugging purpose
            }

        })
        getTask.resume() // start the task to send the HTTP GET request to the server
        
    }
    
    
    // to send a GET request to the server to trigger the training of a model on the server-side identifed by DSID and retrieve a summary of the process
    func trainModel(){
        let baseURL = "http://\(server_ip):8000/train_model_turi/\(dsid)"
        let postUrl = URL(string: "\(baseURL)")
        var request = URLRequest(url: postUrl!)
        
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let getTask : URLSessionDataTask = self.session.dataTask(with: request, completionHandler:{(data, response, error) in
            let jsonDictionary = self.convertDataToDictionary(with: data)  //convert raw data from the server into a dict

            //check if the dict has key "summary" & value as string
            if let summary = jsonDictionary["summary"] as? String {
                print(summary)  //print the summary of the model training process on the console
            }

        })
        getTask.resume() // start the task to send the GET request to the server
        
    }
    
    
    //MARK: Utility Functions
    
    //check if a given text matches a pattern specified by the regex string.
    private func matchIp(for regex:String, in text:String)->(Bool){
        do {
            let regex = try NSRegularExpression(pattern: regex)  //create NSRegularExpression object
            let results = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))  //find matches of the regular expression in the given text
            if results.count > 0{return true}  //if any match found return true
            
        } catch _{
            return false  //no valid match was found due to error in processing
        }
        return false //not match was found in the text
    }
    
    
    // to convert raw JSON data into a dict
    private func convertDataToDictionary(with data:Data?)->[String:Any]{
        
        
        do {
            
            // deserialize the data object into a JSON object
            let jsonDictionary: [String:Any] =
                try JSONSerialization.jsonObject(with: data!, options: JSONSerialization.ReadingOptions.mutableContainers) as! [String : Any]
            return jsonDictionary //returned the parsed dict (JSON)
            
        } catch {
            print("json error: \(error.localizedDescription)")  //details if parsing fail
            
            // convert raw data into human readable format for debugging purpose
            if let strData = String(data:data!, encoding:String.Encoding(rawValue: String.Encoding.utf8.rawValue)){
                print("printing JSON received as string: "+strData)
            }
            return [String:Any]() // if error occurs, just return empty dict
        }
    }

}

