//
//  MapLocation.swift
//  VirtualTourist
//
//  Created by Dwayne George on 9/7/15.
//  Copyright (c) 2015 Dwayne George. All rights reserved.
//

import Foundation
import CoreData

@objc(MapLocation)

class MapLocation: NSManagedObject {
    
    @NSManaged var longitude: NSNumber
    @NSManaged var latitude: NSNumber
    @NSManaged var longitudeDelta: NSNumber
    @NSManaged var latitudeDelta: NSNumber

}
