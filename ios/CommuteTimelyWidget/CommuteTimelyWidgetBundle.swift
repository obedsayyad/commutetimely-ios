//
// CommuteTimelyWidgetBundle.swift
// CommuteTimelyWidget
//
// Widget Extension entry point for Home Screen widgets
//

import WidgetKit
import SwiftUI

@main
struct CommuteTimelyWidgetBundle: WidgetBundle {
    var body: some Widget {
        CommuteTimelyWidget()
        if #available(iOS 16.1, *) {
            CommuteLiveActivity()
        }
    }
}

