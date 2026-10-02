import UIKit

final class ViewabilityTrackingItem: TrackingItem {
  let trackingIdentifer: String
  var registration: VisibleStateDetectorItem
  var target: ImpressionDetectorTarget { registration.target }
  var ratio: CGFloat { registration.ratio }
  let tracksExit = true
  private var enteredItem: VisibleStateDetectorItem?

  var isValid: Bool {
    return ratio.isFinite && (0...1).contains(ratio)
  }

  init(item: VisibleStateDetectorItem) {
    trackingIdentifer = item.trackingIdentifer
    registration = item
  }

  func receive(_ event: TrackingEvent, delegate: VisibleStateDetectorDelegate?) {
    switch event {
    case .entered:
      guard enteredItem == nil else { return }
      enteredItem = registration
      delegate?.onViewabilityChanged(.entered(registration))
    case .exited:
      guard let original = enteredItem else { return }
      enteredItem = nil
      delegate?.onViewabilityChanged(.exited(original))
    case .ended, .evaluated, .clearing:
      break
    }
  }
}
