//
//  Stormcloud.swift
//  Stormcloud
//
//  Created by Simon Fairbairn on 19/10/2015.
//  Copyright © 2015 Simon Fairbairn. All rights reserved.
//

import UIKit
import CoreData

// A simple protocol with an implementation in an extension that will help us manage the environment
public protocol StormcloudEnvironmentVariable  {
    func stringValue() -> String
}

public extension StormcloudEnvironmentVariable {
    func isEnabled() -> Bool {
        let env = NSProcessInfo.processInfo().environment
        if let _ = env[self.stringValue()]  {
            return true
        } else {
            return false
        }
    }
}

/**
A list of environment variables that you can use for debugging purposes.

 Usage:
 
1. `Product -> Scheme -> Edit Scheme...`
2. Under `Environment variables` tap the `+` icon
3. Add `Stormcloud` + the enum case (e.g. `StormcloudMangleDelete`) as the name field. No value is required.

Valid variables:

- **`StormcloudMangleDelete`** : Mangles a delete so you can test your apps response to errors correctly
- **`StormcloudVerboseLogging`** : More verbose output to see what's happening within Stormcloud
*/
enum StormcloudEnvironment : String, StormcloudEnvironmentVariable {
    case MangleDelete = "StormcloudMangleDelete"
    case VerboseLogging = "StormcloudVerboseLogging"
    func stringValue() -> String {
        return self.rawValue
    }
}

enum StormcloudEntityKeys : String {
    case EntityType = "com.voyagetravelapps.Stormcloud.entityType"
    case ManagedObject = "com.voyagetravelapps.Stormcloud.managedObject"
}

// Keys for NSUSserDefaults that manage iCloud state
enum StormcloudPrefKey : String {
    case iCloudToken = "com.voyagetravelapps.Stormcloud.iCloudToken"
    case isUsingiCloud = "com.voyagetravelapps.Stormcloud.usingiCloud"
    
}

/**
 *  Informs the delegate of changes made to the metadata list.
 */
@objc
public protocol StormcloudDelegate {
    func metadataListDidChange(manager : Stormcloud)
    func metadataListDidAddItemsAtIndexes( addedItems : NSIndexSet?, andDeletedItemsAtIndexes deletedItems: NSIndexSet?)
}

public class Stormcloud: NSObject {
    
    /// The file extension to use for the backup files
    public let fileExtension = "json"

    /// Whether or not the backup manager is currently using iCloud (read only)
    public var isUsingiCloud : Bool {
        get {
            return NSUserDefaults.standardUserDefaults().boolForKey(StormcloudPrefKey.isUsingiCloud.rawValue)
        }
    }
    
    /// A list of currently available backup metadata objects.
    public var metadataList : [StormcloudMetadata] {
        get {
            return self.backingMetadataList
        }
    }
    
    /// The backup manager delegate
    public var delegate : StormcloudDelegate?
    
    /// The number of files to keep before older ones are deleted. 0 = never delete.
    public var fileLimit : Int = 0
    
    var formatter = NSDateFormatter()
    
    var iCloudURL : NSURL?
    var metadataQuery : NSMetadataQuery = NSMetadataQuery()
    
    var backingMetadataList : [StormcloudMetadata] = []
    var internalMetadataList : [StormcloudMetadata] = []
    var internalQueryList : [String : StormcloudMetadata] = [:]
    var pauseMetadata : Bool = false
    
    var moveDocsToiCloud : Bool = false
    var moveDocsToiCloudCompletion : ((error : StormcloudError?) -> Void)?

    var operationInProgress : Bool = false
    
    var workingCache : [String : AnyObject] = [:]
    
    public override init() {
        super.init()
        if self.isUsingiCloud {
            self.enableiCloudShouldMoveLocalDocumentsToiCloud(false, completion: nil)
        }
        self.prepareDocumentList()
    }
    
    /**
     Reloads the current metadata list, either from iCloud or from local documents. If you are switching between storage locations, using the appropriate methods will automatically reload the list of documents so there's no need to call this.
     */
    public func reloadData() {
        self.prepareDocumentList()
    }
    
    /**
    Attempts to enable iCloud for document storage.
    
    - parameter move: Attept to move the documents from local storage to iCloud
    - parameter completion: A completion handler to be run when the move has finisehd
    
    - returns: true if iCloud was enabled, false otherwise
    */
    public func enableiCloudShouldMoveLocalDocumentsToiCloud(move : Bool, completion : ((error : StormcloudError?) -> Void)? ) -> Bool {
        let currentiCloudToken = NSFileManager.defaultManager().ubiquityIdentityToken
        
        // If we don't have a token, then we can't enable iCloud
        guard let token = currentiCloudToken  else {
            if let hasCompletion = completion {
                hasCompletion(error: StormcloudError.iCloudUnavailable)
            }
            
            disableiCloudShouldMoveiCloudDocumentsToLocal(false, completion: nil)
            return false
            
        }
        // Add observer for iCloud user changing
        NSNotificationCenter.defaultCenter().addObserver(self, selector: Selector("iCloudUserChanged:"), name: NSUbiquityIdentityDidChangeNotification, object: nil)
        
        let data = NSKeyedArchiver.archivedDataWithRootObject(token)
        NSUserDefaults.standardUserDefaults().setObject(data, forKey: StormcloudPrefKey.iCloudToken.rawValue)
        NSUserDefaults.standardUserDefaults().setBool(true, forKey: StormcloudPrefKey.isUsingiCloud.rawValue)
        
        
        // Make a note that we need to move documents once iCloud is initialised
        self.moveDocsToiCloud = move
        self.moveDocsToiCloudCompletion = completion
        
        self.prepareDocumentList()
        return true
    }
    
