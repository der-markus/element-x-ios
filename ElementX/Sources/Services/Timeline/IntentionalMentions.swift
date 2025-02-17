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

import MatrixRustSDK
import WysiwygComposer

struct IntentionalMentions: Equatable {
    let userIDs: Set<String>
    let atRoom: Bool
    
    static var empty: Self {
        IntentionalMentions(userIDs: [], atRoom: false)
    }
}

extension IntentionalMentions {
    func toRustMentions() -> Mentions {
        Mentions(userIds: Array(userIDs), room: atRoom)
    }
}

extension MentionsState {
    func toIntentionalMentions() -> IntentionalMentions {
        IntentionalMentions(userIDs: Set(userIds), atRoom: hasAtRoomMention)
    }
}
