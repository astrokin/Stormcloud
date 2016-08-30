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
        let env = ProcessInfo.processInfo.environment
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
    func metadataListDidChange(_ manager : Stormcloud)
    func metadataListDidAddItemsAtIndexes( _ addedItems : IndexSet?, andDeletedItemsAtIndexes deletedItems: IndexSet?)
}

open class Stormcloud: NSObject {
    
    /// The file extension to use for the backup files
    open let fileExtension = "json"

    /// Whether or not the backup manager is currently using iCloud (read only)
    open var isUsingiCloud : Bool {
        get {
            return UserDefaults.standard.bool(forKey: StormcloudPrefKey.isUsingiCloud.rawValue)
        }
    }
    
    /// A list of currently available backup metadata objects.
    open var metadataList : [StormcloudMetadata] {
        get {
            return self.backingMetadataList
        }
    }
    
    /// The backup manager delegate
    open var delegate : StormcloudDelegate?
    
    /// The number of files to keep before older ones are deleted. 0 = never delete.
    open var fileLimit : Int = 0
    
    var formatter = DateFormatter()
    
    var iCloudURL : URL?
    var metadataQuery : NSMetadataQuery = NSMetadataQuery()
    
    var backingMetadataList : [StormcloudMetadata] = []
    var internalMetadataList : [StormcloudMetadata] = []
    var internalQueryList : [String : StormcloudMetadata] = [:]
    var pauseMetadata : Bool = false
    
    var moveDocsToiCloud : Bool = false
    var moveDocsToiCloudCompletion : ((_ error : StormcloudError?) -> Void)?

    var operationInProgress : Bool = false
    
    var workingCache : [String : Any] = [:]
    
    public override init() {
        super.init()
        if self.isUsingiCloud {
            _ = self.enableiCloudShouldMoveLocalDocumentsToiCloud(false, completion: nil)
        }
        self.prepareDocumentList()
    }
    
    /**
     Reloads the current metadata list, either from iCloud or from local documents. If you are switching between storage locations, using the appropriate methods will automatically reload the list of documents so there's no need to call this.
     */
    open func reloadData() {
        self.prepareDocumentList()
    }
    
