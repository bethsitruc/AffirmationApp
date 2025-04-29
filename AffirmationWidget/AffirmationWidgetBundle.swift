//
//  AffirmationWidgetBundle.swift
//  AffirmationWidget
//
//  Created by Bethany Curtis on 4/4/25.
//

import WidgetKit
import SwiftUI

/// Defines a bundle of widgets for the Affirmation App.
/// This bundle groups related widgets together for easier management.
struct AffirmationWidgetBundle: WidgetBundle {
    /// The collection of widgets included in this bundle.
    var body: some Widget {
        AffirmationWidget() // Displays a random or selected affirmation.
        AffirmationWidgetControl() // Provides user controls or interactions related to affirmations.
        AffirmationWidgetLiveActivity() // Supports live activities if available (e.g., real-time affirmation updates).
    }
}
