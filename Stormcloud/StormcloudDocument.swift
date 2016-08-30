//
//  BackupDocument.swift
//  VTABM
//
//  Created by Simon Fairbairn on 20/10/2015.
//  Copyright © 2015 Simon Fairbairn. All rights reserved.
//

import UIKit

open class BackupDocument: UIDocument {

    open var backupMetadata : StormcloudMetadata?
    open var objectsToBackup : Any?
    
    open override func load(fromContents contents: Any, ofType typeName: String?) throws {
        if let data = contents as? Data {
            do {
                let json = try JSONSerialization.jsonObject(with: data, options: JSONSerialization.ReadingOptions.allowFragments) as? [String : AnyObject]
                if let isJson = json {
                    self.objectsToBackup = isJson
                    self.backupMetadata = StormcloudMetadata(fileURL: self.fileURL)
                }
                
            } catch {
                print("Error reading JSON, or not correct format")
            }
        }
    }
    
    open override func contents(forType typeName: String) throws -> Any {
        var data = Data()
        
        if let hasData = self.objectsToBackup {
            do {
                let jsonOptions : JSONSerialization.WritingOptions
                if StormcloudEnvironment.VerboseLogging.isEnabled() {
                    jsonOptions = .prettyPrinted
                } else {
                    jsonOptions = JSONSerialization.WritingOptions()
                }
                
                data = try JSONSerialization.data(withJSONObject: hasData, options: jsonOptions)
            } catch {
                print("Error writing JSON")
            }
            
        }
        
        return data
    }
    
}