    /**
    Disables iCloud in favour of local storage
    
    - parameter move:       Pass true if you want the manager to attempt to copy any documents in iCloud to local storage
    - parameter completion: A completion handler to run when the attempt to copy documents has finished.
    */
    public func disableiCloudShouldMoveiCloudDocumentsToLocal( move : Bool, completion : ((moveSuccessful : Bool) -> Void)? ) {
        
        if move {
            // Handle the moving of documents
            self.moveItemsFromiCloud(self.backingMetadataList, completion: completion)
        }
        
        NSUserDefaults.standardUserDefaults().removeObjectForKey(StormcloudPrefKey.iCloudToken.rawValue)
        NSUserDefaults.standardUserDefaults().setBool(false, forKey: StormcloudPrefKey.isUsingiCloud.rawValue)
        NSNotificationCenter.defaultCenter().removeObserver(self, name: NSUbiquityIdentityDidChangeNotification, object: nil)
        
        
        self.metadataQuery.stopQuery()
        self.internalQueryList.removeAll()
        self.prepareDocumentList()
    }
    
    func moveItemsToiCloud( items : [String], completion : ((success : Bool, error : NSError?) -> Void)? ) {
        if let docsDir = self.documentsDirectory(), iCloudDir = iCloudDocumentsDirectory() {
            
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), { () -> Void in
                var success = true
                var hasError : NSError?
                for filename in items {
                    let finalURL = docsDir.URLByAppendingPathComponent(filename)
                    let finaliCloudURL = iCloudDir.URLByAppendingPathComponent(filename)
                    do {
                        try NSFileManager.defaultManager().setUbiquitous(true, itemAtURL: finalURL, destinationURL: finaliCloudURL)
                    } catch let error as NSError {
                        success = false
                        hasError = error
                    }
                }
                
                dispatch_async(dispatch_get_main_queue(), { () -> Void in
                    completion?(success: success, error: hasError)
                })
            })
        } else {
            let scError = StormcloudError.CouldntMoveDocumentToiCloud
            let error = scError.asNSError()
            completion?(success: false, error : error)
        }
    }
    
    func moveItemsFromiCloud( items : [StormcloudMetadata], completion : ((success : Bool ) -> Void)? ) {
        // Copy all of the local documents to iCloud
        if let docsDir = self.documentsDirectory(), iCloudDir = iCloudDocumentsDirectory() {
            
            let filenames = items.map { $0.filename }
            
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), { () -> Void in
                var success = true
                for element in filenames {
                    let finalURL = docsDir.URLByAppendingPathComponent(element)
                    let finaliCloudURL = iCloudDir.URLByAppendingPathComponent(element)
                    do {
                        self.stormcloudLog("Moving files from iCloud: \(finaliCloudURL) to local URL: \(finalURL)")
                        try NSFileManager.defaultManager().setUbiquitous(false, itemAtURL: finaliCloudURL, destinationURL: finalURL)
                    } catch {
                        success = false
                    }
                }
                
                dispatch_async(dispatch_get_main_queue(), { () -> Void in
                    self.prepareDocumentList()
                    completion?(success: success)
                })
            })
        } else {
            completion?(success: false)
        }
    }
    
    
    func iCloudUserChanged( notification : NSNotification ) {
        // Handle user changing
        
        self.prepareDocumentList()
        
    }
    
    deinit {
        self.metadataQuery.stopQuery()
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
    
}

// MARK: - Backup

extension Stormcloud {
    