    /**
    Attempts to enable iCloud for document storage.
    
    - parameter move: Attept to move the documents from local storage to iCloud
    - parameter completion: A completion handler to be run when the move has finisehd
    
    - returns: true if iCloud was enabled, false otherwise
    */
    open func enableiCloudShouldMoveLocalDocumentsToiCloud(_ move : Bool, completion : ((_ error : StormcloudError?) -> Void)? ) -> Bool {
        let currentiCloudToken = FileManager.default.ubiquityIdentityToken
        
        // If we don't have a token, then we can't enable iCloud
        guard let token = currentiCloudToken  else {
            if let hasCompletion = completion {
                hasCompletion(StormcloudError.iCloudUnavailable)
            }
            
            disableiCloudShouldMoveiCloudDocumentsToLocal(false, completion: nil)
            return false
            
        }
        // Add observer for iCloud user changing
        NotificationCenter.default.addObserver(self, selector: #selector(Stormcloud.iCloudUserChanged(_:)), name: NSNotification.Name.NSUbiquityIdentityDidChange, object: nil)
        
        let data = NSKeyedArchiver.archivedData(withRootObject: token)
        UserDefaults.standard.set(data, forKey: StormcloudPrefKey.iCloudToken.rawValue)
        UserDefaults.standard.set(true, forKey: StormcloudPrefKey.isUsingiCloud.rawValue)
        
        
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
    open func disableiCloudShouldMoveiCloudDocumentsToLocal( _ move : Bool, completion : ((_ moveSuccessful : Bool) -> Void)? ) {
        
        if move {
            // Handle the moving of documents
            self.moveItemsFromiCloud(self.backingMetadataList, completion: completion)
        }
        
        UserDefaults.standard.removeObject(forKey: StormcloudPrefKey.iCloudToken.rawValue)
        UserDefaults.standard.set(false, forKey: StormcloudPrefKey.isUsingiCloud.rawValue)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.NSUbiquityIdentityDidChange, object: nil)
        
        
        self.metadataQuery.stop()
        self.internalQueryList.removeAll()
        self.prepareDocumentList()
    }
    
    func moveItemsToiCloud( _ items : [String], completion : ((_ success : Bool, _ error : NSError?) -> Void)? ) {
        if let docsDir = self.documentsDirectory(), let iCloudDir = iCloudDocumentsDirectory() {
			
			DispatchQueue.global(qos: .default).async {
				var success = true
				var hasError : NSError?
				for filename in items {
					let finalURL = docsDir.appendingPathComponent(filename)
					let finaliCloudURL = iCloudDir.appendingPathComponent(filename)
					do {
						try FileManager.default.setUbiquitous(true, itemAt: finalURL, destinationURL: finaliCloudURL)
					} catch let error as NSError {
						success = false
						hasError = error
					}
				}
				
				DispatchQueue.main.async(execute: { () -> Void in
					completion?(success, hasError)
				})
			}
			
        } else {
            let scError = StormcloudError.couldntMoveDocumentToiCloud
            let error = scError.asNSError()
            completion?(false, error)
        }
    }
    
    func moveItemsFromiCloud( _ items : [StormcloudMetadata], completion : ((_ success : Bool ) -> Void)? ) {
        // Copy all of the local documents to iCloud
        if let docsDir = self.documentsDirectory(), let iCloudDir = iCloudDocumentsDirectory() {
            
            let filenames = items.map { $0.filename }
            
            DispatchQueue.global(qos: .default).async {
                var success = true
                for element in filenames {
                    let finalURL = docsDir.appendingPathComponent(element)
                    let finaliCloudURL = iCloudDir.appendingPathComponent(element)
                    do {
                        self.stormcloudLog("Moving files from iCloud: \(finaliCloudURL) to local URL: \(finalURL)")
                        try FileManager.default.setUbiquitous(false, itemAt: finaliCloudURL, destinationURL: finalURL)
                    } catch {
                        success = false
                    }
                }
                
                DispatchQueue.main.async(execute: { () -> Void in
                    self.prepareDocumentList()
                    completion?(success)
                })
            }
        } else {
            completion?(false)
        }
    }
    
    
    func iCloudUserChanged( _ notification : Notification ) {
        // Handle user changing
        
        self.prepareDocumentList()
        
    }
    
    deinit {
        self.metadataQuery.stop()
        NotificationCenter.default.removeObserver(self)
    }
    
}

// MARK: - Backup

extension Stormcloud {
    
    /**
     Backups the passed JSON objects to iCloud. Will also run a check to ensure that the objects are valid JSON, returning an error in the completion handler if there's a problem.
     
     - parameter objects:    A JSON object
     - parameter completion: A completion block that returns the new metadata if the backup was successful and a new document was created
     */
    public func backupObjectsToJSON( _ objects : Any, completion : @escaping (_ error : StormcloudError?, _ metadata : StormcloudMetadata?) -> () ) {
        
        self.stormcloudLog("\(#function)")
        
        if self.operationInProgress {
            completion(.backupInProgress, nil)
            return
        }
        self.operationInProgress = true
        
        
        if let baseURL = self.documentsDirectory() {
            let metadata = StormcloudMetadata()
            let finalURL = baseURL.appendingPathComponent(metadata.filename)
            
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
                completion(.backupFileExists, nil)
                return
            }
            document.save(to: finalURL, for: .forCreating, completionHandler: { (success) -> Void in
                let totalSuccess = success
                
                if ( !totalSuccess ) {
                    
                    self.stormcloudLog("\(#function): Error saving new document")
                    
                    DispatchQueue.main.async(execute: { () -> Void in
                        self.operationInProgress = false
                        completion(StormcloudError.couldntSaveNewDocument, nil)
                    })
                    return
                    
                }
                document.close(completionHandler: nil)
                if !self.isUsingiCloud {
                    DispatchQueue.main.async(execute: { () -> Void in
                        self.internalMetadataList.append(metadata)
                        self.prepareDocumentList()
                        self.operationInProgress = false
                        completion(nil, (totalSuccess) ? metadata : metadata)
                    })
                } else {
					DispatchQueue.main.async(execute: { () -> Void in
						self.moveItemsToiCloud([metadata.filename], completion: { (success) -> Void in
							self.operationInProgress = false
							if totalSuccess {
								completion(nil, metadata)
							} else {
								completion(StormcloudError.couldntMoveDocumentToiCloud, metadata)
							}
						})
					})
                }
            })
        }
    }
	
