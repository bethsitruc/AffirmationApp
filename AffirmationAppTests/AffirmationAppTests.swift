//
//  AffirmationAppTests.swift
//  AffirmationAppTests
//
//  Created by Bethany Curtis on 4/4/25.
//

import XCTest
import Testing
@testable import AffirmationApp

struct AffirmationAppTests {

    // Test to verify that adding a user affirmation increases the total count by one
    @Test func testAddUserAffirmation() async throws {
        let store = AffirmationStore()
        let originalCount = store.affirmations.count

        // Add a new user affirmation with specific text and themes, marking it as user created
        store.addUserAffirmation(text: "You are amazing!", themes: ["Motivation"], isUserCreated: true)
        
        // Expect the count of all affirmations to have increased by one
        XCTAssertTrue(store.affirmations.count == originalCount + 1)
    }

    // Test to verify that toggling favorite status adds the affirmation to favorites
    @Test func testFavoriteAffirmation() async throws {
        let store = AffirmationStore()
        // Ensure there is at least one affirmation to test with
        guard let firstAffirmation = store.affirmations.first else {
            // Fail the test if no affirmations are found
            XCTFail("No affirmations found in store.")
            return
        }
        
        // Toggle the favorite status of the first affirmation
        store.toggleFavorite(for: firstAffirmation)
        
        // Expect the favorite affirmations to include the toggled affirmation
        XCTAssertTrue(store.favoriteAffirmations().contains(where: { $0.id == firstAffirmation.id }))
    }

    // Test to verify that deleting a user affirmation removes it from the store
    @Test func testDeleteUserAffirmation() async throws {
        let store = AffirmationStore()
        // Add a temporary affirmation to be deleted
        store.addUserAffirmation(text: "Temporary Affirmation", themes: ["Test"], isUserCreated: true)
        guard let addedAffirmation = store.affirmations.last else {
            // Fail the test if adding the affirmation failed
            XCTFail("Failed to add new affirmation.")
            return
        }
        
        // Delete the added affirmation
        store.deleteUserAffirmation(addedAffirmation)
        
        // Expect the affirmation to no longer be present in the store
        XCTAssertFalse(store.affirmations.contains(where: { $0.id == addedAffirmation.id }))
    }
}
