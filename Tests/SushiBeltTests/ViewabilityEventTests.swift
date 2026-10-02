import Testing
import UIKit

@testable import KarrotImpression

@MainActor
struct ViewabilityEventTests {
  private final class NestedTarget: ImpressionDetectorTarget, ImpressionInnerScrollable {
    let frameInWindow = CGRect(x: 0, y: 0, width: 100, height: 100)
    var operations: [String] = []
    func trackImpressionEvent() { operations.append("track") }
    func clearImpressionEvent() { operations.append("clear") }
  }

  private func makeSUT() -> (VisibleStateDetector, ImpressionEventTracker) {
    let detector = VisibleStateDetector(
      sushiBeltTracker: SushiBeltTracker(),
      sushiBeltDebugger: SushiBeltDebuggerSpy()
    )
    return (detector, ImpressionEventTracker(
      detector: detector,
      application: UIApplication.self,
      cooltimeCache: InMemoryImpressionCooltimeCacheImpl(dateProvider: { Date() }),
      usesInitialVisibility: false
    ))
  }

  private func makeItem(marker: String = "original", kind: VisibleStateDetectorItem.TrackingKind = .viewability) -> VisibleStateDetectorItem {
    VisibleStateDetectorItem(
      id: "item",
      target: UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 100)),
      ratio: kind == .impression ? 0.1 : 0.5,
      userInfo: ["marker": marker],
      kind: kind
    )
  }

  @Test
  func test_viewability_should_use_its_own_ratio_and_bypass_the_impression_filter() {
    let (detector, tracker) = makeSUT()
    let item = makeItem()
    var impressions = 0
    var events: [String] = []
    tracker.setFilter { _ in false }
    tracker.subscribe { _ in impressions += 1 }
    tracker.subscribeViewability { event in
      switch event {
      case .entered: events.append("enter")
      case .exited: events.append("exit")
      }
    }

    for height in [30, 50, 70, 49, 80] {
      detector.detect(items: [makeItem(kind: .impression), item]) { CGRect(x: 0, y: 0, width: 100, height: height) }
    }

    #expect(impressions == 0)
    #expect(events == ["enter", "exit", "enter"])
  }

  @Test
  func test_clear_should_exit_with_the_original_item_for_a_viewability_only_subscription() {
    let (detector, tracker) = makeSUT()
    var exitedMarkers: [String] = []
    tracker.subscribeViewability { event in
      if case .exited(let item) = event {
        exitedMarkers.append(item.userInfo?["marker"] as? String ?? "missing")
      }
    }
    let rect = CGRect(x: 0, y: 0, width: 100, height: 100)
    detector.detect(items: [makeItem()]) { rect }
    detector.detect(items: [makeItem(marker: "reconfigured")]) { rect }

    tracker.clearCache()
    tracker.clearCache()

    #expect(exitedMarkers == ["original"])
  }

  @Test
  func test_removal_should_exit_and_reentry_with_the_same_id_should_start_a_new_session() {
    let (detector, tracker) = makeSUT()
    var events: [String] = []
    tracker.subscribeViewability { event in
      switch event {
      case .entered: events.append("enter")
      case .exited: events.append("exit")
      }
    }
    let rect = CGRect(x: 0, y: 0, width: 100, height: 100)

    detector.detect(items: [makeItem()]) { rect }
    detector.detect(items: []) { rect }
    detector.detect(items: [makeItem()]) { rect }
    tracker.clearCache()

    #expect(events == ["enter", "exit", "enter", "exit"])
  }

  @Test
  func test_viewability_should_reenter_during_the_impression_cooldown() {
    let (detector, tracker) = makeSUT()
    let item = VisibleStateDetectorItem(
      id: "item",
      target: UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 100)),
      ratio: 0.1,
      cooltime: .init(key: "item", coolingTime: 60)
    )
    var impressions = 0
    var entries = 0
    tracker.subscribe { _ in impressions += 1 }
    tracker.subscribeViewability { event in
      if case .entered = event { entries += 1 }
    }
    let rect = CGRect(x: 0, y: 0, width: 100, height: 100)

    detector.detect(items: [item, makeItem()]) { rect }
    tracker.clearCache()
    detector.detect(items: [item, makeItem()]) { rect }

    #expect(impressions == 1)
    #expect(entries == 2)
  }

  @Test
  func test_impression_items_should_not_deliver_viewability_events() {
    let (detector, tracker) = makeSUT()
    var impressions = 0
    var viewabilityCount = 0
    tracker.subscribe { _ in impressions += 1 }
    tracker.subscribeViewability { _ in viewabilityCount += 1 }
    let item = makeItem(kind: .impression)

    detector.detect(items: [item]) { CGRect(x: 0, y: 0, width: 100, height: 100) }
    tracker.clearCache()

    #expect(impressions == 1)
    #expect(viewabilityCount == 0)
  }

  @Test
  func test_items_with_the_same_id_should_track_each_kind_at_its_own_ratio() {
    let (detector, tracker) = makeSUT()
    let view = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
    let impression = VisibleStateDetectorItem(id: "same", target: view, ratio: 0.1)
    let viewability = VisibleStateDetectorItem(id: "same", target: view, ratio: 0.5, kind: .viewability)
    var events: [String] = []
    tracker.subscribe { _ in events.append("impression") }
    tracker.subscribeViewability {
      switch $0 {
      case .entered: events.append("enter")
      case .exited: events.append("exit")
      }
    }

    detector.detect(items: [impression, viewability]) { CGRect(x: 0, y: 0, width: 100, height: 30) }
    #expect(events == ["impression"])
    detector.detect(items: [impression, viewability]) { CGRect(x: 0, y: 0, width: 100, height: 60) }
    #expect(events == ["impression", "enter"])
    detector.detect(items: [viewability]) { CGRect(x: 0, y: 0, width: 100, height: 60) }
    #expect(events == ["impression", "enter"])
    tracker.clearCache()

    #expect(events == ["impression", "enter", "exit"])
    #expect(Set([impression, viewability]).count == 2)
    #expect(impression.kind == .impression)
  }

  @Test
  func test_adding_viewability_should_not_duplicate_nested_scroll_operations() {
    func operations(includeViewability: Bool) -> [String] {
      let (detector, tracker) = makeSUT()
      let view = NestedTarget()
      var items = [VisibleStateDetectorItem(id: "same", target: view, ratio: 0.1)]
      if includeViewability {
        items.append(VisibleStateDetectorItem(id: "same", target: view, ratio: 0.5, kind: .viewability))
      }
      tracker.subscribe { _ in }
      tracker.subscribeViewability { _ in }
      detector.detect(items: items) { CGRect(x: 0, y: 0, width: 100, height: 100) }
      tracker.clearCache()
      return view.operations
    }

    let baseline = operations(includeViewability: false)
    let combined = operations(includeViewability: true)

    #expect(!baseline.isEmpty)
    #expect(combined == baseline)
  }

  @Test
  func test_reentry_should_capture_the_updated_payload_after_exiting_with_the_original() {
    let (detector, tracker) = makeSUT()
    var events: [String] = []
    tracker.subscribeViewability { event in
      switch event {
      case .entered(let item): events.append("enter:\(item.userInfo?["marker"] as? String ?? "missing")")
      case .exited(let item): events.append("exit:\(item.userInfo?["marker"] as? String ?? "missing")")
      }
    }
    let visible = CGRect(x: 0, y: 0, width: 100, height: 100)
    let belowThreshold = CGRect(x: 0, y: 0, width: 100, height: 30)

    detector.detect(items: [makeItem()]) { visible }
    detector.detect(items: [makeItem(marker: "updated")]) { visible }
    detector.detect(items: [makeItem(marker: "updated")]) { belowThreshold }
    detector.detect(items: [makeItem(marker: "updated")]) { visible }
    tracker.clearCache()

    #expect(events == ["enter:original", "exit:original", "enter:updated", "exit:updated"])
  }

  @Test
  func test_invalid_viewability_ratios_should_exit_once_and_allow_a_valid_reentry() {
    let (detector, tracker) = makeSUT()
    var events: [String] = []
    tracker.subscribeViewability { event in
      switch event {
      case .entered: events.append("enter")
      case .exited: events.append("exit")
      }
    }
    let visible = CGRect(x: 0, y: 0, width: 100, height: 100)

    detector.detect(items: [makeItem()]) { visible }
    let invalidRatios: [CGFloat] = [.nan, .infinity, -0.1, 1.1]
    for ratio in invalidRatios {
      let item = VisibleStateDetectorItem(
        id: "item", target: UIView(frame: visible), ratio: ratio, kind: .viewability
      )
      detector.detect(items: [item]) { visible }
    }
    detector.detect(items: [makeItem()]) { visible }
    tracker.clearCache()

    #expect(events == ["enter", "exit", "enter", "exit"])
  }

  @Test
  func test_viewability_only_items_should_not_forward_nested_scroll_operations() {
    let (detector, tracker) = makeSUT()
    let target = NestedTarget()
    let item = VisibleStateDetectorItem(id: "nested", target: target, ratio: 0.5, kind: .viewability)
    var events: [String] = []
    tracker.subscribeViewability { event in
      switch event {
      case .entered: events.append("enter")
      case .exited: events.append("exit")
      }
    }

    detector.detect(items: [item]) { CGRect(x: 0, y: 0, width: 100, height: 100) }
    tracker.clearCache()
    tracker.clearCache()

    #expect(target.operations.isEmpty)
    #expect(events == ["enter", "exit"])
  }

  @Test
  func test_removal_should_release_the_original_target_after_delivering_exit() {
    let (detector, tracker) = makeSUT()
    let visible = CGRect(x: 0, y: 0, width: 100, height: 100)
    weak var originalTarget: UIView?
    var exitedMarkers: [String] = []
    tracker.subscribeViewability { event in
      if case .exited(let item) = event {
        exitedMarkers.append(item.userInfo?["marker"] as? String ?? "missing")
      }
    }
    autoreleasepool {
      let target = UIView(frame: visible)
      originalTarget = target
      let item = VisibleStateDetectorItem(
        id: "item", target: target, ratio: 0.5, userInfo: ["marker": "original"], kind: .viewability
      )
      detector.detect(items: [item]) { visible }
    }
    detector.detect(items: [makeItem(marker: "updated")]) { visible }
    #expect(originalTarget != nil)

    autoreleasepool {
      detector.detect(items: []) { visible }
    }

    #expect(exitedMarkers == ["original"])
    #expect(originalTarget == nil)
  }
}