    /**
     Backups the passed JSON objects to iCloud. Will also run a check to ensure that the objects are valid JSON, returning an error in the completion handler if there's a problem.
     
     - parameter objects:    A JSON object
     - parameter completion: A completion block that returns the new metadata if the backup was successful and a new document was created
     */
    public func backupObjectsToJSON( objects : AnyObject, completion : (error : StormcloudError?, metadata : StormcloudMetadata?) -> () ) {
        
        self.stormcloudLog("\(__FUNCTION__)")
        
        if self.operationInProgress {
            completion(error: .BackupInProgress, metadata: nil)
            return
        }
        self.operationInProgress = true
        
        
        if let baseURL = self.documentsDirectory() {
            let metadata = StormcloudMetadata()
            let finalURL = baseURL.URLByAppendingPathComponent(metadata.filename)
            
            let document = BackupDocument(fileURL: finalURL)
            
            self.stormcloudLog("Backing up to: \(finalURL)")
            
            document.objectsToBackup = objects
            
            // If the filename already exists, can't create a new document. Usually because it's trying to add them too quickly.
            let exists = self.internalMetadataList.filter({ (element) -> Bool in
                if element.filename == metadata.filename {
                    return true
                }
                return false
            })
            
            if exists.count > 0 {
                completion(error: .BackupFileExists, metadata: nil)
                return
            }
            document.saveToURL(finalURL, forSaveOperation: .ForCreating, completionHandler: { (success) -> Void in
                let totalSuccess = success
                
                if ( !totalSuccess ) {
                    
                    self.stormcloudLog("\(__FUNCTION__): Error saving new document")
                    
                    dispatch_async(dispatch_get_main_queue(), { () -> Void in
                        self.operationInProgress = false
                        completion(error : StormcloudError.CouldntSaveNewDocument, metadata: nil)
                    })
                    return
                    
                }
                document.closeWithCompletionHandler(nil)
                if !self.isUsingiCloud {
                    dispatch_async(dispatch_get_main_queue(), { () -> Void in
                        self.internalMetadataList.append(metadata)
                        self.prepareDocumentList()
                        self.operationInProgress = false
                        completion(error: nil, metadata: (totalSuccess) ? metadata : metadata)
                    })
                } else {
                    self.moveItemsToiCloud([metadata.filename], completion: { (success) -> Void in
                        dispatch_async(dispatch_get_main_queue(), { () -> Void in
                            
                            self.operationInProgress = false
                            if totalSuccess {
                                completion(error:  nil, metadata: metadata)
                            } else {
                                completion(error: StormcloudError.CouldntMoveDocumentToiCloud, metadata: metadata)
                            }
                            
                        })
                    })
                }
            })
        }
    }
    
    public func backupCoreDataEntities( inContext context : NSManagedObjectContext, completion : ( error : StormcloudError?, metadata : StormcloudMetadata?) -> () ) {
        
        self.stormcloudLog("Beginning backup of Core Data with context : \(context)")
        
        do {
            try context.save()
        } catch {
            stormcloudLog("Error saving context")
        }
        if self.operationInProgress {
            completion(error: .BackupInProgress, metadata: nil)
            return
        }
        self.operationInProgress = true
        
        let privateContext = NSManagedObjectContext(concurrencyType: .PrivateQueueConcurrencyType)
        privateContext.parentContext = context
        privateContext.performBlock { () -> Void in
            
            // Dictionaries are a list of all objects, with their ManagedObjectID as the key and a dictionary of their parts as the object
            var dictionary : [String : [ String : AnyObject ] ] = [:]
            
            if let entities = privateContext.persistentStoreCoordinator?.managedObjectModel.entities {
                
                self.formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZZZ"
                for entity in entities {
                    if let entityName = entity.name {
                        let request = NSFetchRequest(entityName: entityName)
                        
                        let allObjects : [NSManagedObject]
                        do {
                            allObjects = try privateContext.executeFetchRequest(request) as! [NSManagedObject]
                        } catch {
                            allObjects = []
                        }
                        
                        for object in allObjects {
                            let uriRepresentation = object.objectID.URIRepresentation().absoluteString
                            
                            var internalDictionary : [String : AnyObject] = [StormcloudEntityKeys.EntityType.rawValue : entityName]
                            
                            for propertyDescription in entity.properties {
                                if let attribute = propertyDescription as? NSAttributeDescription {
                                    internalDictionary[attribute.name] = self.getAttribute(attribute, fromObject: object)
                                }
                                
                                if let relationship = propertyDescription as? NSRelationshipDescription {
                                    var objectIDs : [String] = []
                                    if let objectSet =  object.valueForKey(relationship.name) as? NSSet, objectArray = objectSet.allObjects as? [NSManagedObject] {
                                        for object in objectArray {

                                            objectIDs.append(object.objectID.URIRepresentation().absoluteString)
                                        }
                                    }
                                    
                                    if let relationshipObject = object.valueForKey(relationship.name) as? NSManagedObject {
                                        let objectID = relationshipObject.objectID.URIRepresentation().absoluteString
                                        objectIDs.append(objectID)
                                        
                                    }
                                    internalDictionary[relationship.name] = objectIDs
                                }
                            }
                            dictionary[uriRepresentation] = internalDictionary
                            
                        }
                    }
                }
                if !NSJSONSerialization.isValidJSONObject(dictionary) {

                   self.stormcloudLog("\(__FUNCTION__) Error: Dictionary not valid: \(dictionary)")
                    
                    dispatch_async(dispatch_get_main_queue(), { () -> Void in
                        self.operationInProgress = false
                        completion(error: .InvalidJSON, metadata: nil)
                    })
                } else {
                    dispatch_async(dispatch_get_main_queue(), { () -> Void in
                        self.operationInProgress = false
                        self.backupObjectsToJSON(dictionary, completion: completion)
                    })
                }
            }
        }
    }
    
}


// MARK: - Core Data Methods

