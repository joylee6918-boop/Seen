//
//  Item.swift
//  '拾光'
//
//  Created by Maple on 2026/5/23.
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
