//
//  ViewController.swift
//  Done
//
//  Created by Bart Jacobs on 19/10/15.
//  Copyright © 2015 Envato Tuts+. All rights reserved.
//

import UIKit
import CoreData

class ViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, NSFetchedResultsControllerDelegate {

    let ReuseIdentifierToDoCell = "ToDoCell"
    
    @IBOutlet weak var tableView: UITableView!
    
    var managedObjectContext: NSManagedObjectContext!
    
    var deleteAllButton: UIBarButtonItem!
    
    lazy var fetchedResultsController: NSFetchedResultsController = {
        // Initialize Fetch Request
        let fetchRequest = NSFetchRequest(entityName: "Item")
        
        // Add Sort Descriptors
        let sortDescriptor = NSSortDescriptor(key: "createdAt", ascending: true)
        fetchRequest.sortDescriptors = [sortDescriptor]
        
        // Initialize Fetched Results Controller
        let fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: self.managedObjectContext, sectionNameKeyPath: nil, cacheName: nil)
        
        // Configure Fetched Results Controller
        fetchedResultsController.delegate = self
        
        return fetchedResultsController
    }()
    
    // MARK: -
    // MARK: View Life Cycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        do {
            try self.fetchedResultsController.performFetch()
        } catch {
            let fetchError = error as NSError
            print("\(fetchError), \(fetchError.userInfo)")
        }
        
        // Initialize Delete All Button
        deleteAllButton = UIBarButtonItem(title: "Delete All", style: .Plain, target: self, action: "deleteAll:")
        
        // Configure Navigation Item
        navigationItem.leftBarButtonItem = deleteAllButton
        
        // Seed Persistent Store
        seedPersistentStore()
    }
    
    // MARK: -
    // MARK: Prepare for Segue
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if segue.identifier == "SegueAddToDoViewController" {
            if let navigationController = segue.destinationViewController as? UINavigationController {
                if let viewController = navigationController.topViewController as? AddToDoViewController {
                    viewController.managedObjectContext = managedObjectContext
                }
            }
            
        } else if segue.identifier == "SegueUpdateToDoViewController" {
            if let viewController = segue.destinationViewController as? UpdateToDoViewController {
                if let indexPath = tableView.indexPathForSelectedRow {
                    // Fetch Record
                    let record = fetchedResultsController.objectAtIndexPath(indexPath) as! NSManagedObject
                    
                    // Configure View Controller
                    viewController.record = record
                    viewController.managedObjectContext = managedObjectContext
                }
            }
        }
    }
    
    // MARK: -
    // MARK: Table View Data Source Methods
    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        if let sections = fetchedResultsController.sections {
            return sections.count
        }
        
        return 0
    }
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if let sections = fetchedResultsController.sections {
            let sectionInfo = sections[section]
            return sectionInfo.numberOfObjects
        }
        
        return 0
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier(ReuseIdentifierToDoCell, forIndexPath: indexPath) as! ToDoCell
        
        // Configure Table View Cell
        configureCell(cell, atIndexPath: indexPath)
        
        return cell
    }
    
    func configureCell(cell: ToDoCell, atIndexPath indexPath: NSIndexPath) {
        // Fetch Record
        let record = fetchedResultsController.objectAtIndexPath(indexPath)
        
        // Update Cell
        if let name = record.valueForKey("name") as? String {
            cell.nameLabel.text = name
        }
        
        if let done = record.valueForKey("done") as? Bool {
            cell.doneButton.selected = done
        }
        
        cell.didTapButtonHandler = {
            if let done = record.valueForKey("done") as? Bool {
                record.setValue(!done, forKey: "done")
            }
        }
    }
    
    func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        return true
    }
    
    func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
        if (editingStyle == .Delete) {
            // Fetch Record
            let record = fetchedResultsController.objectAtIndexPath(indexPath) as! NSManagedObject
            
            // Delete Record
            managedObjectContext.deleteObject(record)
        }
    }
    
    // MARK: -
    // MARK: Table View Delegate Methods
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        tableView.deselectRowAtIndexPath(indexPath, animated: true)
    }
    
    // MARK: -
    // MARK: Fetched Results Controller Delegate Methods
    func controllerWillChangeContent(controller: NSFetchedResultsController) {
        tableView.beginUpdates()
    }
    
    func controllerDidChangeContent(controller: NSFetchedResultsController) {
        tableView.endUpdates()
    }
    
    func controller(controller: NSFetchedResultsController, didChangeObject anObject: AnyObject, atIndexPath indexPath: NSIndexPath?, forChangeType type: NSFetchedResultsChangeType, newIndexPath: NSIndexPath?) {
        switch (type) {
        case .Insert:
            if let indexPath = newIndexPath {
                tableView.insertRowsAtIndexPaths([indexPath], withRowAnimation: .Fade)
            }
            break;
        case .Delete:
            if let indexPath = indexPath {
                tableView.deleteRowsAtIndexPaths([indexPath], withRowAnimation: .Fade)
            }
            break;
        case .Update:
            if let indexPath = indexPath {
                let cell = tableView.cellForRowAtIndexPath(indexPath) as! ToDoCell
                configureCell(cell, atIndexPath: indexPath)
            }
            break;
        case .Move:
            if let indexPath = indexPath {
                tableView.deleteRowsAtIndexPaths([indexPath], withRowAnimation: .Fade)
            }
            
            if let newIndexPath = newIndexPath {
                tableView.insertRowsAtIndexPaths([newIndexPath], withRowAnimation: .Fade)
            }
            break;
        }
    }
    
    // MARK: -
    // MARK: Actions
    func checkAll(sender: UIBarButtonItem) {
        // Create Entity Description
        let entityDescription = NSEntityDescription.entityForName("Item", inManagedObjectContext: managedObjectContext)
        
        // Initialize Batch Update Request
        let batchUpdateRequest = NSBatchUpdateRequest(entity: entityDescription!)
        
        // Configure Batch Update Request
        batchUpdateRequest.resultType = .UpdatedObjectIDsResultType
        batchUpdateRequest.propertiesToUpdate = ["done": NSNumber(bool: true)]
        
        do {
            // Execute Batch Request
            let batchUpdateResult = try managedObjectContext.executeRequest(batchUpdateRequest) as! NSBatchUpdateResult
            
            // Extract Object IDs
            let objectIDs = batchUpdateResult.result as! [NSManagedObjectID]
            
            for objectID in objectIDs {
                // Turn Managed Objects into Faults
                let managedObject = managedObjectContext.objectWithID(objectID)
                managedObjectContext.refreshObject(managedObject, mergeChanges: false)
            }
            
            // Perform Fetch
            try self.fetchedResultsController.performFetch()
            
        } catch {
            let updateError = error as NSError
            print("\(updateError), \(updateError.userInfo)")
        }
    }
    
    func deleteAll(sender: UIBarButtonItem) {
        if managedObjectContext.hasChanges {
            do {
                try managedObjectContext.save()
            } catch {
                let saveError = error as NSError
                print("\(saveError), \(saveError.userInfo)")
            }
        }
        
        // Create Fetch Request
        let fetchRequest = NSFetchRequest(entityName: "Item")
        
        // Configure Fetch Request
        fetchRequest.predicate = NSPredicate(format: "done == 1")
        
        // Initialize Batch Delete Request
        let batchDeleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        
        // Configure Batch Update Request
        batchDeleteRequest.resultType = .ResultTypeCount
        
        do {
            // Execute Batch Request
            let batchDeleteResult = try managedObjectContext.executeRequest(batchDeleteRequest) as! NSBatchDeleteResult
            
            print("The batch delete request has deleted \(batchDeleteResult.result!) records.")
            
            // Reset Managed Object Context
            managedObjectContext.reset()
            
            // Perform Fetch
            try self.fetchedResultsController.performFetch()
            
            // Reload Table View
            tableView.reloadData()
            
        } catch {
            let updateError = error as NSError
            print("\(updateError), \(updateError.userInfo)")
        }
    }

    // MARK: -
    // MARK: Helper Methods
    private func seedPersistentStore() {
        // Create Entity Description
        let entityDescription = NSEntityDescription.entityForName("Item", inManagedObjectContext: managedObjectContext)
        
        for i in 0...15 {
            // Initialize Record
            let record = NSManagedObject(entity: entityDescription!, insertIntoManagedObjectContext: self.managedObjectContext)
            
            // Populate Record
            record.setValue((i % 3) == 0, forKey: "done")
            record.setValue(NSDate(), forKey: "createdAt")
            record.setValue("Item \(i + 1)", forKey: "name")
        }
        
        do {
            // Save Record
            try managedObjectContext?.save()
            
        } catch {
            let saveError = error as NSError
            print("\(saveError), \(saveError.userInfo)")
        }
    }

}
