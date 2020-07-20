//
//  FilesGroup.swift
//  MetCenter
//
//  Created by CavanSu on 2019/6/18.
//  Copyright © 2019 Agora. All rights reserved.
//

import Foundation
import AliyunOSSiOS

// MARK: - FilesGroup
class FilesGroup: NSObject {
    static let cacheDirectory: String = {
        #if os(iOS)
        let path = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first! + "/"
        #else
        let path = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true).first! + "/"
        #endif
        return path
    }()
    
    private var ossClient: OSSClient!
    
    var images = ImageFiles()
    var logs = LogFiles()
    
    override init() {
        super.init()
        checkUselessZipFile()
    }
    
    static func check(folderPath: String) {
        let manager = FileManager.default
        
        if !manager.fileExists(atPath: folderPath, isDirectory: nil) {
            try? manager.createDirectory(atPath: folderPath, withIntermediateDirectories: true, attributes: nil)
        }
    }
    
    func removeUselessZip(_ path: String) {
        let manager = FileManager.default
        try? manager.removeItem(atPath: path)
    }
    
    func checkUselessZipFile() {
        let manager = FileManager.default
        let rootPath = FilesGroup.cacheDirectory
        let direcEnumerator = manager.enumerator(atPath: rootPath)
        var zipsList = [String]()
        
        while let file = direcEnumerator?.nextObject() as? String {
            if !file.contains(".zip") {
                continue
            }
            
            let fullPath = "\(rootPath)/\(file)"
            zipsList.append(fullPath)
        }
        
        for item in zipsList {
            removeUselessZip(item)
        }
    }
}

private extension FilesGroup {
    func createOssClient(authServerURL: String, endPoint: String) {
        let provider = OSSAuthCredentialProvider(authServerUrl: authServerURL)
        let configuration = OSSClientConfiguration()
        self.ossClient = OSSClient(endpoint: endPoint, credentialProvider: provider, clientConfiguration: configuration)
    }
    
    func ossClientUpload(filePath: String, success: Completion, fail: ErrorCompletion) {
        let request = OSSPutObjectRequest()
        request.bucketName = ""
        
        let pathArray = filePath.components(separatedBy: "/")
        request.objectKey = pathArray.last!
        
        request.uploadingFileURL = URL(string: filePath)!
        
        let callbackURL = "https://api.agora.io/scenario/meeting/v1/log/sts/callback"
        let callbackParameters = ["callbackUrl": callbackURL,
                                  "callbackBody": "",
                                  "callbackBodyType": ""]
        
        request.callbackParam = callbackParameters
        
        let task = ossClient.putObject(request)
        task.continue({ (task) -> Any? in
            if let error = task.error {
                
            } else {
                guard let uploadResult = task.result else {
                    return nil
                }
                
                
            }
            
            return nil
        }, cancellationToken: nil)
    }
}
