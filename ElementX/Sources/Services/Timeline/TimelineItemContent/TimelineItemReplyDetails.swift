//
// Copyright 2023 New Vector Ltd
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

import Foundation

enum TimelineItemReplyDetails: Hashable {
    case notLoaded(eventID: String)
    case loading(eventID: String)
    case loaded(sender: TimelineItemSender, eventID: String, eventContent: TimelineEventContent)
    case error(eventID: String, message: String)
    
    var eventID: String {
        switch self {
        case .notLoaded(let eventID), .loading(let eventID), .loaded(_, let eventID, _), .error(let eventID, _):
            return eventID
        }
    }
}

enum TimelineEventContent: Hashable {
    case message(EventBasedMessageTimelineItemContentType)
    case poll(question: String)
    case redacted
}