    public func backupCoreDataEntities( inContext currentContext : NSManagedObjectContext, completion : @escaping ( _ error : StormcloudError?, _ metadata : StormcloudMetadata?) -> () ) {
        
        self.stormcloudLog("Beginning backup of Core Data with context : \(currentContext)")
        
        do {
            try currentContext.save()
        } catch {
            stormcloudLog("Error saving context")
        }
        if self.operationInProgress {
            completion(.backupInProgress, nil)
            return
        }
        self.operationInProgress = true

		let context = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
		context.parent = currentContext
        context.perform { () -> Void in
            
            // Dictionaries are a list of all objects, with their ManagedObjectID as the key and a dictionary of their parts as the object
            var dictionary : [String : [ String : Any ] ] = [:]
            
            if let entities = context.persistentStoreCoordinator?.managedObjectModel.entities {
                
                self.formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZZZ"
                for entity in entities {
                    if let entityName = entity.name {
                        let request = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
                        
                        let allObjects : [NSManagedObject]
                        do {
                            allObjects = try context.fetch(request) as! [NSManagedObject]
                        } catch {
                            allObjects = []
                        }
						
						self.stormcloudLog("Found \(allObjects.count) of \(entityName) to back up")
                        
                        for object in allObjects {
                            let uriRepresentation = object.objectID.uriRepresentation().absoluteString
                            
                            var internalDictionary : [String : Any] = [StormcloudEntityKeys.EntityType.rawValue : entityName as AnyObject]
                            
                            for propertyDescription in entity.properties {
                                if let attribute = propertyDescription as? NSAttributeDescription {
                                    internalDictionary[attribute.name] = self.getAttribute(attribute, fromObject: object)
                                }
                                
                                if let relationship = propertyDescription as? NSRelationshipDescription {
                                    var objectIDs : [String] = []
                                    if let objectSet =  object.value(forKey: relationship.name) as? NSSet, let objectArray = objectSet.allObjects as? [NSManagedObject] {
                                        for object in objectArray {

                                            objectIDs.append(object.objectID.uriRepresentation().absoluteString)
                                        }
                                    }
                                    
                                    if let relationshipObject = object.value(forKey: relationship.name) as? NSManagedObject {
                                        let objectID = relationshipObject.objectID.uriRepresentation().absoluteString
                                        objectIDs.append(objectID)
                                        
                                    }
                                    internalDictionary[relationship.name] = objectIDs
                                }
                            }
                            dictionary[uriRepresentation] = internalDictionary
                            
                        }
                    }
                }
                if !JSONSerialization.isValidJSONObject(dictionary) {

                   self.stormcloudLog("\(#function) Error: Dictionary not valid: \(dictionary)")
                    
                    DispatchQueue.main.async(execute: { () -> Void in
                        self.operationInProgress = false
                        completion(.invalidJSON, nil)
                    })
                } else {
                    DispatchQueue.main.async(execute: { () -> Void in
                        self.operationInProgress = false
                        self.backupObjectsToJSON(dictionary as AnyObject, completion: completion)
                    })
                }
            }
        }
    }
    
}


// MARK: - Core Data Methods

