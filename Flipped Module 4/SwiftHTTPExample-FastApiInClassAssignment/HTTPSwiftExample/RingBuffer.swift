//
//  RingBuffer.swift
//  HTTPSwiftExample
//
//  Created by Eric Larson on 10/27/17.
//  Copyright © 2017 Eric Larson. All rights reserved.
//

import UIKit

let BUFFER_SIZE = 50  //the size of the circular buffer for storing data.


//implement a ring (or circular) buffer structure that stores data in arrays.
class RingBuffer: NSObject {
    
    //arrays to hold the data points for the x,y and z axes for the buffer (initially 0)
    var x = [Double](repeating:0, count:BUFFER_SIZE)
    var y = [Double](repeating:0, count:BUFFER_SIZE)
    var z = [Double](repeating:0, count:BUFFER_SIZE)
    
    // used to keep track of the current position where the next data will be inserted into the buffer.
    var head:Int = 0 {
        
        // monitor changes to head
        didSet{
            
            //if head exceeds the buffer size, reset it to 0 to overwrite the old data once it reaches its capacity
            if(head >= BUFFER_SIZE){
                head = 0
            }
        }
    }
    
    //add new x,y and z data to the buffer
    func addNewData(xData:Double,yData:Double,zData:Double){
        x[head] = xData
        y[head] = yData
        z[head] = zData
        
        head += 1 //move the point to the next position
    }
    
    //return all data in the buffer as a single array (x, y and z points arranged in a sequence)
    func getDataAsVector()->[Double]{
        var allVals = [Double](repeating:0, count:3*BUFFER_SIZE)  //hold all x, y & z values. Total is 3 times buffer size since we have x, y and z
        
        // iterate over each beach position in the buffer
        for i in 0..<BUFFER_SIZE {
            let idx = (head+i)%BUFFER_SIZE  //ensure that buffer behaves cicrularly
            
            // The x, y, and z values from the respective arrays are placed into the allVals array, sequentially for each data point
            allVals[3*i] = x[idx]
            allVals[3*i+1] = y[idx]
            allVals[3*i+2] = z[idx]
        }
        return allVals  //return combined array
    }

}