extension Stormcloud {
    func insertObjectsWithContext( context : NSManagedObjectContext, data : [String : AnyObject], completion : (success : Bool) -> ()  ) {
        
        stormcloudLog("\(__FUNCTION__)")
        
        let privateContext = NSManagedObjectContext(concurrencyType: .PrivateQueueConcurrencyType)
        privateContext.parentContext = context
        privateContext.performBlock { () -> Void in

            self.formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZZZ"
            
            var success = true
            
            // First we get all the objects
            // Then we delete them all!
            if let entities = privateContext.persistentStoreCoordinator?.managedObjectModel.entities {

                self.stormcloudLog("Found \(entities.count) entities:")
                
                for entity in entities {
                    if let entityName = entity.name {

                        self.stormcloudLog("\t\(entityName)")
                        
                        let request = NSFetchRequest(entityName: entityName)
                        
                        let allObjects : [NSManagedObject]
                        do {
                            allObjects = try privateContext.executeFetchRequest(request) as! [NSManagedObject]
                        } catch {
                            allObjects = []
                        }
                        
                        for object in allObjects {
                            privateContext.deleteObject(object)
                        }
                    }
                }
                
                // Push the changes to the store
                do {
                    try privateContext.save()
                } catch {
                    success = false
                    self.stormcloudLog("Error saving context")
                    abort()
                }
                
                context.performBlockAndWait({ () -> Void in
                    do {
                        try context.save()
                    } catch {
                        success = false
                        self.stormcloudLog("Error saving parent context")
                        abort()
                    }
                    
                    if let parentContext = context.parentContext {
                        do {
                            try parentContext.save()
                        } catch {
                            // TODO : Better error handling
                            self.stormcloudLog("Error saving top level")
                        }
                    }
                })
                
                var allObjects : [NSManagedObject] = []
                
                for (key, value) in data {
                    
                    if var dict = value as? [ String : AnyObject], let entityName = dict[StormcloudEntityKeys.EntityType.rawValue] as? String {
                        self.stormcloudLog("\tCreating entity \(entityName)")
                        
                        // At this point it will have a temporary ID
                        let object = NSEntityDescription.insertNewObjectForEntityForName(entityName, inManagedObjectContext: privateContext)
                        
                        dict[StormcloudEntityKeys.ManagedObject.rawValue] = object
                        
                        self.workingCache[key] = dict
                        
                        allObjects.append(object)
                        
                        for (propertyName, propertyValue ) in dict {
                            for propertyDescription in object.entity.properties {
                                if let attribute = propertyDescription as? NSAttributeDescription where propertyName == propertyDescription.name {
                                    
                                    self.stormcloudLog("\t\tFound attribute: \(propertyName)")
                                    
                                    self.setAttribute(attribute, onObject: object, withData: propertyValue)
                                }
                            }
                        }
                    }
                }

                self.stormcloudLog("\tAttempting to obtain permanent IDs...")
                do {
                    try privateContext.obtainPermanentIDsForObjects(allObjects)
                    self.stormcloudLog("\t\tSuccess")
                } catch {
                    self.stormcloudLog("\t\tCouldn't obtain permanent IDs")
                }
                
                if StormcloudEnvironment.VerboseLogging.isEnabled() {
                    
                    for object in allObjects {
                        self.stormcloudLog("\t\tIs Temporary ID: \(object.objectID.temporaryID)")
                        self.stormcloudLog("\t\t\tNew ID: \(object.objectID)")
                    }
                    
                }
                
                do {
                    try privateContext.save()
                } catch {
                    // TODO : Better error handling
                    self.stormcloudLog("Error saving during restore")
                }
                
                context.performBlockAndWait({ () -> Void in
                    do {
                        try context.save()
                    } catch {
                        // TODO : Better error handling
                        self.stormcloudLog("Error saving parent context")
                    }
                    if let parentContext = context.parentContext {
                        do {
                            try parentContext.save()
                        } catch {
                            // TODO : Better error handling
                            self.stormcloudLog("Error saving top level")
                        }
                    }
                    
                })
                
                
                // An array of managed objects, whose object IDs are now no good. 
                // A dictionary of the data, with one of the keys pointing to a managed object
                
                for (_, value) in self.workingCache {
                    if let dict = value as? [String : AnyObject], object = dict[StormcloudEntityKeys.ManagedObject.rawValue] as? NSManagedObject {
                        for propertyDescription in object.entity.properties {
                            if let relationship = propertyDescription as? NSRelationshipDescription {
                                self.setRelationship(relationship, onObject: object, withData : dict, inContext: privateContext)
                            }
                        }
                        
                    }
                }
                
                do {
                    try privateContext.save()
                } catch {
                    abort()
                }
                
                dispatch_async(dispatch_get_main_queue()) { () -> Void in
                    completion(success: success)
                }
                
            }
        }
    }
    
