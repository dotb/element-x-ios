//
// Copyright 2024 New Vector Ltd
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

import AVFoundation
import CallKit
import Combine
import Foundation
import PushKit

class ElementCallService: NSObject, ElementCallServiceProtocol, PKPushRegistryDelegate, CXProviderDelegate {
    private let pushRegistry: PKPushRegistry
    
    private let callController = CXCallController()

    private var callProvider: CXProvider?
    private var ongoingCallID: UUID?
    
    private var incomingCallRoomID: String?
    
    private let actionsSubject: PassthroughSubject<ElementCallServiceAction, Never> = .init()
    var actions: AnyPublisher<ElementCallServiceAction, Never> {
        actionsSubject.eraseToAnyPublisher()
    }
    
    override init() {
        pushRegistry = PKPushRegistry(queue: nil)
        
        super.init()
        
        pushRegistry.delegate = self
        pushRegistry.desiredPushTypes = [.voIP]
    }
    
    func setupCallSession(title: String) async {
        guard ongoingCallID == nil else {
            return
        }
        
        let callID = UUID()
        ongoingCallID = callID
        
        let handle = CXHandle(type: .generic, value: title)
        let startCallAction = CXStartCallAction(call: callID, handle: handle)
        startCallAction.isVideo = true
        
        let transaction = CXTransaction(action: startCallAction)
        
        do {
            try await callController.request(transaction)
            try AVAudioSession.sharedInstance().setCategory(.playAndRecord, mode: .videoChat, options: [])
            try AVAudioSession.sharedInstance().setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            MXLog.error("Failed setting up VoIP session with error: \(error)")
            tearDownCallSession()
        }
    }
    
    func tearDownCallSession() {
        guard let ongoingCallID else {
            return
        }
        
        try? AVAudioSession.sharedInstance().setActive(false)
            
        let endCallAction = CXEndCallAction(call: ongoingCallID)
        let transaction = CXTransaction(action: endCallAction)
        
        callController.request(transaction) { error in
            if let error {
                MXLog.error("Failed transaction with error: \(error)")
            }
        }
    }

    // MARK: - PKPushRegistryDelegate
    
    func pushRegistry(_ registry: PKPushRegistry, didUpdate pushCredentials: PKPushCredentials, for type: PKPushType) { }
    
    func pushRegistry(_ registry: PKPushRegistry, didReceiveIncomingPushWith payload: PKPushPayload, for type: PKPushType, completion: @escaping () -> Void) {
        guard let roomID = payload.dictionaryPayload[ElementCallServiceNotificationKey.roomID.rawValue] as? String else {
            MXLog.error("Somethnig went wrong, missing room identifier for incoming voip call: \(payload)")
            return
        }
        
        let callID = UUID()
        ongoingCallID = callID
        
        incomingCallRoomID = roomID
        
        let configuration = CXProviderConfiguration()
        configuration.supportsVideo = true
        configuration.includesCallsInRecents = false
        
        let update = CXCallUpdate()
        update.hasVideo = true
        
        update.localizedCallerName = payload.dictionaryPayload[ElementCallServiceNotificationKey.roomDisplayName.rawValue] as? String
        
        if let senderDisplayName = payload.dictionaryPayload[ElementCallServiceNotificationKey.senderDisplayName.rawValue] as? String {
            update.remoteHandle = .init(type: .generic, value: senderDisplayName)
        } else if let senderID = payload.dictionaryPayload[ElementCallServiceNotificationKey.senderID.rawValue] as? String {
            update.remoteHandle = .init(type: .generic, value: senderID)
        } else {
            MXLog.error("Something went wrong, both the user display name and ID are nil")
        }
        
        let callProvider = CXProvider(configuration: configuration)
        callProvider.setDelegate(self, queue: nil)
        callProvider.reportNewIncomingCall(with: callID, update: update) { error in
            if let error {
                MXLog.error("Failed reporting new incoming call with error: \(error)")
            }
            
            completion()
        }
    }
    
    // MARK: - CXProviderDelegate
    
    func providerDidReset(_ provider: CXProvider) {
        MXLog.info("Call provider did reset: \(provider)")
    }
    
    func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
        if let incomingCallRoomID {
            actionsSubject.send(.answerCall(roomID: incomingCallRoomID))
            self.incomingCallRoomID = nil
        } else {
            MXLog.error("Failed answering incoming call, missing room ID")
        }
        
        action.fulfill()
    }
    
    func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
        if let incomingCallRoomID {
            actionsSubject.send(.declineCall(roomID: incomingCallRoomID))
            self.incomingCallRoomID = nil
        } else {
            MXLog.error("Failed declining incoming call, missing room ID")
        }

        action.fulfill()
    }
}
