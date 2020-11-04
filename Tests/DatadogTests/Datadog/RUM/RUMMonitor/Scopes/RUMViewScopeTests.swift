/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2019-2020 Datadog, Inc.
 */

import XCTest
import UIKit
@testable import Datadog

class RUMViewScopeTests: XCTestCase {
    private let output = RUMEventOutputMock()
    private let parent = RUMContextProviderMock()
    private lazy var dependencies: RUMScopeDependencies = .mockWith(eventOutput: output)

    func testDefaultContext() {
        let applicationScope: RUMApplicationScope = .mockWith(rumApplicationID: "rum-123")
        let sessionScope: RUMSessionScope = .mockWith(parent: applicationScope)
        let scope = RUMViewScope(
            parent: sessionScope,
            dependencies: .mockAny(),
            identity: mockView,
            uri: "UIViewController",
            attributes: [:],
            startTime: .mockAny()
        )

        XCTAssertEqual(scope.context.rumApplicationID, "rum-123")
        XCTAssertEqual(scope.context.sessionID, sessionScope.context.sessionID)
        XCTAssertEqual(scope.context.activeViewID, scope.viewUUID)
        XCTAssertEqual(scope.context.activeViewURI, scope.viewURI)
        XCTAssertNil(scope.context.activeUserActionID)
    }

    func testContextWhenViewHasAnActiveUserAction() {
        let applicationScope: RUMApplicationScope = .mockWith(rumApplicationID: "rum-123")
        let sessionScope: RUMSessionScope = .mockWith(parent: applicationScope)
        let scope = RUMViewScope(
            parent: sessionScope,
            dependencies: .mockAny(),
            identity: mockView,
            uri: "UIViewController",
            attributes: [:],
            startTime: .mockAny()
        )

        _ = scope.process(command: RUMStartUserActionCommand.mockAny())

        XCTAssertEqual(scope.context.rumApplicationID, "rum-123")
        XCTAssertEqual(scope.context.sessionID, sessionScope.context.sessionID)
        XCTAssertEqual(scope.context.activeViewID, scope.viewUUID)
        XCTAssertEqual(scope.context.activeViewURI, scope.viewURI)
        XCTAssertEqual(scope.context.activeUserActionID, try XCTUnwrap(scope.userActionScope?.actionUUID))
    }

    func testWhenInitialViewIsStarted_itSendsApplicationStartAction() throws {
        let currentTime: Date = .mockDecember15th2019At10AMUTC()
        let scope = RUMViewScope(
            parent: parent,
            dependencies: .mockWith(
                launchTimeProvider: LaunchTimeProviderMock(launchTime: 2), // 2 seconds
                eventOutput: output
            ),
            identity: mockView,
            uri: "UIViewController",
            attributes: [:],
            startTime: currentTime
        )

        XCTAssertTrue(
            scope.process(
                command: RUMStartViewCommand.mockWith(time: currentTime, attributes: ["foo": "bar"], identity: mockView, isInitialView: true)
            )
        )

        let event = try XCTUnwrap(output.recordedEvents(ofType: RUMEvent<RUMDataAction>.self).first)
        XCTAssertEqual(event.model.date, Date.mockDecember15th2019At10AMUTC().timeIntervalSince1970.toInt64Milliseconds)
        XCTAssertEqual(event.model.application.id, scope.context.rumApplicationID)
        XCTAssertEqual(event.model.session.id, scope.context.sessionID.toRUMDataFormat)
        XCTAssertEqual(event.model.session.type, .user)
        XCTAssertValidRumUUID(event.model.view.id)
        XCTAssertEqual(event.model.view.url, "UIViewController")
        XCTAssertValidRumUUID(event.model.action.id)
        XCTAssertEqual(event.model.action.type, .applicationStart)
        XCTAssertEqual(event.model.action.loadingTime, 2_000_000_000) // 2e+9 ns
    }

