//
//  MapViewController.swift
//  VirtualTourist
//
//  Created by Dwayne George on 8/13/15.
//  Copyright (c) 2015 Dwayne George. All rights reserved.
//

import UIKit
import MapKit
import CoreData

class MapViewController: UIViewController, MKMapViewDelegate, NSFetchedResultsControllerDelegate {
    
    let context = (UIApplication.sharedApplication().delegate as! AppDelegate).managedObjectContext
    
    var nPin : Pin? = nil
    var fetchCtrl : NSFetchedResultsController  = NSFetchedResultsController()
    var fetchCtrlMap : NSFetchedResultsController  = NSFetchedResultsController()
    
    @IBOutlet weak var viewMap: MKMapView!
    
    var savedCoordinates: CLLocationCoordinate2D? = nil
    
    func pinFetchRequest() -> NSFetchRequest {
        let fetchRequest = NSFetchRequest(entityName: "Pin")
        fetchRequest.sortDescriptors = []
        return fetchRequest
    }
    
    func mapLocFetchRequest() -> NSFetchRequest {
        let fetchRequest = NSFetchRequest(entityName: "MapLocation")
        fetchRequest.sortDescriptors = []
        return fetchRequest
    }
    
    override func viewWillDisappear(animated: Bool) {
        //save map information in core data
        
        fetchCtrlMap.performFetch(nil) //get data
        
        //convert MKCoordinateRegion to types for core data
        let centerLat: NSNumber = viewMap.region.center.latitude
        let centerLon: NSNumber = viewMap.region.center.longitude
        let spanLatDelta: NSNumber = viewMap.region.span.latitudeDelta
        let spanLonDelta: NSNumber = viewMap.region.span.longitudeDelta
        
        if fetchCtrlMap.fetchedObjects!.count == 1
        { //update map persistence
            if let mapLocations = fetchCtrlMap.fetchedObjects as? [MapLocation] {
                let mapLocation = mapLocations[0]
                mapLocation.latitude = centerLat
                mapLocation.longitude = centerLon
                mapLocation.latitudeDelta = spanLatDelta
                mapLocation.longitudeDelta = spanLonDelta
                context?.save(nil)
            }
            
        } else {
            //insert attribute to store map persistence
            let mapLocation = NSEntityDescription.insertNewObjectForEntityForName("MapLocation", inManagedObjectContext: context!) as! MapLocation
            mapLocation.latitude = centerLat
            mapLocation.longitude = centerLon
            mapLocation.latitudeDelta = spanLatDelta
            mapLocation.longitudeDelta = spanLonDelta
            
            //save current map location entity
            context?.save(nil)
            
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        viewMap.delegate = self
        
        //create gesture recognizer
        let longTouchGesture = UILongPressGestureRecognizer(target: self, action: "gestureAction:")
        longTouchGesture.minimumPressDuration = 1.0
        longTouchGesture.allowableMovement = 0
        viewMap.addGestureRecognizer(longTouchGesture)
        
        fetchCtrl.delegate = self
        fetchCtrlMap.delegate = self
        
        var fetchError: NSErrorPointer = NSErrorPointer()
        
        //set map view from core data if information exist
        fetchCtrlMap = NSFetchedResultsController(fetchRequest: mapLocFetchRequest(), managedObjectContext: context!, sectionNameKeyPath: nil, cacheName: nil)
        
        fetchCtrlMap.performFetch(fetchError) //get data
        
        if fetchError == nil {
            if fetchCtrlMap.fetchedObjects!.count == 1
            {
                if let mapLocations = fetchCtrlMap.fetchedObjects as? [MapLocation]
                {   //center map on location previous location
                    let mapLocation = mapLocations[0]
                    let mapCenter: CLLocationCoordinate2D = CLLocationCoordinate2D(latitude: mapLocation.latitude as Double, longitude: mapLocation.longitude as Double)
                    let mapSpan: MKCoordinateSpan = MKCoordinateSpan(latitudeDelta: mapLocation.latitudeDelta as Double, longitudeDelta: mapLocation.longitudeDelta as Double)
                    
                    let region = MKCoordinateRegion(center: mapCenter, span: mapSpan)
                    viewMap.setRegion(region, animated: true)
                }
            }
        }
        
        //read any core data information
        fetchCtrl = NSFetchedResultsController(fetchRequest: pinFetchRequest(), managedObjectContext: context!, sectionNameKeyPath: nil, cacheName: nil)
        
        //update map view
        fetchCtrl.performFetch(fetchError)
        if fetchError == nil {
            let pins = fetchCtrl.fetchedObjects as! [Pin]
            for nPin in pins {
                //create and add pin
                //convert location to 2D Coordinates
                var newCoord:CLLocationCoordinate2D = CLLocationCoordinate2DMake(nPin.pinLat as CLLocationDegrees, nPin.pinLon as CLLocationDegrees)
                var newAnotation = MKPointAnnotation()
                newAnotation.coordinate = newCoord
                viewMap.addAnnotation(newAnotation)
            }
        }
    }
    
    //handle map gestures
    func gestureAction(gestureRecognizer:UIGestureRecognizer) {
        
        if gestureRecognizer.state == UIGestureRecognizerState.Ended
        {//get the location of the touch
            var touchLocation = gestureRecognizer.locationInView(self.viewMap)
            
            //convert location to 2D Coordinates
            var newCoord:CLLocationCoordinate2D = viewMap.convertPoint(touchLocation, toCoordinateFromView: self.viewMap)
            
            //create and add pin
            var newAnotation = MKPointAnnotation()
            newAnotation.coordinate = newCoord
            viewMap.addAnnotation(newAnotation)
            
            //save pin to coredata
            let context = self.context
            let pinEntity = NSEntityDescription.entityForName("Pin", inManagedObjectContext: context!)
            let newPin = Pin(entity: pinEntity!, insertIntoManagedObjectContext: context)
            
            newPin.pinLat = newCoord.latitude
            newPin.pinLon = newCoord.longitude
            context?.save(nil)
        }
    }
    
    func mapView(mapView: MKMapView!, didSelectAnnotationView view: MKAnnotationView) {
        savedCoordinates = view.annotation.coordinate //save pin location
        self.performSegueWithIdentifier("photoView", sender: self) //change to Album view
    }
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if(segue.identifier == "photoView")
        { //pass location of pin to photo view
            let objViewController = segue.destinationViewController as! AlbumViewController
            if let coor = savedCoordinates {
                objViewController.selectedCoordinates = savedCoordinates
            }
        }
    }
}