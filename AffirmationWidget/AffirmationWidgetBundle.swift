//
//  AffirmationWidgetBundle.swift
//  AffirmationWidget
//
//  Created by Bethany Curtis on 4/4/25.
//

import WidgetKit
import SwiftUI

@main
struct AffirmationWidgetBundle: WidgetBundle {
    var body: some Widget {
        AffirmationWidget()
        AffirmationWidgetControl()
        AffirmationWidgetLiveActivity()
    }
}
