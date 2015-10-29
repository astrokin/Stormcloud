import UIKit
import Stormcloud
import CoreData

enum ICEDefaultsKeys : String {
    case Setting1 = "com.voyagetravelapps.iCloud-Extravaganza.Setting1PrefKey"
    case Setting2 = "com.voyagetravelapps.iCloud-Extravaganza.Setting2PrefKey"
    case Setting3 = "com.voyagetravelapps.iCloud-Extravaganza.Setting3PrefKey"
    case textValue = "com.voyagetravelapps.iCloud-Extravaganza.TextValuePrefKey"
    case stepperValue = "com.voyagetravelapps.iCloud-Extravaganza.StepperValuePrefKey"
    case iCloudToken = "nosync.com.voyagetravelapps.iCloud-Extravaganza.ubiquityToken"
}

enum ICEEnvironmentKeys : String, StormcloudEnvironmentVariable {
    case DeleteAllItems = "ICEDeleteAllItems"
    case MoveDefaultItems = "ICEMoveDefaultItems"
    func stringValue() -> String {
        return self.rawValue
    }
}


//
//struct environment {
//    let deleteAllItems : Bool
//    init() {
//        let env = NSProcessInfo.processInfo().environment
//        if let _ = env["ICEDeleteAllItems"]  {
//            deleteAllItems = true
//        } else {
//            deleteAllItems = false
//        }
//    }
//}

enum ICEFetchRequests : String, CoreDataStackFetchTemplate {
    case CloudFetch = "CloudFetch"
    func fetchRequestName() -> String {
        return self.rawValue
    }
}


@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    let coreDataStack = CoreDataStack(modelName: "clouds")
    
    var window: UIWindow?
    
    var defaultsManager : StormcloudDefaultsManager = StormcloudDefaultsManager()
    
    
    
    func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {
        // Override point for customization after application launch.
        self.defaultsManager.prefix = "com.voyagetravelapps.iCloud-Extravaganza"
        
        
        
        
        
        let adder = CloudAdder(context: nil)
        
        if ICEEnvironmentKeys.DeleteAllItems.isEnabled() {
            adder.deleteAllFiles()
        }
        if ICEEnvironmentKeys.MoveDefaultItems.isEnabled() {
            adder.copyDefaultFiles("json")
        }
        
        
        coreDataStack.setupStore { () -> Void in
            if let context = self.coreDataStack.managedObjectContext {
                
                let adder = CloudAdder(context: context)
                
                if CoreDataStackEnvironmentVariables.UseMemoryStore.isEnabled() {
                    for var i = 1; i <= 1000; i++ {
                        adder.addCloudWithNumber(i, addRaindrops : true)
                    }
                }
            }
            
            if let vc = self.window?.rootViewController as? SettingsViewController {
                vc.stack = self.coreDataStack
            }
            
            
        }
        
        return true
    }
    
    
    
    
    func applicationWillResignActive(application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
    }
    
    func applicationDidEnterBackground(application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
        self.coreDataStack.save()
    }
    
    func applicationWillEnterForeground(application: UIApplication) {
        // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
    }
    
    func applicationDidBecomeActive(application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }
    
    func applicationWillTerminate(application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }
    
    
}

class CloudAdder : NSObject {
    let context : NSManagedObjectContext?
    
    let docsURL = NSFileManager.defaultManager().URLsForDirectory(.DocumentDirectory, inDomains: .UserDomainMask).first
    
    init(context : NSManagedObjectContext? ) {
        self.context = context
    }
    
    
    func addCloudWithNumber(number : Int, addRaindrops : Bool ) {
        guard let context = self.context else {
            return
        }
        
        
        let cloud1 : Cloud
        do {
            cloud1 = try Cloud.insertCloudWithName("Cloud \(number)", order: number, didRain: false, inContext: context)
            if addRaindrops {
                _ = try? Raindrop.insertRaindropWithType(RaindropType.Heavy, withCloud: cloud1, inContext: context)
                _ = try? Raindrop.insertRaindropWithType(RaindropType.Heavy, withCloud: cloud1, inContext: context)
                _ = try? Raindrop.insertRaindropWithType(RaindropType.Light, withCloud: cloud1, inContext: context)
            }
            
        } catch {
            print("Error inserting cloud!")
        }
    }
    
    
    
    func addDefaultClouds() {
        guard let context = self.context else {
            return
        }
        
        
        let request = NSFetchRequest(entityName: "Cloud")
        let clouds : AnyObject
        do {
            clouds = try context.executeFetchRequest(request)
        } catch {
            clouds = []
        }
        
        print(clouds.count)
        
        self.addCloudWithNumber(clouds.count, addRaindrops : true)
        self.addCloudWithNumber(clouds.count + 1, addRaindrops : true)
    }
    
    func deleteAllFiles() {
        let docs = self.listItemsAtURL()
        for url in docs {
            if url.pathExtension == "json" {
                do {
                    try NSFileManager.defaultManager().removeItemAtURL(url)
                } catch {
                    print("Couldn't delete item")
                }
            }
        }
        
    }
    
    func listItemsAtURL() -> [NSURL] {
        var jsonDocs : [NSURL] = []
        if let docsURL = docsURL {
            var docs : [NSURL] = []
            do {
                print(docsURL)
                docs = try NSFileManager.defaultManager().contentsOfDirectoryAtURL(docsURL, includingPropertiesForKeys: nil, options: NSDirectoryEnumerationOptions())
            } catch let error as NSError {
                print("\(docsURL) path not available.\(error.localizedDescription)")
            }
            
            for url in docs {
                if url.pathExtension == "json" {
                    jsonDocs.append(url)
                }
            }
        }
        return jsonDocs
    }
    
    
    
    func copyDefaultFiles(name : String ) {
        if let fileURLs = NSBundle.mainBundle().URLsForResourcesWithExtension(".json", subdirectory: nil), docsURL = NSFileManager.defaultManager().URLsForDirectory(.DocumentDirectory, inDomains: .UserDomainMask).first {
            print(docsURL)
            for url in fileURLs {
                let finalURL = docsURL.URLByAppendingPathComponent(url.lastPathComponent!)
                
                do {
                    try NSFileManager.defaultManager().copyItemAtURL(url, toURL: finalURL)
                } catch let error as NSError {
                    print("Couldn't copy files \(error.localizedDescription)")
                }
                
            }
        }
    }
}

