//
//  ProgressView.swift
//  
//
//  Created by Sakhabaev Egor on 12.04.2024.
//

import SwiftUI

struct ProgressView: View {

    var progress: Double
	var color: Color

    var body: some View {
        GeometryReader { geo in
            Capsule()
				.foregroundColor(color.opacity(0.3))
                .overlay(
                    Capsule()
						.fill(color)
                        .frame(width: geo.size.width * min(progress, 1.0)),
                    alignment: .leading
                )
        }
    }
}

#Preview {
    ZStack {
        Color.black
        ProgressView(progress: 0.5, color: .white)
            .frame(height: 2)
    }
}