    func setRelationship( relationship : NSRelationshipDescription, onObject : NSManagedObject, withData data: [ String : AnyObject], inContext : NSManagedObjectContext ) {
        
        
        
        if let _ =  inContext.objectRegisteredForID(onObject.objectID) {
            
        } else {
            return;
        }
        
        if let relationshipIDs = data[relationship.name] as? [String] {
            var setObjects : [NSManagedObject] = []
            for id in relationshipIDs {
                
                
                
                if let cacheData = self.workingCache[id] as? [String : AnyObject], relatedObject = cacheData[StormcloudEntityKeys.ManagedObject.rawValue] as? NSManagedObject {
                    if !relationship.toMany {
                        self.stormcloudLog("\tRestoring To-one relationship \(onObject.entity.name) -> \(relationship.name)")
                        onObject.setValue(relatedObject, forKey: relationship.name)
                    } else {
                        setObjects.append(relatedObject)
                    }
                    
                }                
//                
//                if let url = NSURL(string: id), objectID = inContext.persistentStoreCoordinator?.managedObjectIDForURIRepresentation(url) {
//                    let relatedObject = inContext.objectWithID(objectID)
//
//                }
            }
            
            
            if relationship.toMany && setObjects.count > 0 {
                self.stormcloudLog("\tRestoring To-many relationship \(onObject.entity.name) ->> \(relationship.name) with \(setObjects.count) objects")
                if relationship.ordered {
                    
                    let set = NSOrderedSet(array: setObjects)
                    onObject.setValue(set, forKey: relationship.name)
                    
                } else {
                    let set = NSSet(array: setObjects)
                    onObject.setValue(set, forKey: relationship.name)
                }
                
            }
        }
    }
    
    
    func getAttribute( attribute : NSAttributeDescription, fromObject object : NSManagedObject ) -> AnyObject? {
        
        switch attribute.attributeType {
        case .Integer16AttributeType, .Integer32AttributeType,.Integer64AttributeType, .DoubleAttributeType, .FloatAttributeType, .StringAttributeType, .BooleanAttributeType :
            
            return object.valueForKey(attribute.name)
            
            
        case .DecimalAttributeType:
            
            if let decimal = object.valueForKey(attribute.name) as? NSDecimalNumber {
                return decimal.stringValue
            }
        case .DateAttributeType:
            if let date = object.valueForKey(attribute.name) as? NSDate {
                return formatter.stringFromDate(date)
            }
        case .BinaryDataAttributeType, .TransformableAttributeType:
            if let value = object.valueForKey(attribute.name) as? NSCoding {
                let mutableData = NSMutableData()
                let archiver = NSKeyedArchiver(forWritingWithMutableData: mutableData)
                archiver.encodeObject(value, forKey: attribute.name)
                archiver.finishEncoding()
                return mutableData.base64EncodedStringWithOptions(NSDataBase64EncodingOptions())
            }
        case .ObjectIDAttributeType, .UndefinedAttributeType:
            break
            
        }
        
        
        return nil
    }
    
    
    func setAttribute( attribute : NSAttributeDescription, onObject object : NSManagedObject,  withData data : AnyObject? ) {
        switch attribute.attributeType {
        case .Integer16AttributeType, .Integer32AttributeType,.Integer64AttributeType, .DoubleAttributeType, .FloatAttributeType:
            if let val = data as? NSNumber {
                object.setValue(val, forKey: attribute.name)
            } else {
                stormcloudLog("Setting Number : \(data) not Number")
            }
            
        case .DecimalAttributeType:
            if let val = data as? String {
                let decimal = NSDecimalNumber(string: val)
                object.setValue(decimal, forKey: attribute.name)
            } else {
                stormcloudLog("Setting Decimal : \(data) not String")
            }
            
        case .StringAttributeType:
            if let val = data as? String {
                object.setValue(val, forKey: attribute.name)
            } else {
                stormcloudLog("Setting String : \(data) not String")
            }
        case .BooleanAttributeType:
            if let val = data as? NSNumber {
                object.setValue(val.boolValue, forKey: attribute.name)
            } else {
                stormcloudLog("Setting Bool : \(data) not Number")
            }
        case .DateAttributeType:
            if let val = data as? String, date = self.formatter.dateFromString(val) {
                object.setValue(date, forKey: attribute.name)
            }
        case .BinaryDataAttributeType, .TransformableAttributeType:
            if let val = data as? String {
                let data = NSData(base64EncodedString: val, options: NSDataBase64DecodingOptions())
                let unarchiver = NSKeyedUnarchiver(forReadingWithData: data!)
                if let data = unarchiver.decodeObjectForKey(attribute.name) as? NSObject {
                    object.setValue(data, forKey: attribute.name)
                }
                unarchiver.finishDecoding()
            } else {
                stormcloudLog("Transformable/Binary type : \(data) not String")
            }
        case .ObjectIDAttributeType, .UndefinedAttributeType:
            break
            
        }
    }
    
    
}

// MARK: - Helper methods

extension Stormcloud {
    /**
     Gets the URL for a given StormcloudMetadata item. Will return either the local or iCloud URL.
     
     - parameter item: The item to get the URL for
     
     - returns: An optional NSURL, giving the location for the item
     */
    public func urlForItem(item : StormcloudMetadata) -> NSURL? {
        if self.isUsingiCloud {
            return self.iCloudDocumentsDirectory()?.URLByAppendingPathComponent(item.filename)
        } else {
            return self.documentsDirectory()?.URLByAppendingPathComponent(item.filename)
        }
    }
}


