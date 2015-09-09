//
//  Pin.swift
//  
//
//  Created by Dwayne George on 8/25/15.
//
//

import Foundation
import CoreData

@objc(Pin)

class Pin: NSManagedObject {
    
    @NSManaged var pinLat: NSNumber
    @NSManaged var pinLon: NSNumber
    @NSManaged var photos: NSSet

}
