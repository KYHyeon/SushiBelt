# UIKit visibility events

Unreleased API. A single tracker delivers normal impressions and continuous
visibility transitions independently. Duration thresholds, item business IDs,
session storage, and event delivery belong to the caller.

## Declare both thresholds

```swift
let impressionItem = VisibleStateDetectorItem(
  id: itemID,
  target: cell,
  ratio: 0.1
)
let visibilityItem = VisibleStateDetectorItem(
  id: itemID,
  target: cell,
  ratio: 0.5,
  kind: .visibility
)
```

Each item uses its own `ratio`. `kind` defaults to `.impression`;
`.visibility` enables continuous enter/exit events. Visibility ratios must be
finite values in `0...1`. The pair `(id, kind)` must be unique within the tracker.
Use `DefaultDetectorItemFactory(itemsMapper:)` to return both items for a cell;
the existing single-item `mapper:` initializer remains available. Nested scroll
tracking and clearing are forwarded only by `.impression` items.

## Subscribe independently

```swift
tracker.subscribe { item in
  // Normal impression, after the existing filter and cooldown.
}

tracker.subscribeVisibility { event in
  switch event {
  case .entered(let item):
    // Save the start time and immutable application payload.
  case .exited(let item):
    // Remove the matching session and evaluate its duration.
  }
}
```

- Visibility bypasses the impression filter and cooldown.
- Visibility-only subscriptions are supported.
- Exits occur below the threshold, on removal, and on `clearCache()`.
- The exit carries the item captured at entry, not the current reused cell data.
- Registering with a view controller also clears tracking when that controller
  disappears or the application resigns active. The scroll-view-only overload
  leaves lifecycle forwarding to its owner.
- Callbacks are synchronous with detection. Perform registration and tracking
  operations on the main thread. Do not mutate the tracker from its callbacks.

## Replace a list

```swift
tracker.clearCache()  // Emits exits for active sessions before replacing data.

applySnapshot {
  tracker.trackManually(shouldResetCache: false)
}
```

For an append, omit `clearCache()` to preserve existing sessions.

## Compatibility

Existing `subscribe` calls and item initializers keep their behavior. Custom
`ImpressionEventTrackable` implementations and generated mocks must implement
the new `subscribeVisibility` requirement. SwiftUI APIs are unchanged.
