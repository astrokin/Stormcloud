//
//  StormcloudTestsBaseClass.swift
//  Stormcloud
//
//  Created by Simon Fairbairn on 21/10/2015.
//  Copyright © 2015 Simon Fairbairn. All rights reserved.
//

import XCTest

class StormcloudTestsBaseClass: XCTestCase {

    var docsURL : URL?
    
    let futureFilename = "2020-10-19 16-47-44--iPhone--1E7C8A50-FDDC-4904-AD64-B192CF3DD157"
    let pastFilename = "2014-10-18 16-47-44--iPhone--1E7C8A50-FDDC-4904-AD64-B192CF3DD157"
    
    override func setUp() {
        super.setUp()
        
        docsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        
        let docs = self.listItemsAtURL()
        
        for url in docs {
            if url.pathExtension == "json" {
                do {
                    print("Deleting \(url)")
                    try FileManager.default.removeItem(at: url)
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
                    try FileManager.default.removeItem(at: url)
                } catch {
                    print("Couldn't delete item")
                }
            }
        }
    }
    
    func copyItems() {
        
        let fullPastFilename = self.pastFilename + ".json"
        let fullFutureFilename = self.futureFilename + ".json"
        
        if let pastURL = Bundle(for: StormcloudTests.self).url(forResource: self.pastFilename, withExtension: "json"),
            let docsURL = self.docsURL?.appendingPathComponent(fullPastFilename) {
                
                
                do {
                    try             FileManager.default.copyItem(at: pastURL, to: docsURL)
                } catch let error as NSError {
                    XCTFail("Failed to copy past item \(error.localizedDescription)")
                }
        }
        if let futureURL = Bundle(for: StormcloudTests.self).url(forResource: self.futureFilename, withExtension: "json"),
            let docsURL = self.docsURL?.appendingPathComponent(fullFutureFilename) {
                do {
                    try             FileManager.default.copyItem(at: futureURL, to: docsURL)
                } catch {
                    XCTFail("Failed to copy future item")
                }
        }
        
    }
    
    
    func listItemsAtURL() -> [URL] {
        var jsonDocs : [URL] = []
        if let docsURL = docsURL {
            var docs : [URL] = []
            do {
                docs = try FileManager.default.contentsOfDirectory(at: docsURL, includingPropertiesForKeys: nil, options: FileManager.DirectoryEnumerationOptions())
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
