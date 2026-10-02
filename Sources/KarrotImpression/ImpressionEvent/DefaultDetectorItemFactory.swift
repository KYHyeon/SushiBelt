//
//  DefaultDetectorItemFactory.swift
//  KarrotImpression
//
//  Created by Jaxtyn on 2023/07/20.
//  Copyright © 2023 Danggeun Market Inc. All rights reserved.
//

import UIKit

/// Maps visible cells in a table or collection view to tracking items.
/// Other scroll view types produce no items; use a custom `DetectorItemFactory` for them.
public final class DefaultDetectorItemFactory: DetectorItemFactory {

  private let mapper: (UIView) -> [VisibleStateDetectorItem]

  public init(mapper: @escaping (UIView) -> VisibleStateDetectorItem?) {
    self.mapper = { mapper($0).map { [$0] } ?? [] }
  }

  /// Maps a visible cell to independent tracking items.
  public init(itemsMapper: @escaping (UIView) -> [VisibleStateDetectorItem]) {
    mapper = itemsMapper
  }

  public func makeVisibleDetectorItems(view: UIScrollView) -> [VisibleStateDetectorItem] {
    switch view {
    case let tableView as UITableView:
      tableView.visibleCells.flatMap { cell in
        mapper(cell)
      }

    case let collectionView as UICollectionView:
      collectionView.visibleCells.flatMap { cell in
        mapper(cell)
      }

    default:
      []
    }
  }
}
