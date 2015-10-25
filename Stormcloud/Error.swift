//
//  Error.swift
//  Stormcloud
//
//  Created by Simon Fairbairn on 25/10/2015.
//  Copyright © 2015 Voyage Travel Apps. All rights reserved.
//

import Foundation

/**
 Errors that Stormcloud can generate:
 
 - **InvalidJSON**:                     The JSON file to backup was invalid
 - **BackupFileExists**:                A backup file with the same name exists—usually this is caused by trying to write a new file faster than once a second
 - **CouldntSaveManagedObjectContext**: The passed `NSManagedObjectContext` was invalid
 - **CouldntSaveNewDocument**:          The document manager could not save the document
 - **CouldntMoveDocumentToiCloud**:     The backup document was created but could not be moved to iCloud
 - **CouldntDelete**:     The backup document was created but could not be moved to iCloud 
 */
public enum StormcloudError : Int, ErrorType {
    case InvalidJSON
    case InvalidURL
    case BackupFileExists
    case CouldntSaveManagedObjectContext
    case CouldntSaveNewDocument
    case CouldntMoveDocumentToiCloud
    case CouldntDelete
    
    func domain() -> String {
        return "com.voyagetravelapps.Stormcloud"
    }
}