//
//  VisibleStateDetector.swift
//  KarrotImpression
//
//  Created by Ben on 2023/06/02.
//  Copyright © 2023 Danggeun Market Inc. All rights reserved.
//

import UIKit

final class VisibleStateDetector: VisibleStateDetectable {

  weak var delegate: VisibleStateDetectorDelegate?

  private let sushiBeltTracker: SushiBeltTrackerProtocol
  private let sushiBeltDebugger: SushiBeltDebuggerLogic
  private var items = Set<VisibleStateDetectorItem>()
  private var trackingRectProvider: (() -> CGRect)?
  private var visibleSessions: [String: VisibleStateDetectorItem] = [:]

  init(
    sushiBeltTracker: SushiBeltTrackerProtocol,
    sushiBeltDebugger: SushiBeltDebuggerLogic,
  ) {
    self.sushiBeltTracker = sushiBeltTracker
    self.sushiBeltDebugger = sushiBeltDebugger
    sushiBeltTracker.dataSource = self
    sushiBeltTracker.delegate = self
  }

  func detect(items: [VisibleStateDetectorItem], trackingRect: @escaping () -> CGRect) {
    self.items = Set(items)
    trackingRectProvider = trackingRect

    let viewport = trackingRect()
    let sushiBeltTrackerItems = self.items.compactMap { item -> SushiBeltTrackerItem? in
      let frame = item.target.frameInWindow
      guard viewport.intersection(frame).height > 0 else { return nil }
      if item.kind == .visibility {
        guard item.ratio.isFinite, (0...1).contains(item.ratio) else { return nil }
      }
      return SushiBeltTrackerItem(
        id: .trackingIdentifier(item),
        rect: .init(frame: frame),
        tracksExit: item.kind == .visibility
      )
    }
    sushiBeltTracker.calculateItemsIfNeeded(items: sushiBeltTrackerItems)

    detectInnerScrollable()
  }

  func clear() {
    for item in items where item.kind == .impression {
      (item.target as? ImpressionInnerScrollable)?.clearImpressionEvent()
    }
    items = []
    sushiBeltTracker.calculateItemsIfNeeded(items: [])
  }

  func showDebugger() {
    sushiBeltTracker.registerDebugger(debugger: sushiBeltDebugger)
    sushiBeltDebugger.show()
  }

  private func detectInnerScrollable() {
    for item in items where item.kind == .impression {
      (item.target as? ImpressionInnerScrollable)?.trackImpressionEvent()
    }
  }
}

extension VisibleStateDetector: SushiBeltTrackerDataSource {

  func trackingRect(_ tracker: SushiBeltTracker) -> CGRect {
    trackingRectProvider?() ?? .zero
  }

  func visibleRatioForItem(_ tracker: SushiBeltTracker, item: SushiBeltTrackerItem) -> CGFloat {
    guard
      case .trackingIdentifier(let id) = item.id,
      let item = items.first(where: { $0.trackingIdentifer == id.trackingIdentifer })
    else {
      return .zero
    }
    return item.ratio
  }
}

extension VisibleStateDetector: SushiBeltTrackerDelegate {

  func willBeginTracking(_ tracker: SushiBeltTracker, item: SushiBeltTrackerItem) {
    // nothing
  }

  func didEnter(_ tracker: SushiBeltTracker, item: SushiBeltTrackerItem) {
    guard
      case .trackingIdentifier(let id) = item.id,
      let item = items.first(where: { $0.trackingIdentifer == id.trackingIdentifer })
    else {
      return
    }
    if item.kind == .visibility {
      guard visibleSessions[item.trackingIdentifer] == nil else { return }
      visibleSessions[item.trackingIdentifer] = item
      delegate?.onVisibilityChanged(.entered(item))
      return
    }
    delegate?.onDetect(visibleItem: item)
    (item.target as? ImpressionInnerScrollable)?.trackImpressionEvent()
  }

  func didEndTracking(_ tracker: SushiBeltTracker, item: SushiBeltTrackerItem) {
    guard
      case .trackingIdentifier(let id) = item.id,
      let target = id as? VisibleStateDetectorItem,
      target.kind == .impression,
      let item = items.first(where: { $0.trackingIdentifer == id.trackingIdentifer })?
        .target as? ImpressionInnerScrollable
    else {
      return
    }

    item.clearImpressionEvent()
  }

  func didExit(_ tracker: SushiBeltTracker, item: SushiBeltTrackerItem) {
    guard
      case .trackingIdentifier(let id) = item.id,
      let target = id as? VisibleStateDetectorItem,
      target.kind == .visibility,
      let original = visibleSessions.removeValue(forKey: target.trackingIdentifer)
    else { return }
    delegate?.onVisibilityChanged(.exited(original))
  }
}
