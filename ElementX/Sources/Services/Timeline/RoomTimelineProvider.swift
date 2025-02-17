//
// Copyright 2022 New Vector Ltd
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

import Combine
import Foundation
import MatrixRustSDK

class RoomTimelineProvider: RoomTimelineProviderProtocol {
    private var cancellables = Set<AnyCancellable>()
    private let serialDispatchQueue: DispatchQueue

    private let backPaginationStateSubject = CurrentValueSubject<BackPaginationStatus, Never>(.idle)
    var backPaginationState: BackPaginationStatus {
        backPaginationStateSubject.value
    }

    private let itemProxiesSubject: CurrentValueSubject<[TimelineItemProxy], Never>
    var itemProxies: [TimelineItemProxy] {
        itemProxiesSubject.value
    }

    var updatePublisher: AnyPublisher<TimelineProviderUpdate, Never> {
        itemProxiesSubject
            .combineLatest(backPaginationStateSubject)
            .map(TimelineProviderUpdate.init)
            .eraseToAnyPublisher()
    }

    init(currentItems: [TimelineItem],
         updatePublisher: AnyPublisher<[TimelineDiff], Never>,
         backPaginationStatePublisher: AnyPublisher<BackPaginationStatus, Never>) {
        serialDispatchQueue = DispatchQueue(label: "io.element.elementx.roomtimelineprovider", qos: .utility)
        itemProxiesSubject = CurrentValueSubject<[TimelineItemProxy], Never>(currentItems.map(TimelineItemProxy.init))
        
        // Manually call it here as the didSet doesn't work from constructors
        itemProxiesSubject.send(itemProxies)

        updatePublisher
            .receive(on: serialDispatchQueue)
            .sink { [weak self] in self?.updateItemsWithDiffs($0) }
            .store(in: &cancellables)

        backPaginationStatePublisher
            .sink { [weak self] in self?.backPaginationStateSubject.send($0) }
            .store(in: &cancellables)
    }
    
    // MARK: - Private
    
    private func updateItemsWithDiffs(_ diffs: [TimelineDiff]) {
        let span = MXLog.createSpan("process_timeline_list_diffs")
        span.enter()
        defer {
            span.exit()
        }
        
        MXLog.verbose("Received timeline diff")
        
        let items = diffs
            .reduce(itemProxies) { currentItems, diff in
                guard let collectionDiff = buildDiff(from: diff, on: currentItems) else {
                    MXLog.error("Failed building CollectionDifference from \(diff)")
                    return currentItems
                }
                
                guard let updatedItems = currentItems.applying(collectionDiff) else {
                    MXLog.error("Failed applying diff: \(collectionDiff)")
                    return currentItems
                }
                
                return updatedItems
            }

        itemProxiesSubject.send(items)
        
        MXLog.verbose("Finished applying diffs, current items (\(itemProxies.count)) : \(itemProxies.map(\.debugIdentifier))")
    }
    
