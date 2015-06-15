//
//  SearchResultsController.swift
//  NetworkObjectsUI
//
//  Created by Alsey Coleman Miller on 6/15/15.
//  Copyright (c) 2015 ColemanCDA. All rights reserved.
//

import Foundation
import CoreData
import NetworkObjects

/** Executes a search request on the server and delegates the results, merged with local cache to the delegate for display in the UI. Does not support sections. */
final public class SearchResultsController: NSFetchedResultsControllerDelegate {
    
    // MARK: - Properties
    
    /** The fetch request this controller will execute. Do not change properties after initializing the controller. */
    public let fetchRequest: NSFetchRequest
    
    /** Store that will execute and cache the seach request. Store's 'searchPath' property must not be nil. */
    public let store: Store
    
    /** Sort descriptors that are additionally applied to the search results. Not sent with requests. */
    public let localSortDescriptors: [NSSortDescriptor]?
    
    /** The search controller's delegate. */
    public weak var delegate: SearchResultsControllerDelegate?
    
    /** The cached search results. */
    public private(set) var searchResults = [NSManagedObject]()
    
    // MARK: - Private Properties
    
    /** Managed objects fetched from the server. */
    private let fetchedResultsController: NSFetchedResultsController
    
    // MARK: - Initialization
    
    public init(fetchRequest: NSFetchRequest, store: Store, localSortDescriptors: [NSSortDescriptor]? = nil, delegate: SearchResultsControllerDelegate? = nil) {
        
        assert(store.searchPath != nil, "Store's 'searchPath' must not be nil")
        
        assert(fetchRequest.sortDescriptors != nil, "The fetch request for the seach operation must specify sort descriptors")
        
        self.fetchRequest = fetchRequest
        self.store = store
        self.localSortDescriptors = localSortDescriptors
        self.delegate = delegate
        
        let searchRequest = fetchRequest.copy() as! NSFetchRequest
        
        // add additional sort descriptors
        if let additionalSortDescriptors = self.localSortDescriptors {
            
            var sortDescriptors = additionalSortDescriptors
            
            sortDescriptors += searchRequest.sortDescriptors as! [NSSortDescriptor]
            
            searchRequest.sortDescriptors = sortDescriptors
        }
        
        // create new fetched results controller
        
        self.fetchedResultsController = NSFetchedResultsController(fetchRequest: searchRequest, managedObjectContext: self.store.managedObjectContext, sectionNameKeyPath: nil, cacheName: nil)
        
        self.fetchedResultsController.delegate = self

    }
    
    // MARK: - Methods
    
    /** Fetches search results from server. Must call 'loadCache()' to register for delegate notifications regarding changes to the cache. */
    @IBAction public func performSearch(sender: AnyObject?) {
        
        self.store.performSearch(self.fetchRequest, completionBlock: {[weak self] (error: NSError?, results: [NSManagedObject]?) -> Void in
            
            if self == nil {
                
                return
            }
            
            if error != nil {
                
                self!.delegate?.controller(self!, didPerformSearchWithError: error!)
            }
            
            // save results
            self!.searchResults = results!
            
            // inform delegate
            self!.delegate?.controller(self!, didPerformSearchWithError: nil)
        })
    }
    
    /** Loads caches objects. Does not fetch from server. Call this to recieve delegate notificationes about changes in the cache. */
    public func loadCache() -> NSError? {
        
        var error: NSError?
        
        self.fetchedResultsController.performFetch(&error)
        
        return error
    }
    
    /** Fetches the managed object at the specified index path from the data source. */
    public func objectAtIndex(index: UInt) -> NSManagedObject {
        
        return self.searchResults[Int(index)]
    }
    
    // MARK: - NSFetchedResultsControllerDelegate
    
    public func controllerWillChangeContent(controller: NSFetchedResultsController) {
        
        self.delegate?.controllerWillChangeContent(self)
    }
    
    public func controller(controller: NSFetchedResultsController,
        didChangeObject object: AnyObject,
        atIndexPath indexPath: NSIndexPath?,
        forChangeType type: NSFetchedResultsChangeType,
        newIndexPath: NSIndexPath?) {
            
            let managedObject = object as! NSManagedObject
            
            switch type {
                
            case .Insert:
                
                // already inserted
                if (self.searchResults as NSArray).containsObject(managedObject) {
                    
                    return
                }
                
                self.searchResults.append(managedObject)
                
                self.searchResults = (self.searchResults as NSArray).sortedArrayUsingDescriptors(self.fetchRequest.sortDescriptors!) as! [NSManagedObject]
                
                let row = (self.searchResults as NSArray).indexOfObject(managedObject)
                
                self.delegate?.controller(self, didInsertManagedObject: managedObject, atIndex: UInt(row))
                
            case .Update:
                
                let row = (self.searchResults as NSArray).indexOfObject(managedObject)
                
                let managedObjectIndexPath = NSIndexPath(forRow: row, inSection: 0)
                
                self.delegate?.controller(self, didUpdateManagedObject: managedObject, atIndex: UInt(row))
                
            case .Move:
                
                // get old row
                
                let oldRow = (self.searchResults as NSArray).indexOfObject(managedObject)
                
                self.searchResults = (self.searchResults as NSArray).sortedArrayUsingDescriptors(self.fetchRequest.sortDescriptors!) as! [NSManagedObject]
                
                let newRow = (self.searchResults as NSArray).indexOfObject(managedObject)
                
                if newRow != oldRow {
                    
                    self.delegate?.controller(self, didMoveManagedObject: managedObject, atIndex: UInt(oldRow), toIndex: UInt(newRow))
                }
                
            case .Delete:
                
                // already deleted
                if !(self.searchResults as NSArray).containsObject(managedObject) {
                    
                    return
                }
                
                let row = (self.searchResults as NSArray).indexOfObject(managedObject)
                
                self.searchResults.removeAtIndex(row)
                
                self.delegate?.controller(self, didDeleteManagedObject: managedObject, atIndex: UInt(row))
                
            default:
                return
            }
    }
    
    public func controllerDidChangeContent(controller: NSFetchedResultsController) {
        
        self.delegate?.controllerDidChangeContent(self)
    }
}

// MARK: - Protocol

/* Delegate methods for the search controller. */
public protocol SearchResultsControllerDelegate: class {
    
    /** Informs the delegate that a search request has completed with the specified error (if any). */
    func controller(controller: SearchResultsController, didPerformSearchWithError error: NSError?)
    
    func controllerWillChangeContent(controller: SearchResultsController)
    
    func controllerDidChangeContent(controller: SearchResultsController)
    
    func controller(controller: SearchResultsController, didInsertManagedObject managedObject: NSManagedObject, atIndex index: UInt)
    
    func controller(controller: SearchResultsController, didDeleteManagedObject managedObject: NSManagedObject, atIndex index: UInt)
    
    func controller(controller: SearchResultsController, didUpdateManagedObject managedObject: NSManagedObject, atIndex index: UInt)
    
    func controller(controller: SearchResultsController, didMoveManagedObject managedObject: NSManagedObject, atIndex oldIndex: UInt, toIndex newIndex: UInt)
}