extension Stormcloud {
    func insertObjectsWithContext( _ context : NSManagedObjectContext, data : [String : AnyObject], completion : @escaping (_ success : Bool) -> ()  ) {
        
        stormcloudLog("\(#function)")
        
        let privateContext = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        privateContext.parent = context
        privateContext.perform { () -> Void in

            self.formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZZZ"
            
            var success = true
            
            // First we get all the objects
            // Then we delete them all!
            if let entities = privateContext.persistentStoreCoordinator?.managedObjectModel.entities {

                self.stormcloudLog("Found \(entities.count) entities:")
                
                for entity in entities {
                    if let entityName = entity.name {

                        self.stormcloudLog("\t\(entityName)")
                        
                        let request = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
                        
                        let allObjects : [NSManagedObject]
                        do {
                            allObjects = try privateContext.fetch(request) as! [NSManagedObject]
                        } catch {
                            allObjects = []
                        }
                        
                        for object in allObjects {
                            privateContext.delete(object)
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
                
                context.performAndWait({ () -> Void in
                    do {
                        try context.save()
                    } catch {
                        success = false
                        self.stormcloudLog("Error saving parent context")
                        abort()
                    }
                    
                    if let parentContext = context.parent {
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
                        let object = NSEntityDescription.insertNewObject(forEntityName: entityName, into: privateContext)
                        
                        dict[StormcloudEntityKeys.ManagedObject.rawValue] = object
                        
                        self.workingCache[key] = dict
                        
                        allObjects.append(object)
                        
                        for (propertyName, propertyValue ) in dict {
                            for propertyDescription in object.entity.properties {
                                if let attribute = propertyDescription as? NSAttributeDescription , propertyName == propertyDescription.name {
                                    
                                    self.stormcloudLog("\t\tFound attribute: \(propertyName)")
                                    
                                    self.setAttribute(attribute, onObject: object, withData: propertyValue)
                                }
                            }
                        }
                    }
                }

                self.stormcloudLog("\tAttempting to obtain permanent IDs...")
                do {
                    try privateContext.obtainPermanentIDs(for: allObjects)
                    self.stormcloudLog("\t\tSuccess")
                } catch {
                    self.stormcloudLog("\t\tCouldn't obtain permanent IDs")
                }
                
                if StormcloudEnvironment.VerboseLogging.isEnabled() {
                    
                    for object in allObjects {
                        self.stormcloudLog("\t\tIs Temporary ID: \(object.objectID.isTemporaryID)")
                        self.stormcloudLog("\t\t\tNew ID: \(object.objectID)")
                    }
                    
                }
                
                do {
                    try privateContext.save()
                } catch {
                    // TODO : Better error handling
                    self.stormcloudLog("Error saving during restore")
                }
                
                context.performAndWait({ () -> Void in
                    do {
                        try context.save()
                    } catch {
                        // TODO : Better error handling
                        self.stormcloudLog("Error saving parent context")
                    }
                    if let parentContext = context.parent {
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
                    if let dict = value as? [String : AnyObject], let object = dict[StormcloudEntityKeys.ManagedObject.rawValue] as? NSManagedObject {
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
                
                DispatchQueue.main.async { () -> Void in
                    completion(success)
                }
                
            }
        }
    }
    
    func setRelationship( _ relationship : NSRelationshipDescription, onObject : NSManagedObject, withData data: [ String : AnyObject], inContext : NSManagedObjectContext ) {
        
        
        
        if let _ =  inContext.registeredObject(for: onObject.objectID) {
            
        } else {
            return;
        }
        
        if let relationshipIDs = data[relationship.name] as? [String] {
            var setObjects : [NSManagedObject] = []
            for id in relationshipIDs {
                
                
                
                if let cacheData = self.workingCache[id] as? [String : AnyObject], let relatedObject = cacheData[StormcloudEntityKeys.ManagedObject.rawValue] as? NSManagedObject {
                    if !relationship.isToMany {
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
            
            
            if relationship.isToMany && setObjects.count > 0 {
                self.stormcloudLog("\tRestoring To-many relationship \(onObject.entity.name) ->> \(relationship.name) with \(setObjects.count) objects")
                if relationship.isOrdered {
                    
                    let set = NSOrderedSet(array: setObjects)
                    onObject.setValue(set, forKey: relationship.name)
                    
                } else {
                    let set = NSSet(array: setObjects)
                    onObject.setValue(set, forKey: relationship.name)
                }
                
            }
        }
    }
    
    
    func getAttribute( _ attribute : NSAttributeDescription, fromObject object : NSManagedObject ) -> Any? {
        
        switch attribute.attributeType {
        case .integer16AttributeType, .integer32AttributeType,.integer64AttributeType, .doubleAttributeType, .floatAttributeType, .stringAttributeType, .booleanAttributeType :
            
            return object.value(forKey: attribute.name)
            
            
        case .decimalAttributeType:
            
            if let decimal = object.value(forKey: attribute.name) as? NSDecimalNumber {
                return decimal.stringValue
            }
        case .dateAttributeType:
            if let date = object.value(forKey: attribute.name) as? Date {
                return formatter.string(from: date)
            }
        case .binaryDataAttributeType, .transformableAttributeType:
            if let value = object.value(forKey: attribute.name) as? NSCoding {
                let mutableData = NSMutableData()
                let archiver = NSKeyedArchiver(forWritingWith: mutableData)
                archiver.encode(value, forKey: attribute.name)
                archiver.finishEncoding()
                return mutableData.base64EncodedString(options: NSData.Base64EncodingOptions())
            }
        case .objectIDAttributeType, .undefinedAttributeType:
            break
            
        }
        
        
        return nil
    }
    
    
    func setAttribute( _ attribute : NSAttributeDescription, onObject object : NSManagedObject,  withData data : AnyObject? ) {
        switch attribute.attributeType {
        case .integer16AttributeType, .integer32AttributeType,.integer64AttributeType, .doubleAttributeType, .floatAttributeType:
            if let val = data as? NSNumber {
                object.setValue(val, forKey: attribute.name)
            } else {
                stormcloudLog("Setting Number : \(data) not Number")
            }
            
        case .decimalAttributeType:
            if let val = data as? String {
                let decimal = NSDecimalNumber(string: val)
                object.setValue(decimal, forKey: attribute.name)
            } else {
                stormcloudLog("Setting Decimal : \(data) not String")
            }
            
        case .stringAttributeType:
            if let val = data as? String {
                object.setValue(val, forKey: attribute.name)
            } else {
                stormcloudLog("Setting String : \(data) not String")
            }
        case .booleanAttributeType:
            if let val = data as? NSNumber {
                object.setValue(val.boolValue, forKey: attribute.name)
            } else {
                stormcloudLog("Setting Bool : \(data) not Number")
            }
        case .dateAttributeType:
            if let val = data as? String, let date = self.formatter.date(from: val) {
                object.setValue(date, forKey: attribute.name)
            }
        case .binaryDataAttributeType, .transformableAttributeType:
            if let val = data as? String {
                let data = Data(base64Encoded: val, options: NSData.Base64DecodingOptions())
                let unarchiver = NSKeyedUnarchiver(forReadingWith: data!)
                if let data = unarchiver.decodeObject(forKey: attribute.name) as? NSObject {
                    object.setValue(data, forKey: attribute.name)
                }
                unarchiver.finishDecoding()
            } else {
                stormcloudLog("Transformable/Binary type : \(data) not String")
            }
        case .objectIDAttributeType, .undefinedAttributeType:
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
    public func urlForItem(_ item : StormcloudMetadata) -> URL? {
        if self.isUsingiCloud {
            return self.iCloudDocumentsDirectory()?.appendingPathComponent(item.filename)
        } else {
            return self.documentsDirectory()?.appendingPathComponent(item.filename)
        }
    }
}


// MARK: - Restoring

extension Stormcloud {
    
    
    /**
     Restores a JSON object from the given Stormcloud Metadata object
     
     - parameter metadata:        The Stormcloud metadata object that represents the document
     - parameter completion:      A completion handler to run when the operation is completed
     */
    public func restoreBackup(withMetadata metadata : StormcloudMetadata, completion : @escaping (_ error: StormcloudError?, _ restoredObjects : Any? ) -> () ) {
        
        if self.operationInProgress {
            completion(.backupInProgress, nil)
            return
        }
        self.operationInProgress = true
        
        if let url = self.urlForItem(metadata) {
            let document = BackupDocument(fileURL : url)
            document.open(completionHandler: { (success) -> Void in
                
                if !success {
                    self.operationInProgress = false
                    completion(.couldntOpenDocument, nil)
                    return
                }
                
                DispatchQueue.main.async(execute: { () -> Void in
                    self.operationInProgress = false
                    completion(nil, document.objectsToBackup)
                })
            })
        } else {
            self.operationInProgress = false
            completion(.invalidURL, nil)
        }
    }
    
    /**
     Restores a backup to Core Data from a UIManagedDocument
     
     - parameter document:   The backup document to restore
     - parameter context:    The context to restore the objects to
     - parameter completion: A completion handler
     */
    public func restoreCoreDataBackup(withDocument document : BackupDocument, toContext context : NSManagedObjectContext,  completion : @escaping (_ error : StormcloudError?) -> () ) {
        if let data = document.objectsToBackup as? [String : AnyObject] {
            self.insertObjectsWithContext(context, data: data) { (success)  -> Void in
                self.operationInProgress = false
                let error : StormcloudError?  = (success) ? nil : StormcloudError.couldntRestoreJSON
                completion(error)
            }
        } else {
            self.operationInProgress = false
            completion(.couldntRestoreJSON)
        }
    }
    
    /**
     Restores a backup to Core Data from a StormcloudMetadata object
     
     - parameter metadata:  The metadata that represents the document
     - parameter context:    The context to restore the objects to
     - parameter completion: A completion handler
     */

    public func restoreCoreDataBackup(withMetadata metadata : StormcloudMetadata, toContext context : NSManagedObjectContext,  completion : @escaping (_ error : StormcloudError?) -> () ) {
        
        do {
            try context.save()
        } catch {
            // TODO : Handle errors better
            stormcloudLog("Error saving context")
        }
        
        if self.operationInProgress {
            completion(.backupInProgress)
            return
        }
        self.operationInProgress = true
        
        if let url = self.urlForItem(metadata) {
            let document = BackupDocument(fileURL : url)
            document.open(completionHandler: { (success) -> Void in
                
                if !success {
                    self.operationInProgress = true
                    completion(.couldntOpenDocument)
                    return
                }
                
                DispatchQueue.main.async(execute: { () -> Void in
                    
                    self.restoreCoreDataBackup(withDocument: document, toContext: context, completion: completion)
                })
            })
        } else {
            self.operationInProgress = false
            completion(.invalidURL)
        }
    }
    
    public func deleteItemsOverLimit( _ completion : @escaping ( _ error : StormcloudError? ) -> () ) {
        
        // Knock one off as we're about to back up
        let limit = self.fileLimit - 1
        var itemsToDelete : [StormcloudMetadata] = []
        if self.fileLimit > 0 && self.metadataList.count > limit {
			

			for i in self.fileLimit..<self.metadataList.count {
				let metadata = self.metadataList[i]
				itemsToDelete.append(metadata)				
			}
			
        }
        
        for item in itemsToDelete {
            self.deleteItem(item, completion: { (index, error) -> () in
                if let hasError = error {
                    self.stormcloudLog("Error deleting: \(hasError.localizedDescription)")
                    completion(.couldntDelete)
				} else {
					completion(nil)
				}
            })
        }
        
    }
    
    public func deleteItems( _ metadataItems : [StormcloudMetadata], completion : @escaping (_ index : Int?, _ error : NSError? ) -> () ) {
        
        // Pull them out of the internal list first
        var urlList : [ URL : Int ] = [:]
        var errorList : [StormcloudMetadata] = []
        for item in metadataItems {
            if let itemURL = self.urlForItem(item), let idx = self.internalMetadataList.index(of: item) {
                urlList[itemURL] = idx
            } else {
                errorList.append(item)
            }
        }
        
        for (_, idx) in urlList {
            self.internalMetadataList.remove(at: idx)
        }
        self.sortDocuments()

        // Remove them from the internal list
        DispatchQueue.global(qos: .default).async {
            
            // TESTING ENVIRONMENT
            if StormcloudEnvironment.MangleDelete.isEnabled() {
                sleep(2)
                DispatchQueue.main.async(execute: { () -> Void in
                    let deleteError = StormcloudError.couldntDelete
                    let error = NSError(domain:deleteError.domain(), code: deleteError.rawValue, userInfo: nil)
                    completion(nil, error )
                })
                return
            }
            // ENDs
            var hasError : NSError?
            for (url, _) in urlList {
                let coordinator = NSFileCoordinator(filePresenter: nil)
                coordinator.coordinate(writingItemAt: url, options: .forDeleting, error:nil, byAccessor: { (url) -> Void in

                    do {
                        try FileManager.default.removeItem(at: url)
                    } catch let error as NSError  {
                        hasError = error
                    }
                    
                })
                
                if hasError != nil {
                    break
                }
                
            }
            DispatchQueue.main.async(execute: { () -> Void in
                completion(nil, hasError)

            })
        }

        
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
    public func deleteItem(_ metadataItem : StormcloudMetadata, completion : @escaping (_ index : Int?, _ error : NSError?) -> () ) {
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
            
            var myContainer : URL?
            DispatchQueue.global(qos: .default).async {
                
                myContainer = FileManager.default.url(forUbiquityContainerIdentifier: nil)
                self.iCloudURL = myContainer
                
                var stormcloudError : StormcloudError?
                if self.moveDocsToiCloud {
                    if let iCloudDir = self.iCloudDocumentsDirectory() {
                        for fileURL in self.listLocalDocuments() {
                            if fileURL.pathExtension == self.fileExtension {
								
								let finaliCloudURL = iCloudDir.appendingPathComponent(fileURL.lastPathComponent)
								do {
									try FileManager.default.setUbiquitous(true, itemAt: fileURL, destinationURL: finaliCloudURL)
								} catch {
									stormcloudError = StormcloudError.couldntMoveDocumentToiCloud
								}
						
                            }
                        }
                    }
                    self.moveDocsToiCloud = false
                }
                
                DispatchQueue.main.async(execute: { () -> Void in
                    
                    // Start metadata search
                    self.loadiCloudDocuments()
                    // Set URL

                    // If we have a completion handler from earlier
                    if let completion = self.moveDocsToiCloudCompletion {
                        completion(stormcloudError)
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
        self.internalMetadataList.sort { (element1, element2) -> Bool in
            if (element2.date as NSDate).earlierDate(element1.date as Date) == element2.date as Date {
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
            if let idx = self.backingMetadataList.index(of: item) {
                indexesToDelete.add(idx)
            }
        }
        
        
        let sortedIndexes = indexesToDelete.sorted { (index1, index2) -> Bool in
            return index1 > index2
        }
        for idx in sortedIndexes {
            self.backingMetadataList.remove(at: idx)
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
            if let idx = self.internalMetadataList.index(of: item) {
                indexesToAdd.add(idx)
                let item = self.internalMetadataList[idx]
                self.backingMetadataList.insert(item, at: idx)
            }
        }
        self.delegate?.metadataListDidAddItemsAtIndexes((indexesToAdd.count > 0 ) ? indexesToAdd as IndexSet : nil, andDeletedItemsAtIndexes: (indexesToDelete.count > 0) ? indexesToDelete as IndexSet : nil)
        
        //        })
    }
    
    
}

// MARK: - Local Document Handling

extension Stormcloud {

    func listLocalDocuments() -> [URL] {
        let docs : [URL]
        if let url = self.documentsDirectory()  {
            
            do {
                docs = try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: FileManager.DirectoryEnumerationOptions())
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
    
    
    func documentsDirectory() -> URL? {
        if let docsURL = FileManager.default.urls(for: FileManager.SearchPathDirectory.documentDirectory, in: .userDomainMask).first {
            return docsURL
        }
        return nil
    }
}

// MARK: - iCloud Document Handling

extension Stormcloud {
    
    func loadiCloudDocuments() {

        if self.metadataQuery.isStopped {
            stormcloudLog("Metadata query stopped")
            self.metadataQuery.start()
            return
        }
        
        if self.metadataQuery.isGathering {
            stormcloudLog("Metadata query gathering")
            return
        }
        
        stormcloudLog("Beginning metadata query")
        
        self.metadataQuery.searchScopes = [NSMetadataQueryUbiquitousDocumentsScope]
        self.metadataQuery.predicate = NSPredicate(format: "%K CONTAINS '.json'", NSMetadataItemFSNameKey)
        
        NotificationCenter.default.addObserver(self, selector: #selector(Stormcloud.metadataFinishedGathering), name:NSNotification.Name.NSMetadataQueryDidFinishGathering , object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(Stormcloud.metadataUpdated), name:NSNotification.Name.NSMetadataQueryDidUpdate, object: nil)
        
        self.metadataQuery.start()
    }
    
    func iCloudDocumentsDirectory() -> URL? {
        if self.isUsingiCloud {
            if let hasiCloudDir = self.iCloudURL {
                return hasiCloudDir.appendingPathComponent("Documents")
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
                if let fname = item.value(forAttribute: NSMetadataItemDisplayNameKey) as? String {
                    
                    if let hasBackup = self.internalQueryList[fname] {
                        hasBackup.iCloudMetadata = item
                    } else {
                        if let url = item.value(forAttribute: NSMetadataItemURLKey) as? URL {
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
    func stormcloudLog( _ string : String ) {
        if StormcloudEnvironment.VerboseLogging.isEnabled() {
            print(string)
        }
    }
    
}



