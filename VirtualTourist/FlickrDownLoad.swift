//
//  FlickrDownLoad.swift
//  VirtualTourist
//
//  Created by Dwayne George on 8/14/15.
//  Copyright (c) 2015 Dwayne George. All rights reserved.
//

import UIKit
import MapKit
import CoreData

class FlickrDownLoad {
    
    var downloadLimit: Int //set max number of photos to download per page
    var curPageNum: Int //track current page for pin
    var totalPages: Int //track total pages for pin
    
    init()
    {
        curPageNum = 1
        totalPages = 1
        downloadLimit = 21
    }
    
    //fetch photo image using URL stored in core data
    func getImageFromURL (url: String, context: NSManagedObjectContext?, photoObj: Photo, completionHandler: (success: Bool, retError: NSError?) -> Void) {
        
        //get document directory
        let documents = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true)[0] as! String
        var error: NSError?
        
        let nsurl = NSURL(string: url)
        let request = NSURLRequest(URL: nsurl!)
        let flickrSession = NSURLSession.sharedSession()
        
        let task = flickrSession.dataTaskWithRequest(request) {data, response, Error in
            if  Error == nil {
                if let image = UIImage(data: data!) {
                    //save image to document directory
                    //extract file name from URL and append to filepath
                    let filePath = documents.stringByAppendingPathComponent(url.lastPathComponent)
                    
                    var ferror: NSError?
                    //save the image
                    UIImageJPEGRepresentation(image, 0.5).writeToFile(filePath, options: NSDataWritingOptions.DataWritingAtomic, error: &ferror)
                    if error != nil {
                        //and error occurred while writing the file
                        completionHandler(success: false,  retError: Error)
                        return
                    }
                    
                    //update core data with file path to new image
                    photoObj.filePath = filePath //set file path
                    if !(context?.save(&ferror) != nil) {
                        //error occurred while updating core data
                        completionHandler(success: false,  retError: Error)
                        return
                    }
                    
                    dispatch_async(dispatch_get_main_queue()) {
                        completionHandler(success: true, retError: Error)
                    }
                }
            } else {
                println(Error.description)
                println(Error.userInfo)
                println(url)
                completionHandler(success: false, retError: Error)
            }
        }
        task.resume()
    }
    
    //fetch all photos for provided pin and store in document memory.  update core data
    func saveURLForImagesOfPin (coor: CLLocationCoordinate2D, nextPage: Bool, context: NSManagedObjectContext?, completionHandler: (success: Bool, numFound:
        Int, retError: NSError?) -> Void) {
            
            //manage paging
            if nextPage {
                curPageNum++
                if curPageNum > totalPages {
                    curPageNum = 1
                }
            }
            
            var countPhotos: Int = 0  //track number of urls downloaded to limit pictures
            
            //create session
            let flickrSession = NSURLSession.sharedSession()
            var strURL = "https://api.flickr.com/services/rest/?method=flickr.photos.search"
            strURL = strURL + "&api_key=8a4995630c3096b7fe65f466118388f5"
            strURL = strURL + "&lat=" + coor.latitude.description
            strURL = strURL + "&lon=" + coor.longitude.description
            strURL = strURL + "&per_page=" + downloadLimit.description
            strURL = strURL + "&page=" + curPageNum.description
            strURL = strURL + "&extras=url_m&format=json&nojsoncallback=1"
            
            let url = NSURL(string: strURL)
            let request = NSMutableURLRequest(URL: url!)
            request.addValue("application/json", forHTTPHeaderField: "Accept")
            
            //get this pin Entity
            let fetchRequest = NSFetchRequest(entityName: "Pin")
            fetchRequest.fetchLimit = 1
            fetchRequest.predicate = NSPredicate(format: "pinLat = %@ AND pinLon = %@", argumentArray: [coor.latitude, coor.longitude])
            
            fetchRequest.sortDescriptors = [] //sort by url
            
            var error: NSError? = nil
            
            var thisPin = (context!.executeFetchRequest(fetchRequest, error: &error) as! [Pin])[0] //fetch our pin
            
            if error != nil {
                //didn't find pin
                completionHandler(success: false, numFound: 0, retError: error)
                return
            }
            
            //get document directory
            let documents = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true)[0] as! String
            let placeholderPath = documents + "/Placeholder.jpg"
            
            //start task to get URLs
            let task = flickrSession.dataTaskWithRequest(request) { data, response, error in
                if error != nil { // Handle error...
                    completionHandler(success: false, numFound: 0, retError: error)
                    return
                } else {
                    
                    //get URL information for each photo
                    let parseResults = NSJSONSerialization.JSONObjectWithData(data, options: NSJSONReadingOptions.AllowFragments, error: nil) as! NSDictionary
                    
                    if let photos = parseResults["photos"] as? [String : AnyObject] {
                        
                        self.totalPages = (photos["pages"] as? Int)! // get total number of pages for this pin
                        
                        if let photo = photos["photo"] as? [[String : AnyObject]] {
                            for photoURL in photo {
                                countPhotos++ //keep track of number of photos downloaded
                                if let strURL = (photoURL["url_m"] as? String) { //get file URL to process
                                    //insert core data with new pin and url
                                    let photo = NSEntityDescription.insertNewObjectForEntityForName("Photo", inManagedObjectContext: context!) as! Photo
                                    photo.filePath = placeholderPath //set file path
                                    photo.url = strURL
                                    photo.mapPin = thisPin
                                    //save photo entity
                                    var ferror: NSError? = nil
                                    context?.save(&ferror)
                                    if ferror != nil {
                                        //Photo save to core data failed
                                        completionHandler(success: false, numFound: 0, retError: ferror)
                                        return
                                    }
                                }
                            }
                            completionHandler(success: true, numFound: countPhotos, retError: nil)
                        }
                    }
                }
            }
            
            task.resume()
    }
    
}
