//
//  MochiWidgetBundle.swift
//  MochiWidget
//
//  Created by Harsha on 17/01/26.
//

import WidgetKit
import SwiftUI

@main
struct MochiWidgetBundle: WidgetBundle {
    var body: some Widget {
        MochiWidget()
        MochiWidgetControl()
        MochiWidgetLiveActivity()
    }
}
