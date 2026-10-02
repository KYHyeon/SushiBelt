//
//  VisibleStateDetectorItem.swift
//  KarrotImpression
//
//  Created by Ben on 2023/06/02.
//  Copyright © 2023 Danggeun Market Inc. All rights reserved.
//

import UIKit

/// Describes a UIKit tracking target. Equality and hashing use `id` and `kind`.
public struct VisibleStateDetectorItem: Identifiable, Hashable {

  public enum TrackingKind: String, Hashable {
    case impression
    case visibility
  }

  public let id: String
  public let target: ImpressionDetectorTarget
  public let ratio: CGFloat
  public let kind: TrackingKind
  public let userInfo: [AnyHashable: Any]?

  /// The cooldown applied to this item.
  ///
  /// `nil` disables cooldown checking; it does not fall back to the item's `id`.
  /// Items with and without cooldowns can share a tracker.
  public let cooltime: ImpressionCooltime?

  public init(
    id: String,
    target: ImpressionDetectorTarget,
    ratio: CGFloat,
    userInfo: [AnyHashable: Any]? = nil,
    cooltime: ImpressionCooltime? = nil,
    kind: TrackingKind = .impression,
  ) {
    self.id = id
    self.target = target
    self.ratio = ratio
    self.userInfo = userInfo
    self.cooltime = cooltime
    self.kind = kind
  }

  public func hash(into hasher: inout Hasher) {
    hasher.combine(id)
    hasher.combine(kind)
  }

  public static func == (lhs: VisibleStateDetectorItem, rhs: VisibleStateDetectorItem) -> Bool {
    lhs.id == rhs.id && lhs.kind == rhs.kind
  }
}
