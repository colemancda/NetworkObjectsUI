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
    
    public let store: Store
    
    /** Sort descriptors that are additionally applied to the search results. Not sent with requests. */
    public let localSortDescriptors: [NSSortDescriptor]?
    
    public weak var delegate: SearchResultsControllerDelegate?
    
    // MARK: - Private Properties
    
    /** Managed objects fetched from the server. */
    private let fetchedResultsController: NSFetchedResultsController
    
    private var searchResults = [NSManagedObject]()
    
    // MARK: - Initialization
    
    public init(fetchRequest: NSFetchRequest, store: Store, localSortDescriptors: [NSSortDescriptor]? = nil, delegate: SearchResultsControllerDelegate? = nil) {
        
        self.fetchRequest = fetchRequest
        self.store = store
        self.localSortDescriptors = localSortDescriptors
        self.delegate = delegate
        
        let searchRequest = fetchRequest.copy() as! NSFetchRequest
        
        assert(searchRequest.sortDescriptors != nil, "The fetch request for the seach operation must specify sort descriptors")
        
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
    
    public func performFetch() -> NSError? {
        
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
                
                return
            case .Delete:
                
                // already deleted
                if !(self.searchResults as NSArray).containsObject(managedObject) {
                    
                    return
                }
                
                let row = (self.searchResults as NSArray).indexOfObject(managedObject)
                
                self.searchResults.removeAtIndex(row)
                
                self.delegate?.controller(self, didDeleteManagedObject: managedObject, atIndex: UInt(row))
                
                return
            default:
                return
            }
    }
    
    public func controllerDidChangeContent(controller: NSFetchedResultsController) {
        
        self.delegate?.controllerDidChangeContent(self)
    }
}

// MARK: - Protocol

/*  */
public protocol SearchResultsControllerDelegate: class {
    
    func controllerWillChangeContent(controller: SearchResultsController)
    
    func controllerDidChangeContent(controller: SearchResultsController)
    
    func controller(controller: SearchResultsController, didInsertManagedObject managedObject: NSManagedObject, atIndex index: UInt)
    
    func controller(controller: SearchResultsController, didDeleteManagedObject managedObject: NSManagedObject, atIndex index: UInt)
    
    func controller(controller: SearchResultsController, didUpdateManagedObject managedObject: NSManagedObject, atIndex index: UInt)
    
    func controller(controller: SearchResultsController, didMoveManagedObject managedObject: NSManagedObject, atIndex index: UInt, toIndex: UInt)
}

