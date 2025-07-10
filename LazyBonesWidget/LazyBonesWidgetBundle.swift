//
//  LazyBonesWidgetBundle.swift
//  LazyBonesWidget
//
//  Created by Денис Рюмин on 10.07.2025.
//

import WidgetKit
import SwiftUI

@main
struct LazyBonesWidgetBundle: WidgetBundle {
    var body: some Widget {
        LazyBonesWidget()
        LazyBonesWidgetControl()
        LazyBonesWidgetLiveActivity()
    }
}