    func testWhenInitialViewIsStarted_itSendsViewUpdateEvent() throws {
        let currentTime: Date = .mockDecember15th2019At10AMUTC()
        let scope = RUMViewScope(
            parent: parent,
            dependencies: dependencies,
            identity: mockView,
            uri: "UIViewController",
            attributes: [:],
            startTime: currentTime
        )

        XCTAssertTrue(
            scope.process(
                command: RUMStartViewCommand.mockWith(time: currentTime, attributes: ["foo": "bar"], identity: mockView, isInitialView: true)
            )
        )

        let event = try XCTUnwrap(output.recordedEvents(ofType: RUMEvent<RUMDataView>.self).first)
        XCTAssertEqual(event.model.date, Date.mockDecember15th2019At10AMUTC().timeIntervalSince1970.toInt64Milliseconds)
        XCTAssertEqual(event.model.application.id, scope.context.rumApplicationID)
        XCTAssertEqual(event.model.session.id, scope.context.sessionID.toRUMDataFormat)
        XCTAssertEqual(event.model.session.type, .user)
        XCTAssertValidRumUUID(event.model.view.id)
        XCTAssertEqual(event.model.view.url, "UIViewController")
        XCTAssertEqual(event.model.view.timeSpent, 0)
        XCTAssertEqual(event.model.view.action.count, 1, "The initial view udate must have come with `applicat_start` action sent.")
        XCTAssertEqual(event.model.view.error.count, 0)
        XCTAssertEqual(event.model.view.resource.count, 0)
        XCTAssertEqual(event.model.dd.documentVersion, 1)
        XCTAssertEqual(event.attributes as? [String: String], ["foo": "bar"])
    }

    func testWhenViewIsStarted_itSendsViewUpdateEvent() throws {
        let currentTime: Date = .mockDecember15th2019At10AMUTC()
        let scope = RUMViewScope(
            parent: parent,
            dependencies: dependencies,
            identity: mockView,
            uri: "UIViewController",
            attributes: ["foo": "bar", "fizz": "buzz"],
            startTime: currentTime
        )

        XCTAssertTrue(
            scope.process(
                command: RUMStartViewCommand.mockWith(time: currentTime, attributes: ["foo": "bar 2"], identity: mockView)
            )
        )

        let event = try XCTUnwrap(output.recordedEvents(ofType: RUMEvent<RUMDataView>.self).first)
        XCTAssertEqual(event.model.date, Date.mockDecember15th2019At10AMUTC().timeIntervalSince1970.toInt64Milliseconds)
        XCTAssertEqual(event.model.application.id, scope.context.rumApplicationID)
        XCTAssertEqual(event.model.session.id, scope.context.sessionID.toRUMDataFormat)
        XCTAssertEqual(event.model.session.type, .user)
        XCTAssertValidRumUUID(event.model.view.id)
        XCTAssertEqual(event.model.view.url, "UIViewController")
        XCTAssertEqual(event.model.view.timeSpent, 0)
        XCTAssertEqual(event.model.view.action.count, 0)
        XCTAssertEqual(event.model.view.error.count, 0)
        XCTAssertEqual(event.model.view.resource.count, 0)
        XCTAssertEqual(event.model.dd.documentVersion, 1)
        XCTAssertEqual(event.attributes as? [String: String], ["foo": "bar 2", "fizz": "buzz"])
    }

    func testWhenViewIsStopped_itSendsViewUpdateEvent_andEndsTheScope() throws {
        var currentTime: Date = .mockDecember15th2019At10AMUTC()
        let scope = RUMViewScope(
            parent: parent,
            dependencies: dependencies,
            identity: mockView,
            uri: "UIViewController",
            attributes: [:],
            startTime: currentTime
        )

        XCTAssertTrue(
            scope.process(command: RUMStartViewCommand.mockWith(time: currentTime, identity: mockView))
        )
        currentTime.addTimeInterval(2)
        XCTAssertFalse(
            scope.process(command: RUMStopViewCommand.mockWith(time: currentTime, identity: mockView)),
            "The scope should end."
        )

        let viewEvents = try output.recordedEvents(ofType: RUMEvent<RUMDataView>.self)
        XCTAssertEqual(viewEvents.count, 2)
        viewEvents.forEach { viewEvent in
            XCTAssertEqual(
                viewEvent.model.date,
                Date.mockDecember15th2019At10AMUTC().timeIntervalSince1970.toInt64Milliseconds,
                "All View events must share the same creation date"
            )
        }

        let event = try XCTUnwrap(viewEvents.dropFirst().first)
        XCTAssertEqual(event.model.date, Date.mockDecember15th2019At10AMUTC().timeIntervalSince1970.toInt64Milliseconds)
        XCTAssertEqual(event.model.application.id, scope.context.rumApplicationID)
        XCTAssertEqual(event.model.session.id, scope.context.sessionID.toRUMDataFormat)
        XCTAssertEqual(event.model.session.type, .user)
        XCTAssertValidRumUUID(event.model.view.id)
        XCTAssertEqual(event.model.view.url, "UIViewController")
        XCTAssertEqual(event.model.view.timeSpent, TimeInterval(2).toInt64Nanoseconds)
        XCTAssertEqual(event.model.view.action.count, 0)
        XCTAssertEqual(event.model.view.error.count, 0)
        XCTAssertEqual(event.model.view.resource.count, 0)
        XCTAssertEqual(event.model.dd.documentVersion, 2)
        XCTAssertTrue(event.attributes.isEmpty)
    }

