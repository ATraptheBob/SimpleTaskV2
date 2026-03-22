//
//  TaskWidgetBundle.swift
//  TaskWidget
//
//  Created by Wilson Lee on 3/22/26.
//

import WidgetKit
import SwiftUI

@main
struct TaskWidgetBundle: WidgetBundle {
    var body: some Widget {
        TaskWidget()
        TaskWidgetControl()
    }
}
