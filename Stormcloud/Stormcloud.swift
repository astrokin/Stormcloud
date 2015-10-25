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
    
    var formatter = NSDateFormatter()
    
    var iCloudURL : NSURL?
    var metadataQuery : NSMetadataQuery = NSMetadataQuery()
    
    var backingMetadataList : [StormcloudMetadata] = []
    var internalMetadataList : [StormcloudMetadata] = []
    var internalQueryList : [String : StormcloudMetadata] = [:]
    var pauseMetadata : Bool = false
    
    var moveDocsToiCloud : Bool = false
    var moveDocsToiCloudCompletion : ((error : StormcloudError?) -> Void)?

    
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
                        // TODO: Better error handling with enum in closure
                        success = false
                        hasError = error
                    }
                }
                
                dispatch_async(dispatch_get_main_queue(), { () -> Void in
                    completion?(success: success, error: hasError)
                })
            })
        } else {
            let error = NSError(domain: "Stormcloud", code: 10, userInfo: [NSLocalizedDescriptionKey : "Couldn't get valid iCloud and local documents directories"])
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
                        //                        print("Moving files from iCloud: \(finaliCloudURL) to local URL: \(finalURL)")
                        try NSFileManager.defaultManager().setUbiquitous(false, itemAtURL: finaliCloudURL, destinationURL: finalURL)
                    } catch {
                        // TODO: Better error handling with enum in closure
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
    }
    
    deinit {
        self.metadataQuery.stopQuery()
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
    
}

