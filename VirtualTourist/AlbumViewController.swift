//
//  AlbumViewController.swift
//  VirtualTourist
//
//  Created by Dwayne George on 8/14/15.
//  Copyright (c) 2015 Dwayne George. All rights reserved.
//

import UIKit
import MapKit
import CoreData


class AlbumViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate, MKMapViewDelegate, NSFetchedResultsControllerDelegate {
    
    let context = (UIApplication.sharedApplication().delegate as! AppDelegate).managedObjectContext
    var nPin: Pin? = nil
    
    
    @IBOutlet weak var btnNewCollection: UIBarButtonItem!
    
    @IBOutlet weak var btnDelete: UIBarButtonItem!
    
    var updatedIndexPaths: [NSIndexPath]!
    var insertedIndexPaths: [NSIndexPath]!
    var deletedIndexPaths: [NSIndexPath]!
    var holdInsertedIndexPaths: [NSIndexPath]!
    
    let placeHolderImageName = "Placeholder.jpg"
    
    var flickr: FlickrDownLoad = FlickrDownLoad()
    
    @IBOutlet weak var smallViewMap: MKMapView!
    
    @IBOutlet weak var colView: UICollectionView!
    
    //create variable to hold coordinates of selected annotation
    var selectedCoordinates: CLLocationCoordinate2D? = nil
    
    var appDelegate: AppDelegate? = nil //get appDelegate for a reference to Meme class
    
    lazy var fetchResultCtrl: NSFetchedResultsController = {
        
        let fetchRequest = NSFetchRequest(entityName: "Photo")
        fetchRequest.predicate = NSPredicate(format: "mapPin.pinLat = %@ AND mapPin.pinLon = %@", argumentArray: [self.selectedCoordinates!.latitude, self.selectedCoordinates!.longitude])
        let sortDescriptor = NSSortDescriptor(key: "url", ascending: true)
        fetchRequest.sortDescriptors = [sortDescriptor]
        
        let fetchResultCtrl = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: self.context!, sectionNameKeyPath: nil, cacheName: nil)
        
