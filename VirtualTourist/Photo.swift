//
//  Photo.swift
//  
//
//  Created by Dwayne George on 8/25/15.
//
//

import Foundation
import CoreData

@objc(Photo)

class Photo: NSManagedObject {
    
    @NSManaged var url: String
    @NSManaged var filePath: String?
    @NSManaged var mapPin: Pin

}
