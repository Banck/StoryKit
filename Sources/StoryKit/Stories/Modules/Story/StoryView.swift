//
//  StoryView.swift
//  OlimpBetAppClip
//
//  Created by Sakhabaev Egor on 11.04.2024.
//

import SwiftUI

struct StoryView: View {

    @Environment(\.presentationMode) var presentation
    @ObservedObject var viewModel: StoryViewModel
    private var safeAreaInsets: EdgeInsets?

    init(
        viewModel: StoryViewModel,
        safeAreaInsets: EdgeInsets? = nil
    ) {
        self.viewModel = viewModel
        self.safeAreaInsets = safeAreaInsets
    }

    var body: some View {
		ZStack {
			overlayedContent()
		}
		.coordinateSpace(name: "StorySpace")
    }
	
	@ViewBuilder
	func overlayedContent() -> some View {
		contentView()
			.frame(maxWidth: .infinity, maxHeight: .infinity)
			.overlay(
				GeometryReader { geo in
					progress()
						.onAppear {
							let frame = geo.frame(in: .named("StorySpace"))
							viewModel.progressFrame = frame
						}
						.animation(.linear, value: viewModel.progressColor)
				}
					.frame(height: 2)
					.padding(.top, (safeAreaInsets?.top ?? 0) + 8),
				alignment: .top
			)
			.overlay(
				Button {
					viewModel.didDismiss()
					presentation.wrappedValue.dismiss()
				} label: {
					GeometryReader { geo in
						Image(systemName: "xmark")
							.font(.system(size: 24))
							.foregroundColor(viewModel.closeColor)
							.frame(width: 48, height: 44)
							.onAppear {
								let frame = geo.frame(in: .named("StorySpace"))
								viewModel.closeFrame = frame
							}
							.animation(.linear, value: viewModel.closeColor)
					}
					.frame(width: 48, height: 44)
					.padding(.top, (safeAreaInsets?.top ?? 0) + 18)
				},
				alignment: .topTrailing
			)
			.background(controls())
			.background(Color(hex: "1A1A1A"))
			.onAppear {
				viewModel.viewDidAppear()
			}
			.onDisappear {
				viewModel.viewDidDisappear()
			}
	}

    @ViewBuilder
    func contentView() -> some View {
        switch viewModel.pagesData[viewModel.currentPageIndex] {
        case .none, .loading:
            VStack(alignment: .center) {
                Spacer()
                LoaderView(color: .white.opacity(0.5))
                    .frame(width: 42, height: 42, alignment: .center)
                Spacer()
            }
            .frame(maxWidth: .infinity)
        case .loaded(let data):
            PageView(pageData: data, isPaused: $viewModel.isPagePaused)
                .id(data.id)
                .onAppear {
                    viewModel.pageContentDidAppear()
                }
        case .failed(let error):
            if let view = viewModel.failureView(forError: error) {
                view
            } else {
                VStack {
                    Spacer()
                    Button {
                        viewModel.reloadPage()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 41))
                            .foregroundColor(.white)
                    }
                    Spacer()
                }
            }
        }
    }

    @ViewBuilder
    func progress() -> some View {
        HStack(spacing: 4) {
            ForEach(Array(viewModel.story.pages.enumerated()), id: \.element.id) { index, _ in
				ProgressView(
					progress: viewModel.progress(forPageIndex: index),
					color: viewModel.progressColor
				)
            }
        }
        .frame(height: 2)
        .padding(.horizontal, 8)
    }

    @ViewBuilder
    func controls() -> some View {
        HStack(spacing: 0) {
            Rectangle()
                .contentShape(Rectangle())
                .highPriorityGesture(
                    TapGesture()
                        .onEnded {
                            viewModel.didSelectPreviousPage()
                        }
                )
            Rectangle()
                .contentShape(Rectangle())
                .highPriorityGesture(
                    TapGesture()
                        .onEnded {
                            viewModel.didSelectNextPage()
                        }
                )
        }
        .onLongPressGesture(minimumDuration: .infinity, perform: { }) { bool in
            viewModel.didHold(ended: !bool)
        }
        .foregroundColor(.clear)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    return StoryView(
        viewModel: .init(
            story: .init(
                id: UUID().uuidString,
                pages: [
                    .init(
                        id: UUID().uuidString,
                        duration: 15,
                        contentType: .image(url: .init(string: "https://m.media-amazon.com/images/I/71HvRxH2bgL._AC_UF1000,1000_QL80_.jpg")!)
                    )
                ]
            ),
            isActive: true,
            didEndView: { _ in },
            didRequestBack: { _ in }
        )
    )
}
