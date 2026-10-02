import Foundation

final class ImpressionTrackingItem: TrackingItem {
  let trackingIdentifer: String
  var currentItem: VisibleStateDetectorItem?
  let tracksExit = false
  let isValid = true

  init(item: VisibleStateDetectorItem) {
    trackingIdentifer = item.trackingIdentifer
    currentItem = item
  }

  func receive(_ event: TrackingEvent, delegate: VisibleStateDetectorDelegate?) {
    guard let currentItem else { return }
    let nestedTarget = currentItem.target as? ImpressionInnerScrollable
    switch event {
    case .entered:
      delegate?.onDetect(visibleItem: currentItem)
      nestedTarget?.trackImpressionEvent()
    case .evaluated:
      nestedTarget?.trackImpressionEvent()
    case .ended, .clearing:
      nestedTarget?.clearImpressionEvent()
    case .exited:
      break
    }
  }
}