// MARK: - Handle backup and restore

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
    
    /**
     Backups the passed JSON objects to iCloud. Will also run a check to ensure that the objects are valid JSON, returning an error in the completion handler if there's a problem.
     
     - parameter objects:    A JSON object
     - parameter completion: A completion block that returns the new metadata if the backup was successful and a new document was created
     */
    public func backupObjectsToJSON( objects : AnyObject, completion : (success : Bool, error : StormcloudError?, metadata : StormcloudMetadata?) -> () ) {
        
        if let baseURL = self.documentsDirectory() {
            let metadata = StormcloudMetadata()
            let finalURL = baseURL.URLByAppendingPathComponent(metadata.filename)
            
            let document = BackupDocument(fileURL: finalURL)
            
            document.objectsToBackup = objects
            
            // If the filename already exists, can't create a new document. Usually because it's trying to add them too quickly.
            let exists = self.internalMetadataList.filter({ (element) -> Bool in
                if element.filename == metadata.filename {
                    return true
                }
                return false
            })
            
            if exists.count > 0 {
                completion(success: false, error: .BackupFileExists, metadata: nil)
                return
            }
            document.saveToURL(finalURL, forSaveOperation: .ForCreating, completionHandler: { (success) -> Void in
                let totalSuccess = success
                
                if ( !totalSuccess ) {
                    if StormcloudEnvironment.VerboseLogging.isEnabled() {
                        print("\(__FUNCTION__): Error saving new document")
                    }
                    completion(success: totalSuccess, error : StormcloudError.CouldntSaveNewDocument, metadata: nil)
                    return
                    
                }
                document.closeWithCompletionHandler(nil)
                if !self.isUsingiCloud {
                    dispatch_async(dispatch_get_main_queue(), { () -> Void in
                        self.internalMetadataList.append(metadata)
                        
                        self.prepareDocumentList()
                        
                        completion(success: totalSuccess, error: nil, metadata: (totalSuccess) ? metadata : metadata)
                    })
                } else {
                    
                    self.moveItemsToiCloud([metadata.filename], completion: { (success) -> Void in
                        
                        dispatch_async(dispatch_get_main_queue(), { () -> Void in
                            
                            if totalSuccess {
                                completion(success: totalSuccess, error:  nil, metadata: metadata)
                            } else {
                                completion(success: totalSuccess, error: StormcloudError.CouldntMoveDocumentToiCloud, metadata: metadata)
                            }
                            
                        })
                    })
                }
            })
        }
    }
    
    func restoreBackup(withMetadata metadata : StormcloudMetadata, completion : (success : Bool, restoredObjects : AnyObject? ) -> () ) {
        
        
        
    }
    
    
    public func backupCoreDataEntities( inContext context : NSManagedObjectContext, completion : ( success : Bool, error : StormcloudError?, metadata : StormcloudMetadata?) -> () ) {
        
        do {
            try context.save()
        } catch {
            print("Error saving context")
        }
        
        
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
                    // TODO: Handle errors elegantly and remove abort
                    
                    if StormcloudEnvironment.VerboseLogging.isEnabled() {
                        print("\(__FUNCTION__) Error: Dictionary not valid: \(dictionary)")
                    }
                    
                    dispatch_async(dispatch_get_main_queue(), { () -> Void in
                        completion(success: false, error: .InvalidJSON, metadata: nil)
                    })
                } else {
                    dispatch_async(dispatch_get_main_queue(), { () -> Void in
                        self.backupObjectsToJSON(dictionary, completion: completion)
                    })
                }
            }
        }
    }
    
    public func mergeCoreDataBackup(withMetadata metadata : StormcloudMetadata, toContext context : NSManagedObjectContext, completion : (success : Bool ) -> () ) {
        
        
        do {
            try context.save()
        } catch {
            // TODO : Handle errors better
            print("Error saving context")
        }
        
        
        let privateContext = NSManagedObjectContext(concurrencyType: .PrivateQueueConcurrencyType)
        privateContext.parentContext = context
        privateContext.performBlock { () -> Void in
            
            
        }
    }
    
    public func restoreCoreDataBackup(withDocument document : BackupDocument, toContext context : NSManagedObjectContext,  completion : (success : Bool) -> () ) {
        if let data = document.objectsToBackup as? [String : AnyObject] {
            self.insertObjectsWithContext(context, data: data) { (success)  -> Void in
                completion(success: success)
            }
        } else {
            completion(success: false)
        }
    }
    
    
    public func restoreCoreDataBackup(withMetadata metadata : StormcloudMetadata, toContext context : NSManagedObjectContext,  completion : (success : Bool) -> () ) {
        
        do {
            try context.save()
        } catch {
            // TODO : Handle errors better
            print("Error saving context")
        }
        if let url = self.urlForItem(metadata) {
            let document = BackupDocument(fileURL : url)
            document.openWithCompletionHandler({ (success) -> Void in
                
                if !success {
                    completion(success: success)
                    return
                }
                
                dispatch_async(dispatch_get_main_queue(), { () -> Void in
                    
                    self.restoreCoreDataBackup(withDocument: document, toContext: context, completion: completion)
                })
            })
        }
    }
    
    func insertObjectsWithContext( context : NSManagedObjectContext, data : [String : AnyObject], completion : (success : Bool) -> ()  ) {
        
        let privateContext = NSManagedObjectContext(concurrencyType: .PrivateQueueConcurrencyType)
        privateContext.parentContext = context
        privateContext.performBlock { () -> Void in
            
            self.formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZZZ"
            
            var success = true
            // First we get all the objects
            // Then we delete them all!
            
            if let entities = privateContext.persistentStoreCoordinator?.managedObjectModel.entities {
                
                
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
                            privateContext.deleteObject(object)
                        }
                    }
                }
                
                do {
                    try privateContext.save()
                } catch {
                    success = false
                    abort()
                }
                
                var allObjects : [NSManagedObject] = []
                
                var testObject : NSManagedObject?
                
                for (key, value) in data {
                    if let url = NSURL(string: key), objectID = privateContext.persistentStoreCoordinator?.managedObjectIDForURIRepresentation(url) {
                        let object = privateContext.objectWithID(objectID)
                        privateContext.insertObject(object)

                        
                        // TESTING
                        if let _ = testObject {
                            
                        } else {
                            testObject = object
                            print("Test object has id: \(testObject!.objectID.URIRepresentation().absoluteString)")
                        }
                        
                        
                        

                        
                        allObjects.append(object)
                        
                        if let dict = value as? [String : AnyObject] {
                            for (propertyName, propertyValue ) in dict {
                                for propertyDescription in object.entity.properties {
                                    if let attribute = propertyDescription as? NSAttributeDescription where propertyName == propertyDescription.name {
                                        self.setAttribute(attribute, onObject: object, withData: propertyValue)
                                    }
                                }
                            }
                        }
                    }
                }
                do {
                    try privateContext.save()
                } catch {
                    // TODO : Better error handling
                    print("Error saving during restore")
                }
                
                // TESTING
                print("After save: \(testObject!.objectID.URIRepresentation().absoluteString)")
                
                for object in allObjects {
                    if let relationshipData = data[object.objectID.URIRepresentation().absoluteString] as? [String : AnyObject] {

                        for propertyDescription in object.entity.properties {
                            if let relationship = propertyDescription as? NSRelationshipDescription {
                                self.setRelationship(relationship, onObject: object, withData : relationshipData, inContext: privateContext)
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
        
        if let relationshipIDs = data[relationship.name] as? [String] {
                var setObjects : [NSManagedObject] = []
            for id in relationshipIDs {

                
                if let url = NSURL(string: id), objectID = inContext.persistentStoreCoordinator?.managedObjectIDForURIRepresentation(url) {
                    let relatedObject = inContext.objectWithID(objectID)
                    if !relationship.toMany {
                        let name = relatedObject.valueForKey("name")
                        let relatedName = onObject.valueForKey("type")
                        print("Added \(name) to \(relatedName)")
                        
                        onObject.setValue(relatedObject, forKey: relationship.name)
                        
                    } else {
                        setObjects.append(relatedObject)
                    }
                }
            }
            if relationship.toMany {
                if relationship.ordered {
                    let set = NSOrderedSet(array: setObjects)
                    onObject.setValue(set, forKey: relationship.name)
                    
                } else {
                    let set = NSSet(array: setObjects)
                    onObject.setValue(set, forKey: relationship.name)
                    let name = onObject.valueForKey("name")
                    print("Added \(setObjects.count) objects to \(name)")
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
                print("Setting Number : \(data) not Number")
            }
            
        case .DecimalAttributeType:
            if let val = data as? String {
                let decimal = NSDecimalNumber(string: val)
                object.setValue(decimal, forKey: attribute.name)
            } else {
                print("Setting Decimal : \(data) not String")
            }
            
        case .StringAttributeType:
            if let val = data as? String {
                object.setValue(val, forKey: attribute.name)
            } else {
                print("Setting String : \(data) not String")
            }
        case .BooleanAttributeType:
            if let val = data as? NSNumber {
                object.setValue(val.boolValue, forKey: attribute.name)
            } else {
                print("Setting Bool : \(data) not Number")
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
                print("Transformable/Binary type : \(data) not String")
            }
        case .ObjectIDAttributeType, .UndefinedAttributeType:
            break
            
        }
    }
    
    
    public func deleteItem(metadataItem : StormcloudMetadata, completion : (index : Int?, error : NSError?) -> () ) {
        
        if let itemURL = self.urlForItem(metadataItem), let idx = self.internalMetadataList.indexOf(metadataItem) {
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
                
                let coordinator = NSFileCoordinator(filePresenter: nil)
                coordinator.coordinateWritingItemAtURL(itemURL, options: .ForDeleting, error:nil, byAccessor: { (url) -> Void in
                    var hasError : NSError?
                    do {
                        try NSFileManager.defaultManager().removeItemAtURL(url)
                        self.internalMetadataList.removeAtIndex(idx)
                    } catch let error as NSError  {
                        // TODO: More information for error handling. Custom enum and error in completion block
                        hasError = error
                    }
                    dispatch_async(dispatch_get_main_queue(), { () -> Void in
                        
                        
                        completion(index : (hasError != nil) ? idx : nil, error: hasError)
                        self.sortDocuments()
                    })
                })
                
                
            })
        } else {

            let urlError = StormcloudError.InvalidURL
            let error = NSError(domain: urlError.domain(), code: urlError.rawValue, userInfo: [NSLocalizedDescriptionKey : "Couldn't get a valid URL for the item"])
            completion(index : nil, error : error)
        }
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
    
    
    // TODO: Rethrow this
    func listLocalDocuments() -> [NSURL] {
        let docs : [NSURL]
        if let url = self.documentsDirectory()  {
            
            do {
                docs = try NSFileManager.defaultManager().contentsOfDirectoryAtURL(url, includingPropertiesForKeys: nil, options: NSDirectoryEnumerationOptions())
            } catch {
                
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
            if StormcloudEnvironment.VerboseLogging.isEnabled() {
                print("Metadata query stopped")
                self.metadataQuery.startQuery()
                return
            }
        }
        
        if self.metadataQuery.gathering {
            if StormcloudEnvironment.VerboseLogging.isEnabled() {
                print("Metadata query gathering")
            }
            return
        }

        if StormcloudEnvironment.VerboseLogging.isEnabled() {
            print("Beginning metadata query")
        }

        
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
        
        if StormcloudEnvironment.VerboseLogging.isEnabled() {
            print("Metadata finished gathering")
        }
        
//        self.metadataQuery.stopQuery()
        self.metadataUpdated()
    }
    
    func metadataUpdated() {
        
        if StormcloudEnvironment.VerboseLogging.isEnabled() {
            print("Metadata updated")
        }
        
        if let items = self.metadataQuery.results as? [NSMetadataItem] {
            
            if StormcloudEnvironment.VerboseLogging.isEnabled() {
                print("Metadata query found \(items.count) items")
            }
            
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

