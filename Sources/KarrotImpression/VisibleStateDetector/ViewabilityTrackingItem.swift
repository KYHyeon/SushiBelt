import Foundation

final class ViewabilityTrackingItem: TrackingItem {
  let trackingIdentifer: String
  var currentItem: VisibleStateDetectorItem?
  let tracksExit = true
  private var enteredItem: VisibleStateDetectorItem?

  var isValid: Bool {
    guard let ratio = currentItem?.ratio else { return false }
    return ratio.isFinite && (0...1).contains(ratio)
  }

  init(item: VisibleStateDetectorItem) {
    trackingIdentifer = item.trackingIdentifer
    currentItem = item
  }

  func receive(_ event: TrackingEvent, delegate: VisibleStateDetectorDelegate?) {
    switch event {
    case .entered:
      guard enteredItem == nil, let currentItem else { return }
      enteredItem = currentItem
      delegate?.onViewabilityChanged(.entered(currentItem))
    case .exited:
      guard let original = enteredItem else { return }
      enteredItem = nil
      delegate?.onViewabilityChanged(.exited(original))
    case .ended, .evaluated, .clearing:
      break
    }
  }
}
