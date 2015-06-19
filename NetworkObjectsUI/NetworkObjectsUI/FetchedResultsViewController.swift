//
//  FetchedResultsViewController.swift
//  NetworkObjectsUI
//
//  Created by Alsey Coleman Miller on 12/10/14.
//  Copyright (c) 2014 ColemanCDA. All rights reserved.
//

import Foundation
import UIKit
import CoreData
import NetworkObjects
import ExSwift

/** Fetches instances of an entity on the server and displays them in a table view. Supports single section only. */
public class FetchedResultsViewController: UITableViewController, SearchResultsControllerDelegate {
    
    // MARK: - Properties
    
    /** NetworkObjects Store that this view controller will use. Make sure to set this value before loading this class. Store must have its dateCachedAttributeName set. Must set before 'fetchRequest'. */
    public var store: Store!
    
    /** Sort descriptors that are additionally applied to the search results. Not sent with requests. Must set before 'fetchRequest'. */
    public var localSortDescriptors: [NSSortDescriptor]?
    
    /** The fetch request that will be converted into a search request. Also used to created a fetched results controller to display content. */
    public var fetchRequest: NSFetchRequest? {
        
        didSet {
            
            if fetchRequest == nil {
                
                self.searchResultsController = nil
                
                return
            }
            
            self.searchResultsController = SearchResultsController(fetchRequest: fetchRequest!, store: self.store, localSortDescriptors: self.localSortDescriptors, delegate: self)
            
            // perform fetch if view is loaded
            if self.isViewLoaded() {
                
                let error = self.searchResultsController!.loadCache()
                
                assert(error == nil, "Could not load cache. (\(error!.localizedDescription))")
                
                // load from server
                self.refresh(self)
            }
        }
    }
    
    /** Date the data was last pulled from the server. */
    public private(set) var datedRefreshed: NSDate?
    
    // MARK: - Private Properties
    
    private var searchResultsController: SearchResultsController?
    
    private var previousSearchResults: [NSManagedObject]?
    
    // MARK: - Initialization
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        let error = self.searchResultsController?.loadCache()
        