// MARK: - Restoring

extension Stormcloud {

    func mergeCoreDataBackup(withMetadata metadata : StormcloudMetadata, toContext context : NSManagedObjectContext, completion : (success : Bool ) -> () ) {
        
        
        do {
            try context.save()
        } catch {
            // TODO : Handle errors better
            stormcloudLog("Error saving context")
        }
        
        
        let privateContext = NSManagedObjectContext(concurrencyType: .PrivateQueueConcurrencyType)
        privateContext.parentContext = context
        privateContext.performBlock { () -> Void in
            
            
        }
    }
    
    
    
    /**
     Restores a JSON object from the given Stormcloud Metadata object
     
     - parameter metadata:        The Stormcloud metadata object that represents the document
     - parameter completion:      A completion handler to run when the operation is completed
     */
    public func restoreBackup(withMetadata metadata : StormcloudMetadata, completion : (error: StormcloudError?, restoredObjects : AnyObject? ) -> () ) {
        
        if self.operationInProgress {
            completion(error: .BackupInProgress, restoredObjects:  nil)
            return
        }
        self.operationInProgress = true
        
        if let url = self.urlForItem(metadata) {
            let document = BackupDocument(fileURL : url)
            document.openWithCompletionHandler({ (success) -> Void in
                
                if !success {
                    self.operationInProgress = false
                    completion(error: .CouldntOpenDocument, restoredObjects:  nil)
                    return
                }
                
                dispatch_async(dispatch_get_main_queue(), { () -> Void in
                    self.operationInProgress = false
                    completion(error: nil, restoredObjects: document.objectsToBackup)
                })
            })
        } else {
            self.operationInProgress = false
            completion(error: .InvalidURL, restoredObjects:  nil)
        }
    }
    
    /**
     Restores a backup to Core Data from a UIManagedDocument
     
     - parameter document:   The backup document to restore
     - parameter context:    The context to restore the objects to
     - parameter completion: A completion handler
     */
    public func restoreCoreDataBackup(withDocument document : BackupDocument, toContext context : NSManagedObjectContext,  completion : (error : StormcloudError?) -> () ) {
        if let data = document.objectsToBackup as? [String : AnyObject] {
            self.insertObjectsWithContext(context, data: data) { (success)  -> Void in
                self.operationInProgress = false
                let error : StormcloudError?  = (success) ? nil : StormcloudError.CouldntRestoreJSON
                completion(error: error)
            }
        } else {
            self.operationInProgress = false
            completion(error: .CouldntRestoreJSON)
        }
    }
    
    /**
     Restores a backup to Core Data from a StormcloudMetadata object
     
     - parameter metadata:  The metadata that represents the document
     - parameter context:    The context to restore the objects to
     - parameter completion: A completion handler
     */

    public func restoreCoreDataBackup(withMetadata metadata : StormcloudMetadata, toContext context : NSManagedObjectContext,  completion : (error : StormcloudError?) -> () ) {
        
        do {
            try context.save()
        } catch {
            // TODO : Handle errors better
            stormcloudLog("Error saving context")
        }
        
        if self.operationInProgress {
            completion(error: .BackupInProgress)
            return
        }
        self.operationInProgress = true
        
        if let url = self.urlForItem(metadata) {
            let document = BackupDocument(fileURL : url)
            document.openWithCompletionHandler({ (success) -> Void in
                
                if !success {
                    self.operationInProgress = true
                    completion(error: .CouldntOpenDocument)
                    return
                }
                
                dispatch_async(dispatch_get_main_queue(), { () -> Void in
                    
                    self.restoreCoreDataBackup(withDocument: document, toContext: context, completion: completion)
                })
            })
        } else {
            self.operationInProgress = false
            completion(error: .InvalidURL)
        }
    }
    
    public func deleteItemsOverLimit( completion : ( error : StormcloudError? ) -> () ) {
        
        // Knock one off as we're about to back up
        let limit = self.fileLimit - 1
        var itemsToDelete : [StormcloudMetadata] = []
        if self.fileLimit > 0 && self.metadataList.count > limit {
            for var i = limit; i < self.metadataList.count; i++ {
                let metadata = self.metadataList[i]
                itemsToDelete.append(metadata)
                
            }
        }
        
        for item in itemsToDelete {
            self.deleteItem(item, completion: { (index, error) -> () in
                if let hasError = error {
                    self.stormcloudLog("Error deleting: \(hasError.localizedDescription)")
                    completion(error: .CouldntDelete)
                }
            })
        }
        
    }
    