    // swiftlint:disable:next cyclomatic_complexity
    private func buildDiff(from diff: TimelineDiff, on itemProxies: [TimelineItemProxy]) -> CollectionDifference<TimelineItemProxy>? {
        var changes = [CollectionDifference<TimelineItemProxy>.Change]()
        
        switch diff.change() {
        case .append:
            guard let items = diff.append() else { fatalError() }

            MXLog.verbose("Append \(items.map(\.debugIdentifier))")
            for (index, item) in items.enumerated() {
                changes.append(.insert(offset: Int(itemProxies.count) + index, element: TimelineItemProxy(item: item), associatedWith: nil))
            }
        case .clear:
            MXLog.verbose("Clear all items")
            for (index, itemProxy) in itemProxies.enumerated() {
                changes.append(.remove(offset: index, element: itemProxy, associatedWith: nil))
            }
        case .insert:
            guard let update = diff.insert() else { fatalError() }

            MXLog.verbose("Insert \(update.item.debugIdentifier) at \(update.index)")
            let itemProxy = TimelineItemProxy(item: update.item)
            changes.append(.insert(offset: Int(update.index), element: itemProxy, associatedWith: nil))
        case .popBack:
            guard let itemProxy = itemProxies.last else { fatalError() }

            MXLog.verbose("Pop Back \(itemProxy.debugIdentifier)")

            changes.append(.remove(offset: itemProxies.count - 1, element: itemProxy, associatedWith: nil))
        case .popFront:
            guard let itemProxy = itemProxies.first else { fatalError() }

            MXLog.verbose("Pop Front \(itemProxy.debugIdentifier)")

            changes.append(.remove(offset: 0, element: itemProxy, associatedWith: nil))
        case .pushBack:
            guard let item = diff.pushBack() else { fatalError() }

            MXLog.verbose("Push Back \(item.debugIdentifier)")
            let itemProxy = TimelineItemProxy(item: item)
            changes.append(.insert(offset: Int(itemProxies.count), element: itemProxy, associatedWith: nil))
        case .pushFront:
            guard let item = diff.pushFront() else { fatalError() }

            MXLog.verbose("Push Front: \(item.debugIdentifier)")
            let itemProxy = TimelineItemProxy(item: item)
            changes.append(.insert(offset: 0, element: itemProxy, associatedWith: nil))
        case .remove:
            guard let index = diff.remove() else { fatalError() }

            let itemProxy = itemProxies[Int(index)]

            MXLog.verbose("Remove \(itemProxy.debugIdentifier) at: \(index)")

            changes.append(.remove(offset: Int(index), element: itemProxy, associatedWith: nil))
        case .reset:
            guard let items = diff.reset() else { fatalError() }

            MXLog.verbose("Replace all items with \(items.map(\.debugIdentifier))")
            for (index, itemProxy) in itemProxies.enumerated() {
                changes.append(.remove(offset: index, element: itemProxy, associatedWith: nil))
            }

            for (index, timelineItem) in items.enumerated() {
                changes.append(.insert(offset: index, element: TimelineItemProxy(item: timelineItem), associatedWith: nil))
            }
        case .set:
            guard let update = diff.set() else { fatalError() }

            MXLog.verbose("Set \(update.item.debugIdentifier) at index \(update.index)")
            let itemProxy = TimelineItemProxy(item: update.item)
            changes.append(.remove(offset: Int(update.index), element: itemProxy, associatedWith: nil))
            changes.append(.insert(offset: Int(update.index), element: itemProxy, associatedWith: nil))
        case .truncate:
            break
        }
        
        return CollectionDifference(changes)
    }
}

private extension TimelineItem {
    var debugIdentifier: DebugIdentifier {
        if let virtualTimelineItem = asVirtual() {
            return .virtual(timelineID: String(uniqueId()), dscription: virtualTimelineItem.description)
        } else if let eventTimelineItem = asEvent() {
            return .event(timelineID: String(uniqueId()),
                          eventID: eventTimelineItem.eventId(),
                          transactionID: eventTimelineItem.transactionId())
        }
        
        return .unknown(timelineID: String(uniqueId()))
    }
}

private extension TimelineItemProxy {
    var debugIdentifier: DebugIdentifier {
        switch self {
        case .event(let eventTimelineItem):
            return .event(timelineID: eventTimelineItem.id.timelineID,
                          eventID: eventTimelineItem.id.eventID,
                          transactionID: eventTimelineItem.id.transactionID)
        case .virtual(let virtualTimelineItem, let timelineID):
            return .virtual(timelineID: timelineID, dscription: virtualTimelineItem.description)
        case .unknown(let item):
            return .unknown(timelineID: String(item.uniqueId()))
        }
    }
}

private extension VirtualTimelineItem {
    var description: String {
        switch self {
        case .dayDivider(let timestamp):
            return "DayDiviver(\(timestamp))"
        case .readMarker:
            return "ReadMarker"
        }
    }
}

enum DebugIdentifier {
    case event(timelineID: String, eventID: String?, transactionID: String?)
    case virtual(timelineID: String, dscription: String)
    case unknown(timelineID: String)
}
