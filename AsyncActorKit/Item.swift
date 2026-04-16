//
//  Item.swift
//  AsyncActorKit
//
//  Created by Ravi Ranjan on 16/04/26.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
