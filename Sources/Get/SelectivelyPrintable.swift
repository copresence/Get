import Foundation

/// The purpose of this type is to declutter logs in case you have JSON responses that
/// have a lot of extra properties in them that ultimately just clutter up your console log.
/// (I'm looking at you, Parse Server)
/// So you can specify some keypaths in your response JSON that you want to whitelist.
/**
 USAGE:
 
 Say you have json:
 
 ```
 let jsonString =
 """
 {
     "result": [
         {
             "objectId": "42",
             "name": "Steve",
             "details": {
                 "age": 45,
                 "orientation": "S"
             }
         },
         {
             "objectId": "44",
             "name": "Dave",
             "details": {
                 "age": 50,
                 "orientation": "G"
             }
         }
     ]
 }
 """
 ```
 
 and you don't want to print anything about "orientation", you could do:
 
 `let reduced = jsonDict.reduced(keepingKeyPaths: ["result.objectId", "result.name", "result.details.age"])`
 
 to yield: the same JSON with orientation removed when printed to a string.
 
 Or if you only wanted details and objectId,  you could do:
 
 `let reduced = jsonDict.reduced(keepingKeyPaths: ["result.objectId", "result.details"])`
 
 It includes anything 'past' the last key.
 
 So all you have to do for any Decodable model you are parsing with Get, just conform to this protocol and provide the schema in the JSON you are interested in.
 
 */
public protocol SelectivelyPrintableJSON {
    var keypathsOfInterest: [String]? { get }
}

extension SelectivelyPrintableJSON {
    var keypathsOfInterest: [String]? {
        return nil // you have to opt into this functionality.
    }
}

// MARK: - Internal Helpers

extension String {
    func keyPath(atDepth depth: Int) -> String? {
        let components = self.components(separatedBy: ".")
        if depth < components.count {
            return components[depth]
        }
        return nil
    }
}

extension [String: Any] {
    func reduced(keepingKeyPaths: [String], currentDepth: Int = 0) -> Self {
        var reduced = self
        let uniquePathsAtThisLevel = Set(keepingKeyPaths.compactMap {
            $0.keyPath(atDepth: currentDepth)
        })
        if uniquePathsAtThisLevel.count == 0 {
            // print("No more unique keys at depth: \(currentDepth). Returning.")
            return reduced
        }
        
        // print("Depth: \(currentDepth), \(uniquePathsAtThisLevel.joined(separator: ", "))")
        
        for (key, value) in self {
            if uniquePathsAtThisLevel.contains(key) {
                reduced[key] = value
            } else {
                reduced[key] = nil
            }
        }
        
        // print("Reduced at this level: \(reduced)")
        for (key, value) in reduced {
            if var nestedArray = value as? Array<Any> {
                for (index, element) in nestedArray.enumerated() {
                    if let nestedDict = element as? [String: Any] {
                        nestedArray[index] = nestedDict.reduced(keepingKeyPaths: keepingKeyPaths, currentDepth: currentDepth + 1)
                    }
                }
                reduced[key] = nestedArray
                
            } else if let nestedDict = value as? [String: Any] {
                reduced[key] = nestedDict.reduced(keepingKeyPaths: keepingKeyPaths, currentDepth: currentDepth + 1)
            }
        }
        return reduced
    }
}

extension Array<String> {
    var maxDepth: Int {
        var depth = 1
        forEach { element in
            depth = Swift.max(depth, element.maxKeyPathDepth)
        }
        return depth
    }
}

extension String {
    var maxKeyPathDepth: Int {
        return self.components(separatedBy: ".").count
    }
}

extension [[String: Any]] {
    
    func reduced(keepingKeyPaths: [String], currentDepth: Int = 0) -> Self {
        var reduced = self
        for (index, element) in self.enumerated() {
            reduced[index] = element.reduced(keepingKeyPaths: keepingKeyPaths, currentDepth: 0)
        }
        return reduced
    }
}