    func testWhenAnotherViewIsStarted_itEndsTheScope() throws {
        let view1 = createMockView(viewControllerClassName: "FirstViewController")
        let view2 = createMockView(viewControllerClassName: "SecondViewController")
        var currentTime = Date()
        let scope = RUMViewScope(
            parent: parent,
            dependencies: dependencies,
            identity: view1,
            uri: "FirstViewController",
            attributes: [:],
            startTime: currentTime
        )

        XCTAssertTrue(
             scope.process(command: RUMStartViewCommand.mockWith(time: currentTime, identity: view1))
         )

        currentTime.addTimeInterval(1)

        XCTAssertFalse(
            scope.process(command: RUMStartViewCommand.mockWith(time: currentTime, identity: view2)),
            "The scope should end as another View is started."
        )

        let viewEvents = try output.recordedEvents(ofType: RUMEvent<RUMDataView>.self)
        let event = try XCTUnwrap(viewEvents.dropFirst().first)
        XCTAssertEqual(event.model.view.url, "FirstViewController")
        XCTAssertEqual(event.model.view.timeSpent, TimeInterval(1).toInt64Nanoseconds, "The View should last for 1 second")
    }

    func testWhenTheViewIsStartedAnotherTime_itEndsTheScope() throws {
        var currentTime = Date()
        let scope = RUMViewScope(
            parent: parent,
            dependencies: dependencies,
            identity: mockView,
            uri: "FirstViewController",
            attributes: [:],
            startTime: currentTime
        )

        currentTime.addTimeInterval(1)

        XCTAssertTrue(
            scope.process(command: RUMStartViewCommand.mockWith(time: currentTime, identity: mockView)),
            "The scope should be kept as the View was started for the first time."
        )
        XCTAssertFalse(
            scope.process(command: RUMStartViewCommand.mockWith(time: currentTime, identity: mockView)),
            "The scope should end as the View was started for another time."
        )

        let viewEvents = try output.recordedEvents(ofType: RUMEvent<RUMDataView>.self)
        let event = try XCTUnwrap(viewEvents.first)
        XCTAssertEqual(event.model.view.url, "FirstViewController")
        XCTAssertEqual(event.model.view.timeSpent, TimeInterval(1).toInt64Nanoseconds, "The View should last for 1 second")
    }

    func testGivenMultipleViewScopes_whenSendingViewEvent_eachScopeUsesUniqueViewID() throws {
        func createScope(uri: String) -> RUMViewScope {
            RUMViewScope(
                parent: parent,
                dependencies: dependencies,
                identity: mockView,
                uri: uri,
                attributes: [:],
                startTime: .mockAny()
            )
        }

        // Given
        let scope1 = createScope(uri: "View1")
        let scope2 = createScope(uri: "View2")

        // When
        [scope1, scope2].forEach { scope in
            _ = scope.process(command: RUMStartViewCommand.mockWith(identity: mockView))
            _ = scope.process(command: RUMStopViewCommand.mockWith(identity: mockView))
        }

        // Then
        let viewEvents = try output.recordedEvents(ofType: RUMEvent<RUMDataView>.self)
        let view1Events = viewEvents.filter { $0.model.view.url == "View1" }
        let view2Events = viewEvents.filter { $0.model.view.url == "View2" }
        XCTAssertEqual(view1Events.count, 2)
        XCTAssertEqual(view2Events.count, 2)
        XCTAssertEqual(view1Events[0].model.view.id, view1Events[1].model.view.id)
        XCTAssertEqual(view2Events[0].model.view.id, view2Events[1].model.view.id)
        XCTAssertNotEqual(view1Events[0].model.view.id, view2Events[0].model.view.id)
    }

    // MARK: - Resources Tracking

