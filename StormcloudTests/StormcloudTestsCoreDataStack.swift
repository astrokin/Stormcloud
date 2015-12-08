//
//  StormcloudTestsCoreDataStack.swift
//  Stormcloud
//
//  Created by Simon Fairbairn on 21/10/2015.
//  Copyright © 2015 Simon Fairbairn. All rights reserved.
//

import CoreData
import Stormcloud




public enum CoreDataStackEnvironmentVariables : String, StormcloudEnvironmentVariable {
    case UseMemoryStore = "StormcloudUseMemoryStore"
    
    public func stringValue() -> String {
        return self.rawValue
    }
}

public protocol CoreDataStackFetchTemplate {
    func fetchRequestName() -> String
    
}

public protocol CoreDataStackDelegate {
    /**
     The location where you would like the SQLite database stored. Default is application document's directory, return nil to keep it there
     */
    func storeDirectory() -> NSURL?
}

public class CoreDataStack {
    
    public var delegate : CoreDataStackDelegate?
    
    /// If you have a store you want to copy from elsewhere (e.g. a default store in your bundle), set this before running `setupStore`
    public var copyDefaultStoreFromURL: NSURL?
    
    /// Whether to enable journalling on your SQLite database
    public var journalling: Bool = true
    
    /// The managed object context for this stack
    public var managedObjectContext : NSManagedObjectContext?
    
    internal var privateContext : NSManagedObjectContext?
    
    internal var callback : (() -> Void)?
    
    internal  let modelName : String
    
    internal var persistentStoreCoordinator: NSPersistentStoreCoordinator?
    
    /**
     Initialises the core data stack, setting up the managed object model, the managed object contexts, and the persistent store coordinator.
     
     This method does NOT attach a persistent store to the coordinator. You will need to run setupStore in order to finish setting up the store.
     
     - parameter modelName: The name of the xcdatamodeld file to use. Also forms the basis for the name of the sqlite database
     
     */
    public init( modelName : String ) {
        self.modelName = modelName
        initialiseCoreData()
    }
    
    public func performRequestForTemplate( template : CoreDataStackFetchTemplate ) -> [NSManagedObject] {
        let results : [NSManagedObject]
        if let fetchRequest = self.persistentStoreCoordinator?.managedObjectModel.fetchRequestTemplateForName(template.fetchRequestName()), context = self.managedObjectContext {
            do {
                results = try context.executeFetchRequest(fetchRequest) as! [NSManagedObject]
            } catch {
                results = []
                print("Error fetching unit")
            }
        } else {
            results = []
        }
        return results
    }
    