    public func deleteItems( metadataItems : [StormcloudMetadata], completion : (index : Int?, error : NSError? ) -> () ) {
        
        // Pull them out of the internal list first
        var urlList : [ NSURL : Int ] = [:]
        var errorList : [StormcloudMetadata] = []
        for item in metadataItems {
            if let itemURL = self.urlForItem(item), idx = self.internalMetadataList.indexOf(item) {
                urlList[itemURL] = idx
            } else {
                errorList.append(item)
            }
        }
        
        for (_, idx) in urlList {
            self.internalMetadataList.removeAtIndex(idx)
        }
        self.sortDocuments()

        // Remove them from the internal list
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), { () -> Void in
            
            // TESTING ENVIRONMENT
            if StormcloudEnvironment.MangleDelete.isEnabled() {
                sleep(2)
                dispatch_async(dispatch_get_main_queue(), { () -> Void in
                    let deleteError = StormcloudError.CouldntDelete
                    let error = NSError(domain:deleteError.domain(), code: deleteError.rawValue, userInfo: nil)
                    completion(index: nil, error: error )
                })
                return
            }
            // ENDs
            var hasError : NSError?
            for (url, _) in urlList {
                let coordinator = NSFileCoordinator(filePresenter: nil)
                coordinator.coordinateWritingItemAtURL(url, options: .ForDeleting, error:nil, byAccessor: { (url) -> Void in

                    do {
                        try NSFileManager.defaultManager().removeItemAtURL(url)
                    } catch let error as NSError  {
                        hasError = error
                    }
                    
                })
                
                if hasError != nil {
                    break
                }
                
            }
            dispatch_async(dispatch_get_main_queue(), { () -> Void in
                completion(index : nil, error: hasError)

            })
        })

        
//
//        if let itemURL = self.urlForItem(metadataItem), let idx = self.internalMetadataList.indexOf(metadataItem) {
//            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), { () -> Void in
//                
//                // TESTING ENVIRONMENT
//                if StormcloudEnvironment.MangleDelete.isEnabled() {
//                    sleep(2)
//                    dispatch_async(dispatch_get_main_queue(), { () -> Void in
//                        let deleteError = StormcloudError.CouldntDelete
//                        let error = NSError(domain:deleteError.domain(), code: deleteError.rawValue, userInfo: nil)
//                        completion(index: nil, error: error )
//                    })
//                    return
//                }
//                // ENDs
//                
//                let coordinator = NSFileCoordinator(filePresenter: nil)
//                coordinator.coordinateWritingItemAtURL(itemURL, options: .ForDeleting, error:nil, byAccessor: { (url) -> Void in
//                    var hasError : NSError?
//                    do {
//                        try NSFileManager.defaultManager().removeItemAtURL(url)
//                    } catch let error as NSError  {
//                        hasError = error
//                    }
//                    dispatch_async(dispatch_get_main_queue(), { () -> Void in
//                        self.internalMetadataList.removeAtIndex(idx)
//                        completion(index : (hasError != nil) ? idx : nil, error: hasError)
//                        self.sortDocuments()
//                    })
//                })
//            })
//        } else {
//            
//
//        }
    }
    
    
    
    /**
     Deletes the document represented by the metadataItem object
     
     - parameter metadataItem: The Stormcloud Metadata object that represents the document
     - parameter completion:   The completion handler to run when the delete completes
     */
    public func deleteItem(metadataItem : StormcloudMetadata, completion : (index : Int?, error : NSError?) -> () ) {
        self.deleteItems([metadataItem], completion: completion)
    }
}


// MARK: - Prepare Documents

extension Stormcloud {
    
    
    func prepareDocumentList() {
        
        self.internalQueryList.removeAll()
        self.internalMetadataList.removeAll()
        self.sortDocuments()
        if self.isUsingiCloud  {
            
            var myContainer : NSURL?
            dispatch_async(dispatch_get_global_queue (DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) { () -> Void in
                
                myContainer = NSFileManager.defaultManager().URLForUbiquityContainerIdentifier(nil)
                self.iCloudURL = myContainer
                
                var stormcloudError : StormcloudError?
                if self.moveDocsToiCloud {
                    if let iCloudDir = self.iCloudDocumentsDirectory() {
                        for fileURL in self.listLocalDocuments() {
                            if fileURL.pathExtension == self.fileExtension {
                                if let finalPath = fileURL.lastPathComponent {
                                    let finaliCloudURL = iCloudDir.URLByAppendingPathComponent(finalPath)
                                    do {
                                        try NSFileManager.defaultManager().setUbiquitous(true, itemAtURL: fileURL, destinationURL: finaliCloudURL)
                                    } catch {
                                        stormcloudError = StormcloudError.CouldntMoveDocumentToiCloud
                                    }
                                }
                            }
                        }
                    }
                    self.moveDocsToiCloud = false
                }
                
                dispatch_async(dispatch_get_main_queue(), { () -> Void in
                    
                    // Start metadata search
                    self.loadiCloudDocuments()
                    // Set URL

                    // If we have a completion handler from earlier
                    if let completion = self.moveDocsToiCloudCompletion {
                        completion(error : stormcloudError)
                        self.moveDocsToiCloudCompletion = nil;
                    }
                    
                })
            }
        } else {
            self.loadLocalDocuments()
        }
    }
    
    func sortDocuments() {
        
        
        //        dispatch_async(dispatch_get_main_queue(), { () -> Void in
        self.internalMetadataList.sortInPlace { (element1, element2) -> Bool in
            if element2.date.earlierDate(element1.date).isEqualToDate(element2.date) {
                return true
            }
            return false
        }
        
        // Has anything been removed? Filter out anything from the documents that isn't in the manager
        let removeItems = self.backingMetadataList.filter { (element) -> Bool in
            if self.internalMetadataList.contains(element) {
                return false
            }
            return true
        }
        
        let indexesToDelete = NSMutableIndexSet()
        
        for item in removeItems {
            if let idx = self.backingMetadataList.indexOf(item) {
                indexesToDelete.addIndex(idx)
            }
        }
        
        
        let sortedIndexes = indexesToDelete.sort { (index1, index2) -> Bool in
            return index1 > index2
        }
        for idx in sortedIndexes {
            self.backingMetadataList.removeAtIndex(idx)
        }
        
        
        // Has anything been added?
        let indexesToAdd = NSMutableIndexSet()
        let addedItems = self.internalMetadataList.filter { (element) -> Bool in
            if self.backingMetadataList.contains(element ) {
                return false
            }
            return true
        }
        for item in addedItems {
            if let idx = self.internalMetadataList.indexOf(item) {
                indexesToAdd.addIndex(idx)
                let item = self.internalMetadataList[idx]
                self.backingMetadataList.insert(item, atIndex: idx)
            }
        }
        self.delegate?.metadataListDidAddItemsAtIndexes((indexesToAdd.count > 0 ) ? indexesToAdd : nil, andDeletedItemsAtIndexes: (indexesToDelete.count > 0) ? indexesToDelete : nil)
        
        //        })
    }
    
    
}

// MARK: - Local Document Handling

extension Stormcloud {

