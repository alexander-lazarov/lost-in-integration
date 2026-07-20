//
//  Item.swift
//  Lost in Integration
//
//  Created by Alexander Lazarov on 20.07.26.
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
