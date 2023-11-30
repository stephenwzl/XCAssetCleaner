//
//  main.swift
//  xcasset-clean
//
//  Created by stephenwzl on 2023/11/30.
//

import Foundation

// get argv
let argv = CommandLine.arguments
// get current working dir
var workingDir: String = FileManager.default.currentDirectoryPath

if argv.count >= 2 {
    workingDir = argv[1]
}

// if workingDir is relative path, turn to absolute path
if workingDir.starts(with: ".") {
    // change to absolute path
    workingDir = (FileManager.default.currentDirectoryPath.appendingPathComponent(workingDir) as NSString).standardizingPath
}

func log(_ msg: String) {
    print("[xcasset-clean]: \(msg)")
}

log("current working dir: \(workingDir)")

var count = 0
func walkAndCleanDir(_ workingDir: String) {
    // check is folder
    if workingDir.isFolderPath == false {
        return
    }
    let enumerator = FileManager.default.enumerator(atPath: workingDir)
    while let element = enumerator?.nextObject() as? String {
        if element.hasSuffix(".imageset") {
            let done = processingAssetFolder(workingDir.appendingPathComponent(element))
            if done {
                count += 1
                log("cleaned: \(element)")
            }
        } else if element.isFolderPath  {
            walkAndCleanDir(element)
        }
    }
}

extension String {
    var isFolderPath: Bool {
        var isDir: ObjCBool = false
        if !FileManager.default.fileExists(atPath: self, isDirectory: &isDir) {
            return false
        }
        return isDir.boolValue
    }
    func appendingPathComponent(_ item: String) -> String {
        return (self as NSString).appendingPathComponent(item)
    }
    
}

func processingAssetFolder(_ assetFolder: String) -> Bool {
    // get folder basename
    let folderName = (assetFolder as NSString).lastPathComponent.components(separatedBy: ".").first ?? ""
    if folderName.isEmpty {
        return false
    }
    // parse contents.json
    let contentsPath = assetFolder.appendingPathComponent("Contents.json")
    guard var contents = parseContentsJSON(contentsPath) else {
        return false
    }
    guard let images = contents["images"] as? [[String: String]] else {
        return false
    }
    var newImages = images
    var needClean = false
    for (index, item) in images.enumerated() {
        guard let filename = item["filename"],
              let scale = item["scale"] else {
            continue
        }
        // get filename extension
        let ext = (filename as NSString).pathExtension
        var newFileName = "\(folderName)@\(scale).\(ext)"
        if scale == "1x" {
            newFileName = "\(folderName).\(ext)"
        }
        if newFileName != filename {
            needClean = true
            // rename file
            let oldPath = assetFolder.appendingPathComponent(filename)
            let newPath = assetFolder.appendingPathComponent(newFileName)
            try? FileManager.default.moveItem(atPath: oldPath, toPath: newPath)
            newImages[index]["filename"] = newFileName
        }
    }
    if needClean {
        contents["images"] = newImages
        // write contents.json
        let data = try? JSONSerialization.data(withJSONObject: contents, options: .prettyPrinted)
        try? data?.write(to: URL(fileURLWithPath: contentsPath))
    }
    return needClean
}

@inlinable func parseContentsJSON(_ path: String) -> [String: Any]? {
    guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else {
        return nil
    }
    guard let json = try? JSONSerialization.jsonObject(with: data, options: .mutableContainers) as? [String: Any] else {
        return nil
    }
    return json
}

walkAndCleanDir(workingDir)
log("\(count) imageasset cleaned")

