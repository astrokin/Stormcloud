//
//  StormcloudTests.swift
//  Stormcloud
//
//  Created by Simon Fairbairn on 20/10/2015.
//  Copyright © 2015 Simon Fairbairn. All rights reserved.
//

import XCTest

class StormcloudTests: StormcloudTestsBaseClass {
	
	let year = NSCalendar.currentCalendar().component(.Year, fromDate: NSDate())
	
    override func setUp() {
        super.setUp()
    }
    
    override func tearDown() {
        super.tearDown()
    }
    
    
    func testThatBackupManagerAddsDocuments() {
        let stormcloud = Stormcloud()
        
        XCTAssertEqual(stormcloud.metadataList.count, 0)
        
        XCTAssertFalse(stormcloud.isUsingiCloud)
        
        let docs = self.listItemsAtURL()
        XCTAssertEqual(stormcloud.metadataList.count, docs.count)
        
        let expectation = expectationWithDescription("Backup expectation")
        
        
        stormcloud.backupObjectsToJSON(["Test" : "Test"]) { (error, metadata) -> () in
            XCTAssertNil(error, "Backing up should always write successfully")
                print(metadata?.filename)
                XCTAssertNotNil(metadata, "If successful, the metadata field should be populated")
            expectation.fulfill()
            
        }
        
        waitForExpectationsWithTimeout(3.0, handler: nil)
        
        let newDocs = self.listItemsAtURL()
        XCTAssertEqual(newDocs.count, 1)
        XCTAssertEqual(stormcloud.metadataList.count, 1)
        XCTAssertEqual(stormcloud.metadataList.count, newDocs.count)
        
    }
    
    func testThatBackupManagerDeletesDocuments() {
        let stormcloud = Stormcloud()
        
        let expectation = expectationWithDescription("Backup expectation")
        stormcloud.backupObjectsToJSON(["Test" : "Test"]) { (error, metadata) -> () in
            XCTAssertNil(error, "Backing up should always write successfully")

                print(metadata?.filename)
                XCTAssertNotNil(metadata, "If successful, the metadata field should be populated")
            expectation.fulfill()
        }
        waitForExpectationsWithTimeout(3.0, handler: nil)
        
        
        let newDocs = self.listItemsAtURL()
        XCTAssertEqual(stormcloud.metadataList.count, 1)
        XCTAssertEqual(stormcloud.metadataList.count, newDocs.count)

        let deleteExpectation = expectationWithDescription("Delete expectation")
        
        if let firstItem = stormcloud.metadataList.first {
            stormcloud.deleteItem(firstItem) { (error, index) -> () in
                XCTAssertNil(error)
                deleteExpectation.fulfill()
            }
        } else {
            XCTFail("Backup list should have at least 1 item in it")
        }
        waitForExpectationsWithTimeout(3.0, handler: nil)
        
        let emptyDocs = self.listItemsAtURL()
        XCTAssertEqual(stormcloud.metadataList.count, 0)
        XCTAssertEqual(stormcloud.metadataList.count, emptyDocs.count)
    }
    
    func testThatAddingAnItemPlacesItInRightPosition() {
        
        self.copyItems()
        let stormcloud = Stormcloud()
        let newDocs = self.listItemsAtURL()
        XCTAssertEqual(stormcloud.metadataList.count, 2)
        XCTAssertEqual(stormcloud.metadataList.count, newDocs.count)
		
		
		
        let expectation = expectationWithDescription("Adding new item")
        stormcloud.backupObjectsToJSON(["Test" : "Test"]) { ( error,  metadata) -> () in
            
            XCTAssertNil(error)
            
            XCTAssertEqual(stormcloud.metadataList.count, 3)

            if stormcloud.metadataList.count == 3 {
                XCTAssert(stormcloud.metadataList[0].filename.containsString("2020"))
                XCTAssert(stormcloud.metadataList[1].filename.containsString("\(self.year)"))
                XCTAssert(stormcloud.metadataList[2].filename.containsString("2014"))
                
            }
            
        
            expectation.fulfill()
        }
        waitForExpectationsWithTimeout(3.0, handler: nil)
        
        let threeDocs = self.listItemsAtURL()
        XCTAssertEqual(stormcloud.metadataList.count, 3)
        XCTAssertEqual(stormcloud.metadataList.count, threeDocs.count)
        
    }
    