    func testItManagesResourceScopesLifecycle() throws {
        let scope = RUMViewScope(
            parent: parent,
            dependencies: dependencies,
            identity: mockView,
            uri: "UIViewController",
            attributes: [:],
            startTime: Date()
        )
        XCTAssertTrue(
            scope.process(command: RUMStartViewCommand.mockWith(identity: mockView))
        )

        XCTAssertEqual(scope.resourceScopes.count, 0)
        XCTAssertTrue(
            scope.process(
                command: RUMStartResourceCommand.mockWith(resourceKey: "/resource/1")
            )
        )
        XCTAssertEqual(scope.resourceScopes.count, 1)
        XCTAssertTrue(
            scope.process(
                command: RUMStartResourceCommand.mockWith(resourceKey: "/resource/2")
            )
        )
        XCTAssertEqual(scope.resourceScopes.count, 2)
        XCTAssertTrue(
            scope.process(
                command: RUMStopResourceCommand.mockWith(resourceKey: "/resource/1")
            )
        )
        XCTAssertEqual(scope.resourceScopes.count, 1)
        XCTAssertTrue(
            scope.process(
                command: RUMStopResourceWithErrorCommand.mockWithErrorMessage(resourceKey: "/resource/2")
            )
        )
        XCTAssertEqual(scope.resourceScopes.count, 0)

        XCTAssertFalse(
            scope.process(command: RUMStopViewCommand.mockWith(identity: mockView))
        )
        let event = try XCTUnwrap(output.recordedEvents(ofType: RUMEvent<RUMDataView>.self).last)
        XCTAssertEqual(event.model.view.resource.count, 1, "View should record 1 successfull Resource")
        XCTAssertEqual(event.model.view.error.count, 1, "View should record 1 error due to second Resource failure")
    }

    func testGivenViewWithPendingResources_whenItGetsStopped_itDoesNotFinishUntilResourcesComplete() throws {
        let scope = RUMViewScope(
            parent: parent,
            dependencies: dependencies,
            identity: mockView,
            uri: "UIViewController",
            attributes: [:],
            startTime: Date()
        )

        // given
        XCTAssertTrue(
            scope.process(command: RUMStartViewCommand.mockWith(identity: mockView))
        )
        XCTAssertTrue(
            scope.process(command: RUMStartResourceCommand.mockWith(resourceKey: "/resource/1"))
        )
        XCTAssertTrue(
            scope.process(command: RUMStartResourceCommand.mockWith(resourceKey: "/resource/2"))
        )

        // when
        XCTAssertTrue(
            scope.process(command: RUMStopViewCommand.mockWith(identity: mockView)),
            "The View should be kept alive as its Resources havent yet finished loading"
        )

        // then
        XCTAssertTrue(
            scope.process(command: RUMStopResourceCommand.mockWith(resourceKey: "/resource/1")),
            "The View should be kept alive as all its Resources havent yet finished loading"
        )
        XCTAssertFalse(
            scope.process(command: RUMStopResourceWithErrorCommand.mockWithErrorMessage(resourceKey: "/resource/2")),
            "The View should stop as all its Resources finished loading"
        )

        let event = try XCTUnwrap(output.recordedEvents(ofType: RUMEvent<RUMDataView>.self).last)
        XCTAssertEqual(event.model.view.resource.count, 1, "View should record 1 successfull Resource")
        XCTAssertEqual(event.model.view.error.count, 1, "View should record 1 error due to second Resource failure")
    }

    // MARK: - User Action Tracking

    func testItManagesContinuousUserActionScopeLifecycle() throws {
        let scope = RUMViewScope(
            parent: parent,
            dependencies: dependencies,
            identity: mockView,
            uri: "UIViewController",
            attributes: [:],
            startTime: Date()
        )
        XCTAssertTrue(
            scope.process(command: RUMStartViewCommand.mockWith(identity: mockView))
        )

        XCTAssertNil(scope.userActionScope)
        let actionName = String.mockRandom()
        XCTAssertTrue(
            scope.process(command: RUMStartUserActionCommand.mockWith(actionType: .swipe, name: actionName))
        )
        XCTAssertNotNil(scope.userActionScope)
        XCTAssertEqual(scope.userActionScope?.name, actionName)

        XCTAssertTrue(
            scope.process(command: RUMStartUserActionCommand.mockWith(actionType: .swipe, name: .mockRandom()))
        )
        XCTAssertEqual(scope.userActionScope?.name, actionName, "View should ignore the next UA if one is pending.")

        XCTAssertTrue(
            scope.process(command: RUMStopUserActionCommand.mockWith(actionType: .swipe))
        )
        XCTAssertNil(scope.userActionScope)

        XCTAssertFalse(
            scope.process(command: RUMStopViewCommand.mockWith(identity: mockView))
        )
        let viewEvent = try XCTUnwrap(output.recordedEvents(ofType: RUMEvent<RUMDataView>.self).last)
        XCTAssertEqual(viewEvent.model.view.action.count, 1, "View should record 1 action")
    }