        fetchResultCtrl.delegate = self
        return fetchResultCtrl
        
        }()
    
    override func viewWillAppear(animated: Bool) {
        
        // get saved Memes
        let object = UIApplication.sharedApplication().delegate
        appDelegate = object as? AppDelegate
    }
    
    override func viewDidLoad() {
        
        super.viewDidLoad()
        self.colView.dataSource = self;
        self.colView.delegate = self;
        smallViewMap.delegate = self
        let object = UIApplication.sharedApplication().delegate
        appDelegate = object as? AppDelegate
        
        btnNewCollection.enabled = false //disable the button until download competed.
        
        //create and add pin
        var newAnotation = MKPointAnnotation()
        newAnotation.coordinate = selectedCoordinates!
        smallViewMap.addAnnotation(newAnotation)
        
        //center map on location
        let region = MKCoordinateRegion(center: selectedCoordinates!, span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01))
        smallViewMap.setRegion(region, animated: true)
        
        //check to see if placeholder image exist, if not create it.
        let documents = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true)[0] as! String
        var path = documents + "/" + placeHolderImageName
        let docManager = NSFileManager.defaultManager()
        
        if !docManager.fileExistsAtPath(path) {
            //create file
            UIImageJPEGRepresentation(UIImage(named: placeHolderImageName)!, 0.5).writeToFile(path, options: NSDataWritingOptions.DataWritingAtomic, error: nil)
        }
        
        //determine if there are any photos associated with this pin
        var fetchError: NSErrorPointer = NSErrorPointer()
        fetchResultCtrl.performFetch(fetchError)
        if fetchError == nil {
            //check for existing photos
            if fetchResultCtrl.fetchedObjects!.count > 0 {
                //information already exist for this pin...reload the data
                colView.reloadData()
                btnNewCollection.enabled = true //enable the button refresh button
            } else {
                //no photos exist for this pin. get new ones
                updatePhotos(false)
            }
        }
    }
    
    func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        
        let sectionInfo = self.fetchResultCtrl.sections![section] as! NSFetchedResultsSectionInfo
        let objectCount = sectionInfo.numberOfObjects
        return objectCount
    }
    
    func collectionView(collectionView: UICollectionView, didSelectItemAtIndexPath indexPath: NSIndexPath) {
        
        let cell = collectionView.dequeueReusableCellWithReuseIdentifier("Cell", forIndexPath: indexPath) as! PhotoCollectionViewCell
        
        removePhoto(indexPath)
    }
    
    
    
    func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
        
        let cell = collectionView.dequeueReusableCellWithReuseIdentifier("Cell", forIndexPath: indexPath) as! PhotoCollectionViewCell
        
        let photo = self.fetchResultCtrl.objectAtIndexPath(indexPath) as! Photo //get this photo...could be placeholder image or actual downloaded image
        
        let docManager = NSFileManager.defaultManager()
        
        if docManager.fileExistsAtPath(photo.filePath!) {
            cell.imageCell.image = UIImage(contentsOfFile: photo.filePath!) //add image to cell
        } else {
            //this will happen if the application is restarted in the simulator by using Xcode build and run
            //it occurs because the document directory location changes.  However, if the application is stopped and restarted within
            //the simulator, all is well.
            
            //reload photographs because application was restarted from Xcode interface which changed the document directory
            //path stored in core data
            let documents = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true)[0] as! String
            let placeholderPath = documents + "/" + placeHolderImageName
            
            photo.filePath = placeholderPath  //change photo file path to force a reload of the image
            context!.save(nil)
        }
        
        if photo.filePath!.lastPathComponent == placeHolderImageName {
            ////image not availabe yet...download file image.
            flickr.getImageFromURL(photo.url, context: context, photoObj: photo) { success, error in
                dispatch_async(dispatch_get_main_queue(), { self.colView.reloadItemsAtIndexPaths([indexPath]) })
            }
        }

        return cell
    }
    
    func controllerDidChangeContent(controller: NSFetchedResultsController) {
        //required for NSFetchedResultsController to track changes
    }
 
    func updatePhotos(nextPage: Bool)
    {
        let docManager = NSFileManager.defaultManager()
        
        //delete all image files for this pin in document directory except placeholder image
        let photos = fetchResultCtrl.fetchedObjects as! [Photo] //get all of the photos
        
        for photo in photos
        { //iterate through each row and delete associated file from document directory
            if let path = photo.filePath {
                if docManager.fileExistsAtPath(path) { //delete file if it exists
                    if path.lastPathComponent != placeHolderImageName {
                        docManager.removeItemAtPath(path, error: nil)
                    }
                    context!.deleteObject(photo) //remove photos for pin
                }
            }
        }
        
        if context!.hasChanges {
            context!.save(nil) //update core data
        }
        
        dispatch_async(dispatch_get_main_queue(), { self.colView.reloadData() }) //update collection view on main thread
        
        //get urls for photos and insert them into core data.
        //refresh urls for this pin
        self.flickr.saveURLForImagesOfPin(self.selectedCoordinates!, nextPage: nextPage, context: self.context) { success, numFound, error in
            if success {
                if numFound > 0 {
                    dispatch_async(dispatch_get_main_queue(), { self.colView.reloadData() })  //update collection view on main thread
                } else {
                    //display no photos found
                    var alert = UIAlertController(title: "Information", message: "No photos found", preferredStyle: UIAlertControllerStyle.Alert)
                    alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.Default, handler: nil))
                    self.presentViewController(alert, animated: true, completion: nil)
                }
                
                dispatch_async(dispatch_get_main_queue(), { self.btnNewCollection.enabled = true }) //enable the button refresh button
            }
        }
    }
    
    func removePhoto(indexPath: NSIndexPath)
    {
        let docManager = NSFileManager.defaultManager()
        if let photo = fetchResultCtrl.objectAtIndexPath(indexPath) as? Photo {
            //delete image file for this pin in document directory except placeholder image
            if let path = photo.filePath {
                if docManager.fileExistsAtPath(path) { //delete file if it exists
                    if path.lastPathComponent != placeHolderImageName {
                        docManager.removeItemAtPath(path, error: nil) //remove photo from document dir
                    }
                }
                self.context!.deleteObject(photo) //remove this photo from core data
                self.context!.save(nil) //update core data
                self.colView.deleteItemsAtIndexPaths([indexPath]) //remove photo from collection view
            }
            
            if context!.hasChanges {
                context!.save(nil) //update core data
            }
        }
    }
    
    
    @IBAction func getNewCollection(sender: AnyObject) {
        
        //New Collection touched
        btnNewCollection.enabled = false //disable the button while downloading
        
        updatePhotos(true) //move to next page of photos
    }
    
}