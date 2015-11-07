//
//  StormcloudMetadata.swift
//  Stormcloud
//
//  Created by Simon Fairbairn on 19/10/2015.
//  Copyright © 2015 Simon Fairbairn. All rights reserved.
//

import UIKit

@objc
public protocol StormcloudMetadataDelegate {
    func iCloudMetadataDidUpdate( metadata : StormcloudMetadata )
}

public class StormcloudMetadata: NSObject {
    
    public static let dateFormatter = NSDateFormatter()
    
    /// A delegate that can be notified when the state of the backup document changes
    public var delegate : StormcloudMetadataDelegate?
    
    public let date : NSDate
    
    /// The original Device UUID on which this backup was originally created
    public let deviceUUID : String
    public let device : String
    public let filename : String
    public var iCloudMetadata : NSMetadataItem? {
        didSet {
            self.delegate?.iCloudMetadataDidUpdate(self)
        }
    }
    
    /// A read only property indiciating whether or not the document currently exists in iCloud
    public var iniCloud : Bool {
        get {
            if let metadata = iCloudMetadata {
                if let isInCloud = metadata.valueForAttribute(NSMetadataUbiquitousItemIsUploadedKey) as? Bool {
                    return isInCloud
                }
                
            }
            return false
        }
    }

    /// A read only property indicating that returns true when the document is currently downloading
    public var isDownloading : Bool {
        get {
            if let metadata = iCloudMetadata {
                if let isDownloading = metadata.valueForAttribute(NSMetadataUbiquitousItemIsDownloadingKey) as? Bool {
                    return isDownloading
                }
            }
            return false
        }
    }
    
    /// A read only property that returns the percentage of the document that has downloaded
    public var percentDownloaded : Double {
        get {
            if let metadata = iCloudMetadata {
                if let downloaded = metadata.valueForAttribute(NSMetadataUbiquitousItemPercentDownloadedKey) as? Double {
                    self.internalPercentDownloaded =  downloaded
                }
            }
            return self.internalPercentDownloaded
        }
    }
    
    /// A read only property indicating that returns true when the document is currently uploading
    public var isUploading : Bool {
        get {
            if let metadata = iCloudMetadata {
                if let isUploading = metadata.valueForAttribute(NSMetadataUbiquitousItemIsUploadingKey) as? Bool {
                    return isUploading
                }
                
            }
            return false
        }
    }
    
    /// A read only property that returns the percentage of the document that has uploaded
    public var percentUploaded : Double {
        get {
            if let metadata = iCloudMetadata {
                if let uploaded = metadata.valueForAttribute(NSMetadataUbiquitousItemPercentUploadedKey) as? Double {
                    self.internalPercentUploaded =  uploaded
                }
            }
            return self.internalPercentUploaded
        }
    }
    
    var internalPercentUploaded : Double = 0
    var internalPercentDownloaded : Double = 0
    
    public override init() {
        let dateComponents = NSCalendar.currentCalendar().components([.Year, .Month, .Day, .Hour, .Minute, .Second], fromDate: NSDate())
        dateComponents.calendar = NSCalendar.currentCalendar()
        dateComponents.timeZone = NSTimeZone(abbreviation: "UTC")
        
        StormcloudMetadata.dateFormatter.dateFormat = "yyyy-MM-dd HH-mm-ss"

        self.device = UIDevice.currentDevice().model
        if let date = dateComponents.date {
            self.date = date
        } else {
            self.date = NSDate()
        }
        
        self.deviceUUID = StormcloudMetadata.getDeviceUUID()
        let stringDate = StormcloudMetadata.dateFormatter.stringFromDate(self.date)
        self.filename = "\(stringDate)--\(self.device)--\(self.deviceUUID).json"
    }
    
    
    public convenience init( fileURL : NSURL ) {
        var path = ""
        if let isPath = fileURL.lastPathComponent {
           path = isPath
        }
        self.init(path : path)
    }
    

    public init( path : String ) {
        StormcloudMetadata.dateFormatter.dateFormat = "yyyy-MM-dd HH-mm-ss"

        var filename = ""
        
        var date  = NSDate()
        
        var device = UIDevice.currentDevice().model
        var deviceUUID = StormcloudMetadata.getDeviceUUID()
        
        filename = path
        let components = path.componentsSeparatedByString("--")
        
        if components.count > 2 {
            if let newDate = StormcloudMetadata.dateFormatter.dateFromString(components[0]) {
                date = newDate
            }
            
            device = components[1]
            deviceUUID = components[2].stringByReplacingOccurrencesOfString(".json", withString: "")
        }
        self.filename = filename
        self.device = device
        self.deviceUUID = deviceUUID
        self.date = date
    }
    
    
    /**
     Use this to get a UUID for the current device, which is then cached and attached to the filename of the created document and can be used to find out if the document that this metadata represents was originally created on the saem device.
     
     - returns: The device UUID as a string
     */
    public class func getDeviceUUID() -> String {
        let currentDeviceUUIDKey = "VTADocumentsManagerDeviceKey"
        if let savedDevice = NSUserDefaults.standardUserDefaults().objectForKey(currentDeviceUUIDKey) as? String {
            return savedDevice
        } else {
            let uuid = NSUUID().UUIDString
            NSUserDefaults.standardUserDefaults().setObject(uuid, forKey: currentDeviceUUIDKey)
            return uuid
        }
    }
}

// MARK: - NSCopying 

extension StormcloudMetadata : NSCopying {
    public func copyWithZone(zone: NSZone) -> AnyObject {
        let backup = StormcloudMetadata(path : self.filename)
        return backup
    }
}