    /**
     Call this to finish setting up the store once you've set any additional properties.
     
     - parameter callback: The callback you want to run once the store is set up. Runs on the main thread.
     */
    public func setupStore(callback : (() -> Void)?) {
        
        self.callback = callback
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0)) { () -> Void in
            
            let storeURL = self.applicationDocumentsDirectory().URLByAppendingPathComponent("\(self.modelName).sqlite")
            
            //            sleep(400)
            
            // Try to copy the database from the bundle.
            if let defaultStoreURL = self.copyDefaultStoreFromURL {
                
                print("Attempting to copy store from: \(defaultStoreURL)\nto:\(storeURL)")
                do {
                    try NSFileManager.defaultManager().copyItemAtURL(defaultStoreURL, toURL: storeURL)
                } catch let error as NSError {
                    print("Store already exists")
                    if error.code != 516 {
                        print("Error copying store: \(error.localizedDescription), code: \(error.code)")
                    }
                } catch {
                    print("Unknown file error")
                }
            }
            
            if CoreDataStackEnvironmentVariables.UseMemoryStore.isEnabled() {
                do {
                    try self.persistentStoreCoordinator!.addPersistentStoreWithType(NSInMemoryStoreType, configuration: nil, URL: storeURL, options:self.storeOptions())
                    
                    print("Successfully attached in-memory store")
                    
                } catch let error as NSError {
                    print("Error adding in-memory persistent store: \(error.localizedDescription)\n\(error.userInfo)")
                    abort()
                }
            } else {
                do {
                    try self.persistentStoreCoordinator!.addPersistentStoreWithType(NSSQLiteStoreType, configuration: nil, URL: storeURL, options:self.storeOptions())
                    
                    print("Successfully attached SQL store")
                    
                } catch let error as NSError {
                    print("Error adding SQL persistent store: \(error.localizedDescription)\n\(error.userInfo)")
                    abort()
                }
            }

			if let callback = self.callback {
                dispatch_sync(dispatch_get_main_queue(), { () -> Void in
                    callback()
                })
            }
        }
    }
    
    /**
     Saves the managed object contexts
     */
    public func save() {
        if self.managedObjectContext?.hasChanges == false && self.privateContext?.hasChanges == false {
            return
        }
        self.managedObjectContext?.performBlockAndWait { () -> Void in
            do {
                try self.managedObjectContext?.save()
            } catch let error as NSError {
                print("Error: \(error.localizedDescription)\n\(error.userInfo)")
                abort()
            } catch {
                print("Error saving")
                abort()
            }
            
            self.privateContext?.performBlock({ () -> Void in
                do {
                    try self.privateContext?.save()
                } catch let error as NSError {
                    print("Error saving private context: \(error.localizedDescription)\n\(error.userInfo)")
                    abort()
                } catch {
                    print("Error saving private context")
                    abort()
                }
            })
        }
    }
    
    
    
    @available(iOS 9.0, OSX 10.11, *)
    public func replaceStore() {
        save()
        let storeURL = self.applicationDocumentsDirectory().URLByAppendingPathComponent("\(self.modelName).sqlite")
        do {
            if let sourceStore = NSBundle.mainBundle().URLForResource(self.modelName, withExtension: "sqlite") {
                try persistentStoreCoordinator?.replacePersistentStoreAtURL(storeURL, destinationOptions: self.storeOptions(), withPersistentStoreFromURL: sourceStore, sourceOptions: self.storeOptions(), storeType: NSSQLiteStoreType)
                print("Store replaced")
            } else {
                print("No replacement found")
            }
        } catch {
            print("Error deleting store")
        }
    }
    
    /**
     Use this for versions of iOS < 9.0 and OS X < 10.11 to delete the store files.
     */
    public func deleteStore() {
        save()
        
        print("Deleting store")
        
        managedObjectContext = nil
        privateContext = nil
        
        let storeURL = self.applicationDocumentsDirectory().URLByAppendingPathComponent("\(self.modelName).sqlite")
        
        if #available(iOS 9.0, OSX 10.9, *) {
            
            do {
                try  self.persistentStoreCoordinator?.destroyPersistentStoreAtURL(storeURL, withType: NSSQLiteStoreType, options: self.storeOptions())
            } catch {
                print("Couldn't delete store")
            }
            
            
            persistentStoreCoordinator = nil
        } else {
            
            let walURL = self.applicationDocumentsDirectory().URLByAppendingPathComponent("\(self.modelName).sqlite-wal")
            let shmURL = self.applicationDocumentsDirectory().URLByAppendingPathComponent("\(self.modelName).sqlite-shm")
            
            
            do {
                try NSFileManager.defaultManager().removeItemAtURL(storeURL)
                try NSFileManager.defaultManager().removeItemAtURL(walURL)
                try NSFileManager.defaultManager().removeItemAtURL(shmURL)
            } catch let error as NSError {
                print("Error deleting store files: \(error.localizedDescription)")
            }
            
        }
        
        
        initialiseCoreData()
    }
    
    
    internal func storeOptions() -> [ NSObject : AnyObject ] {
        var options = [ NSObject : AnyObject ]()
        options = [NSMigratePersistentStoresAutomaticallyOption : true]
        if !self.journalling {
            options[ NSSQLitePragmasOption ] = [ "journal_mode" : "DELETE" ]
        }
        return options
    }
    
    internal func applicationDocumentsDirectory() -> NSURL {
        guard let theDelegate = delegate, storeURL = theDelegate.storeDirectory() else {
            let filemanager = NSFileManager.defaultManager()
            let urls = filemanager.URLsForDirectory(.DocumentDirectory, inDomains: .UserDomainMask) as [NSURL]
            return urls[0]
        }
        return storeURL
    }
    
    internal func initialiseCoreData() {
        
        if self.managedObjectContext != nil {
            return
        }
        
        print("Setting up PSC")
        
        let bundle = NSBundle(forClass: CoreDataStack.self)
        
        guard let model =             NSManagedObjectModel.mergedModelFromBundles([bundle]) else {
            abort()
        }
        self.persistentStoreCoordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
        
        self.managedObjectContext = NSManagedObjectContext(concurrencyType: .MainQueueConcurrencyType)
        self.privateContext = NSManagedObjectContext(concurrencyType: .PrivateQueueConcurrencyType)
        self.privateContext!.persistentStoreCoordinator = self.persistentStoreCoordinator
        
        self.managedObjectContext?.parentContext = privateContext
    }
    
    
    
}
