    func testThatFilenameDatesAreConvertedToLocalTime() {
        
        let stormcloud = Stormcloud()
        let dateComponents = NSCalendar.currentCalendar().components([.Year, .Month, .Day, .Hour, .Minute], fromDate: NSDate())
        dateComponents.timeZone = NSTimeZone(abbreviation: "UTC")
        dateComponents.calendar = NSCalendar.currentCalendar()
        guard let date = dateComponents.date else {
            XCTFail()
            return
        }
        
        let expectation = expectationWithDescription("Adding new item")
        stormcloud.backupObjectsToJSON(["Test" : "Test"]) { (error,  metadata) -> () in
            
            XCTAssertNil(error)
            
            if let hasMetadata = metadata {
                let dateComponents = NSCalendar.currentCalendar().components([.Year, .Month, .Day, .Hour, .Minute], fromDate: hasMetadata.date)
                dateComponents.calendar = NSCalendar.currentCalendar()
                if let metaDatadate = dateComponents.date {
                    XCTAssertEqual(date, metaDatadate)
                }
            }
            
            expectation.fulfill()
        }
        waitForExpectationsWithTimeout(3.0, handler: nil)
        
        
        
    }
    
    
    func testThatMaximumBackupLimitsAreRespected() {
        self.copyItems()
        let stormcloud = Stormcloud()
        stormcloud.fileLimit = 2
        let newDocs = self.listItemsAtURL()
        XCTAssertEqual(stormcloud.metadataList.count, 2)
        XCTAssertEqual(stormcloud.metadataList.count, newDocs.count)

        let expectation = expectationWithDescription("Adding new item")
        stormcloud.backupObjectsToJSON(["Test" : "Test"]) { (error,  metadata) -> () in
            
            XCTAssertNil(error)
            
            XCTAssertEqual(stormcloud.metadataList.count, 3)
            
            expectation.fulfill()
        }
        waitForExpectationsWithTimeout(3.0, handler: nil)
		
        let deleteExpectation = expectationWithDescription("Deleting new item")
		stormcloud.deleteItemsOverLimit { (error) in
			XCTAssertNil(error)
			
			XCTAssertEqual(stormcloud.metadataList.count, 2)
			
			deleteExpectation.fulfill()
		}
		waitForExpectationsWithTimeout(3.0, handler: nil)
		
        let stillTwoDocs = self.listItemsAtURL()
        XCTAssertEqual(stormcloud.metadataList.count, stillTwoDocs.count)
        
        if stormcloud.metadataList.count == 2 {
            // It should delete the oldest one
            XCTAssert(stormcloud.metadataList[0].filename.containsString("2020"))
            XCTAssert(stormcloud.metadataList[1].filename.containsString("\(year)"), "Deleted the wrong file!")
        } else {
            XCTFail("Document number incorrect")
        }
    }
    
    func testThatRestoringAFileWorks() {
        self.copyItems()
        let stormcloud = Stormcloud()
        let newDocs = self.listItemsAtURL()
        XCTAssertEqual(stormcloud.metadataList.count, 2)
        XCTAssertEqual(stormcloud.metadataList.count, newDocs.count)
        let expectation = expectationWithDescription("Restoring item")        
        
        let metadata = stormcloud.metadataList[0]
        
        stormcloud.restoreBackup(withMetadata: metadata) { (error, restoredObjects) -> () in
            XCTAssertNil(error)
            
            XCTAssertNotNil(restoredObjects)
            
            if let dictionary = restoredObjects as? [String : AnyObject], model = dictionary["Model"] as? String {
                XCTAssertEqual(model, "iPhone")
                
            } else {
                XCTFail("Restored objects not valid")
            }
            
            expectation.fulfill()
            
        }
        
        waitForExpectationsWithTimeout(4.0, handler: nil)
        
    }
    
    
}
