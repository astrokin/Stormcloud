//
//  StormcloudTestsBaseClass.swift
//  Stormcloud
//
//  Created by Simon Fairbairn on 21/10/2015.
//  Copyright © 2015 Simon Fairbairn. All rights reserved.
//

import XCTest

class StormcloudTestsBaseClass: XCTestCase {

    var docsURL : NSURL?
    
    let futureFilename = "2020-10-19 16-47-44--iPhone--1E7C8A50-FDDC-4904-AD64-B192CF3DD157"
    let pastFilename = "2014-10-18 16-47-44--iPhone--1E7C8A50-FDDC-4904-AD64-B192CF3DD157"
    
    override func setUp() {
        super.setUp()
        
        docsURL = NSFileManager.defaultManager().URLsForDirectory(.DocumentDirectory, inDomains: .UserDomainMask).first
        
        let docs = self.listItemsAtURL()
        
        for url in docs {
            if url.pathExtension == "json" {
                do {
                    print("Deleting \(url)")
                    try NSFileManager.defaultManager().removeItemAtURL(url)
                } catch {
                    print("Couldn't delete item")
                }
            }
        }
        
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
        
        let docs = self.listItemsAtURL()
        
        for url in docs {
            if url.pathExtension == "json" {
                do {
                    print("Deleting \(url)")
                    try NSFileManager.defaultManager().removeItemAtURL(url)
                } catch {
                    print("Couldn't delete item")
                }
            }
        }
    }
    
    func copyItems() {
        
        let fullPastFilename = self.pastFilename + ".json"
        let fullFutureFilename = self.futureFilename + ".json"
        
        if let pastURL = NSBundle(forClass: StormcloudTests.self).URLForResource(self.pastFilename, withExtension: "json"),
            docsURL = self.docsURL?.URLByAppendingPathComponent(fullPastFilename) {
                
                
                do {
                    try             NSFileManager.defaultManager().copyItemAtURL(pastURL, toURL: docsURL)
                } catch let error as NSError {
                    XCTFail("Failed to copy past item \(error.localizedDescription)")
                }
        }
        if let futureURL = NSBundle(forClass: StormcloudTests.self).URLForResource(self.futureFilename, withExtension: "json"),
            docsURL = self.docsURL?.URLByAppendingPathComponent(fullFutureFilename) {
                do {
                    try             NSFileManager.defaultManager().copyItemAtURL(futureURL, toURL: docsURL)
                } catch {
                    XCTFail("Failed to copy future item")
                }
        }
        
    }
    
    
    func listItemsAtURL() -> [NSURL] {
        var jsonDocs : [NSURL] = []
        if let docsURL = docsURL {
            var docs : [NSURL] = []
            do {
                docs = try NSFileManager.defaultManager().contentsOfDirectoryAtURL(docsURL, includingPropertiesForKeys: nil, options: NSDirectoryEnumerationOptions())
            } catch {
                print("couldn't search path \(docsURL)")
            }
            
            for url in docs {
                if url.pathExtension == "json" {
                    jsonDocs.append(url)
                }
            }
        }
        return jsonDocs
    }
    
}
