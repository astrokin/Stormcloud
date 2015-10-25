//
//  BackupDocument.swift
//  VTABM
//
//  Created by Simon Fairbairn on 20/10/2015.
//  Copyright © 2015 Simon Fairbairn. All rights reserved.
//

import UIKit

public class BackupDocument: UIDocument {

    public var backupMetadata : StormcloudMetadata?
    public var objectsToBackup : AnyObject?
    
    public override func loadFromContents(contents: AnyObject, ofType typeName: String?) throws {
        if let data = contents as? NSData {
            do {
                let json = try NSJSONSerialization.JSONObjectWithData(data, options: NSJSONReadingOptions.AllowFragments) as? [String : AnyObject]
                if let isJson = json {
                    self.objectsToBackup = isJson
                    self.backupMetadata = StormcloudMetadata(fileURL: self.fileURL)
                }
                
            } catch {
                print("Error reading JSON, or not correct format")
            }
        }
    }
    
    public override func contentsForType(typeName: String) throws -> AnyObject {
        var data = NSData()
        
        if let hasData = self.objectsToBackup {
            do {
                data = try NSJSONSerialization.dataWithJSONObject(hasData, options: NSJSONWritingOptions())
            } catch {
                print("Error writing JSON")
            }
            
        }
        
        return data
    }
    
}
