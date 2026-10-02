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
  private var trackingItems: [String: any TrackingItem] = [:]
  private var trackingRectProvider: (() -> CGRect)?

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
    trackingRectProvider = trackingRect
    for item in trackingItems.values {
      item.currentItem = nil
    }
    for item in Set(items) {
      if let existing = trackingItems[item.trackingIdentifer] {
        existing.currentItem = item
      } else {
        trackingItems[item.trackingIdentifer] = makeTrackingItem(item)
      }
    }

    let viewport = trackingRect()
    let sushiBeltTrackerItems = trackingItems.values.compactMap {
      $0.makeTrackerItem(viewport: viewport)
    }
    sushiBeltTracker.calculateItemsIfNeeded(items: sushiBeltTrackerItems)
    trackingItems = trackingItems.filter { $0.value.currentItem != nil }
    for item in trackingItems.values {
      item.receive(.evaluated, delegate: delegate)
    }
  }

  func clear() {
    for item in trackingItems.values {
      item.receive(.clearing, delegate: delegate)
      item.currentItem = nil
    }
    sushiBeltTracker.calculateItemsIfNeeded(items: [])
    trackingItems.removeAll()
  }

  func showDebugger() {
    sushiBeltTracker.registerDebugger(debugger: sushiBeltDebugger)
    sushiBeltDebugger.show()
  }

  private func makeTrackingItem(_ item: VisibleStateDetectorItem) -> any TrackingItem {
    switch item.kind {
    case .impression:
      ImpressionTrackingItem(item: item)
    case .visibility:
      VisibilityTrackingItem(item: item)
    }
  }

  private func trackingItem(for item: SushiBeltTrackerItem) -> (any TrackingItem)? {
    guard case .trackingIdentifier(let identifier) = item.id else { return nil }
    return identifier as? any TrackingItem
  }
}

extension VisibleStateDetector: SushiBeltTrackerDataSource {

  func trackingRect(_ tracker: SushiBeltTracker) -> CGRect {
    trackingRectProvider?() ?? .zero
  }

  func visibleRatioForItem(_ tracker: SushiBeltTracker, item: SushiBeltTrackerItem) -> CGFloat {
    trackingItem(for: item)?.currentItem?.ratio ?? .zero
  }
}

extension VisibleStateDetector: SushiBeltTrackerDelegate {

  func willBeginTracking(_ tracker: SushiBeltTracker, item: SushiBeltTrackerItem) {
    // nothing
  }

  func didEnter(_ tracker: SushiBeltTracker, item: SushiBeltTrackerItem) {
    trackingItem(for: item)?.receive(.entered, delegate: delegate)
  }

  func didEndTracking(_ tracker: SushiBeltTracker, item: SushiBeltTrackerItem) {
    trackingItem(for: item)?.receive(.ended, delegate: delegate)
  }

  func didExit(_ tracker: SushiBeltTracker, item: SushiBeltTrackerItem) {
    trackingItem(for: item)?.receive(.exited, delegate: delegate)
  }
}