    func listLocalDocuments() -> [NSURL] {
        let docs : [NSURL]
        if let url = self.documentsDirectory()  {
            
            do {
                docs = try NSFileManager.defaultManager().contentsOfDirectoryAtURL(url, includingPropertiesForKeys: nil, options: NSDirectoryEnumerationOptions())
            } catch {
                stormcloudLog("Error listing contents of \(url)")
                
                docs = []
            }
        } else {
            docs = []
        }
        return docs
    }
    
    func loadLocalDocuments() {
        for fileURL in self.listLocalDocuments() {
            if fileURL.pathExtension == self.fileExtension {
                let backup = StormcloudMetadata(fileURL: fileURL)
                self.internalMetadataList.append(backup)
                self.sortDocuments()
            }
        }
    }
    
    
    func documentsDirectory() -> NSURL? {
        if let docsURL = NSFileManager.defaultManager().URLsForDirectory(NSSearchPathDirectory.DocumentDirectory, inDomains: .UserDomainMask).first {
            return docsURL
        }
        return nil
    }
}

// MARK: - iCloud Document Handling

extension Stormcloud {
    
    func loadiCloudDocuments() {

        if self.metadataQuery.stopped {
            stormcloudLog("Metadata query stopped")
            self.metadataQuery.startQuery()
            return
        }
        
        if self.metadataQuery.gathering {
            stormcloudLog("Metadata query gathering")
            return
        }
        
        stormcloudLog("Beginning metadata query")
        
        self.metadataQuery.searchScopes = [NSMetadataQueryUbiquitousDocumentsScope]
        self.metadataQuery.predicate = NSPredicate(format: "%K CONTAINS '.json'", NSMetadataItemFSNameKey)
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: Selector("metadataFinishedGathering"), name:NSMetadataQueryDidFinishGatheringNotification , object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: Selector("metadataUpdated"), name:NSMetadataQueryDidUpdateNotification, object: nil)
        
        self.metadataQuery.startQuery()
    }
    
    func iCloudDocumentsDirectory() -> NSURL? {
        if self.isUsingiCloud {
            if let hasiCloudDir = self.iCloudURL {
                return hasiCloudDir.URLByAppendingPathComponent("Documents")
            }
        }
        return nil
    }
    
    func metadataFinishedGathering() {
        
        stormcloudLog("Metadata finished gathering")
        
//        self.metadataQuery.stopQuery()
        self.metadataUpdated()
    }
    
    func metadataUpdated() {
        
        stormcloudLog("Metadata updated")
        
        if let items = self.metadataQuery.results as? [NSMetadataItem] {
            
            stormcloudLog("Metadata query found \(items.count) items")
            
            for item in items {
                if let fname = item.valueForAttribute(NSMetadataItemDisplayNameKey) as? String {
                    
                    if let hasBackup = self.internalQueryList[fname] {
                        hasBackup.iCloudMetadata = item
                    } else {
                        if let url = item.valueForAttribute(NSMetadataItemURLKey) as? NSURL {
                            let backup = StormcloudMetadata(fileURL: url)
                            backup.iCloudMetadata = item
                            self.internalMetadataList.append(backup)
                            self.internalQueryList[fname] = backup
                        }
                    }
                }
            }
        }
        self.sortDocuments()
    }
}

extension Stormcloud {
    func stormcloudLog( string : String ) {
        if StormcloudEnvironment.VerboseLogging.isEnabled() {
            print(string)
        }
    }
    
}