    func testItManagesDiscreteUserActionScopeLifecycle() throws {
        var currentTime = Date()
        let scope = RUMViewScope(
            parent: parent,
            dependencies: dependencies,
            identity: mockView,
            uri: "UIViewController",
            attributes: [:],
            startTime: currentTime
        )
        XCTAssertTrue(
            scope.process(command: RUMStartViewCommand.mockWith(time: currentTime, identity: mockView))
        )

        currentTime.addTimeInterval(0.5)

        XCTAssertNil(scope.userActionScope)
        let actionName = String.mockRandom()
        XCTAssertTrue(
            scope.process(command: RUMAddUserActionCommand.mockWith(time: currentTime, actionType: .tap, name: actionName))
        )
        XCTAssertNotNil(scope.userActionScope)
        XCTAssertEqual(scope.userActionScope?.name, actionName)

        XCTAssertTrue(
            scope.process(command: RUMAddUserActionCommand.mockWith(time: currentTime, actionType: .tap, name: .mockRandom()))
        )
        XCTAssertEqual(scope.userActionScope?.name, actionName, "View should ignore the next UA if one is pending.")

        currentTime.addTimeInterval(RUMUserActionScope.Constants.discreteActionTimeoutDuration)

        XCTAssertFalse(
            scope.process(command: RUMStopViewCommand.mockWith(time: currentTime, identity: mockView))
        )
        let event = try XCTUnwrap(output.recordedEvents(ofType: RUMEvent<RUMDataView>.self).last)
        XCTAssertEqual(event.model.view.action.count, 1, "View should record 1 action")
    }

    // MARK: - Error Tracking

    func testWhenViewErrorIsAdded_itSendsErrorEventAndViewUpdateEvent() throws {
        var currentTime: Date = .mockDecember15th2019At10AMUTC()
        let scope = RUMViewScope(
            parent: parent,
            dependencies: dependencies,
            identity: mockView,
            uri: "UIViewController",
            attributes: [:],
            startTime: currentTime
        )

        XCTAssertTrue(
            scope.process(
                command: RUMStartViewCommand.mockWith(time: currentTime, attributes: ["foo": "bar"], identity: mockView, isInitialView: true)
            )
        )

        currentTime.addTimeInterval(1)

        XCTAssertTrue(
            scope.process(
                command: RUMAddCurrentViewErrorCommand.mockWithErrorMessage(time: currentTime, message: "view error", source: .source, stack: nil)
            )
        )

        let error = try XCTUnwrap(output.recordedEvents(ofType: RUMEvent<RUMDataError>.self).last)
        XCTAssertEqual(error.model.date, Date.mockDecember15th2019At10AMUTC(addingTimeInterval: 1).timeIntervalSince1970.toInt64Milliseconds)
        XCTAssertEqual(error.model.application.id, scope.context.rumApplicationID)
        XCTAssertEqual(error.model.session.id, scope.context.sessionID.toRUMDataFormat)
        XCTAssertEqual(error.model.session.type, .user)
        XCTAssertValidRumUUID(error.model.view.id)
        XCTAssertEqual(error.model.view.url, "UIViewController")
        XCTAssertNil(error.model.usr)
        XCTAssertNil(error.model.connectivity)
        XCTAssertEqual(error.model.error.message, "view error")
        XCTAssertEqual(error.model.error.source, .source)
        XCTAssertNil(error.model.error.stack)
        XCTAssertNil(error.model.error.isCrash)
        XCTAssertNil(error.model.error.resource)
        XCTAssertNil(error.model.action)
        XCTAssertEqual(error.attributes as? [String: String], ["foo": "bar"])

        let viewUpdate = try XCTUnwrap(output.recordedEvents(ofType: RUMEvent<RUMDataView>.self).last)
        XCTAssertEqual(viewUpdate.model.view.error.count, 1)
    }

    func testWhenResourceIsFinishedWithError_itSendsViewUpdateEvent() throws {
        let scope = RUMViewScope(
            parent: parent,
            dependencies: dependencies,
            identity: mockView,
            uri: "UIViewController",
            attributes: [:],
            startTime: Date()
        )

        XCTAssertTrue(
            scope.process(
                command: RUMStartViewCommand.mockWith(attributes: ["foo": "bar"], identity: mockView, isInitialView: true)
            )
        )

        XCTAssertTrue(
            scope.process(
                command: RUMStartResourceCommand.mockWith(resourceKey: "/resource/1")
            )
        )

        XCTAssertTrue(
            scope.process(
                command: RUMStopResourceWithErrorCommand.mockWithErrorObject(resourceKey: "/resource/1")
            )
        )

        let viewUpdate = try XCTUnwrap(output.recordedEvents(ofType: RUMEvent<RUMDataView>.self).last)
        XCTAssertEqual(viewUpdate.model.view.resource.count, 0, "Failed Resource should not be counted")
        XCTAssertEqual(viewUpdate.model.view.error.count, 1, "Failed Resource should be counted as Error")
    }
}