        assert(error == nil, "Could not load cache. (\(error!.localizedDescription))")
    }
    
    public override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        // start reloading data before view appears
        self.refresh(self)
    }
    
    // MARK: - Methods
    
    /** Fetches the managed object at the specified index path from the data source. */
    public func objectAtIndexPath(indexPath: NSIndexPath) -> NSManagedObject {
        
        assert(indexPath.section == 0, "Only single section supported")
        
        return self.searchResultsController!.objectAtIndex(UInt(indexPath.row))
    }
    
    /** Subclasses should overrride this to provide custom cells. */
    public func dequeueReusableCellForIndexPath(indexPath: NSIndexPath) -> UITableViewCell {
        
        let CellIdentifier = NSStringFromClass(UITableViewCell)
        
        var cell = self.tableView.dequeueReusableCellWithIdentifier(CellIdentifier, forIndexPath: indexPath) as? UITableViewCell
        
        if cell == nil {
            
            cell = UITableViewCell(style: UITableViewCellStyle.Default, reuseIdentifier: CellIdentifier)
        }
        
        return cell!
    }
    
    /** Subclasses should override this to configure custom cells. */
    public func configureCell(cell: UITableViewCell, atIndexPath indexPath: NSIndexPath, withError error: NSError? = nil) {
        
        if error != nil {
            
            // TODO: Configure cell for error
            
            return
        }
        
        // get model object
        let managedObject = self.objectAtIndexPath(indexPath)
        
        let dateCached = managedObject.valueForKey(self.store.dateCachedAttributeName!) as? NSDate
        
        // not cached
        
        if dateCached == nil {
            
            // configure empty cell...
            
            cell.textLabel?.text = NSLocalizedString("Loading...", comment: "Loading...")
            
            cell.detailTextLabel?.text = ""
            
            cell.userInteractionEnabled = false
            
            return
        }
        
        // configure cell...
        
        cell.userInteractionEnabled = true
        
        // Entity name + resource ID
        cell.textLabel!.text = "\(managedObject.entity)" + "\(managedObject.valueForKey(self.store.resourceIDAttributeName))"
    }
    
    // MARK: - Actions
    
    @IBAction public func refresh(sender: AnyObject) {
        
        if self.fetchRequest == nil {
            
            self.refreshControl?.endRefreshing()
            
            return
        }
        
        self.datedRefreshed = NSDate()
        
        self.previousSearchResults = self.searchResultsController!.searchResults
        
        self.searchResultsController!.performSearch(sender)
    }
    
    // MARK: - Private Methods
    
    private func deleteManagedObject(managedObject: NSManagedObject) {
        
        self.store.deleteManagedObject(managedObject, completionBlock: { (error) -> Void in
            
            NSOperationQueue.mainQueue().addOperationWithBlock({ () -> Void in
                
                // show error
                if error != nil {
                    
                    self.showErrorAlert(error!.localizedDescription, retryHandler: { () -> Void in
                        
                        self.deleteManagedObject(managedObject)
                    })
                    
                    return
                }
                
            })
        })
    }
    
    // MARK: - UITableViewDataSource
    
    public override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        
        return 1
    }
    
    public override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        return self.searchResultsController?.searchResults.count ?? 0
    }
    
    public override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        
        let cell = self.dequeueReusableCellForIndexPath(indexPath) as UITableViewCell
        
        // configure cell
        self.configureCell(cell, atIndexPath: indexPath)
        
        // fetch from server... (loading table view after -refresh:)
        
        if self.datedRefreshed != nil {
            
            // get model object
            let managedObject = self.objectAtIndexPath(indexPath)
            
            // get date cached
            let dateCached = managedObject.valueForKey(self.store.dateCachedAttributeName!) as? NSDate
            
            // fetch if older than refresh date or not fetched yet
            if dateCached == nil || dateCached?.compare(self.datedRefreshed!) == NSComparisonResult.OrderedAscending {
                
                self.store.fetchEntity(managedObject.entity.name!, resourceID: managedObject.valueForKey(self.store.resourceIDAttributeName) as! UInt, completionBlock: { (error, managedObject) -> Void in
                    
                    // configure error cell
                    NSOperationQueue.mainQueue().addOperationWithBlock({ () -> Void in
                        
                        if error != nil {
                            
                            // get cell for error request (may have changed)
                            
                            // TODO: handle error (show error text in cell)
                        }
                    })
                    
                    // fetched results controller should update cell
                })
            }
        }
        
        return cell
    }
    
    // MARK: - UITableViewDelegate
    
    public override func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
        
        // get model object
        let managedObject = self.objectAtIndexPath(indexPath)
        
        switch editingStyle {
            
        case .Delete:
            
            self.deleteManagedObject(managedObject)
            
        default:
            
            return
        }
    }
    
    public override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        
        tableView.deselectRowAtIndexPath(indexPath, animated: true)
    }
    
    // MARK: - SearchResultsControllerDelegate
    
    public func controller(controller: SearchResultsController, didPerformSearchWithError error: NSError?) {
        
        NSOperationQueue.mainQueue().addOperationWithBlock { () -> Void in
            
            // show error
            if error != nil {
                
                self.refreshControl?.endRefreshing()
                
                self.showErrorAlert(error!.localizedDescription, retryHandler: { () -> Void in
                    
                    self.refresh(self)
                })
                
                return
            }
            
            // update table view with nice animations...
            
            if self.previousSearchResults != nil {
                
                self.tableView.beginUpdates()
                
                let results = self.searchResultsController!.searchResults
                
                let previousSearchResultsArray = self.previousSearchResults! as NSArray
                
                for (index, searchResult) in enumerate(results) {
                    
                    // already present
                    if previousSearchResultsArray.containsObject(searchResult) {
                        
                        let previousIndex = previousSearchResultsArray.indexOfObject(searchResult) as Int
                        
                        // move cell
                        if index != previousIndex {
                            
                            self.tableView.deleteRowsAtIndexPaths([NSIndexPath(forRow: Int(previousIndex), inSection: 0)], withRowAnimation: .Automatic)
                            
                            self.tableView.insertRowsAtIndexPaths([NSIndexPath(forRow: Int(index), inSection: 0)], withRowAnimation: .Automatic)
                        }
                            
                            // update cell
                        else {
                            
                            let indexPath = NSIndexPath(forRow: Int(index), inSection: 0)
                            
                            if let cell = self.tableView.cellForRowAtIndexPath(indexPath) {
                                
                                self.configureCell(cell, atIndexPath: indexPath)
                            }
                        }
                    }
                        
                        // new managed object
                    else {
                        
                        self.tableView.insertRowsAtIndexPaths([NSIndexPath(forRow: index, inSection: 0)], withRowAnimation: .Automatic)
                    }
                }
                
                self.tableView.endUpdates()
            }
            
            self.previousSearchResults = nil
            
            self.refreshControl?.endRefreshing()
        }
    }
    
    public func controllerWillChangeContent(controller: SearchResultsController) {
        
        self.tableView.beginUpdates()
    }
    
    public func controllerDidChangeContent(controller: SearchResultsController) {
        
        self.tableView.endUpdates()
    }
    
    public func controller(controller: SearchResultsController, didInsertManagedObject managedObject: NSManagedObject, atIndex index: UInt) {
        
        self.tableView.insertRowsAtIndexPaths([NSIndexPath(forRow: Int(index), inSection: 0)], withRowAnimation: .Automatic)
    }
    
    public func controller(controller: SearchResultsController, didDeleteManagedObject managedObject: NSManagedObject, atIndex index: UInt) {
        
        self.tableView.deleteRowsAtIndexPaths([NSIndexPath(forRow: Int(index), inSection: 0)], withRowAnimation: .Automatic)
    }
    
    public func controller(controller: SearchResultsController, didUpdateManagedObject managedObject: NSManagedObject, atIndex index: UInt) {
        
        let indexPath = NSIndexPath(forRow: Int(index), inSection: 0)
        
        if let cell = self.tableView.cellForRowAtIndexPath(indexPath) {
            
            self.configureCell(cell, atIndexPath: indexPath)
        }
    }
    
    public func controller(controller: SearchResultsController, didMoveManagedObject managedObject: NSManagedObject, atIndex newIndex: UInt, toIndex oldIndex: UInt) {
        
        self.tableView.deleteRowsAtIndexPaths([NSIndexPath(forRow: Int(newIndex), inSection: 0)], withRowAnimation: .Automatic)
        
        self.tableView.insertRowsAtIndexPaths([NSIndexPath(forRow: Int(oldIndex), inSection: 0)], withRowAnimation: .Automatic)
    }
}
