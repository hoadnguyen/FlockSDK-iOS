//
//  IdentifyResponse.swift
//  FlockSDK
//
//  Created by Hoa Nguyen on 2024-10-02.
//
public struct IdentifyResponse: Codable, Sendable {
    let id: String
    let externalUserId: String
    let email: String
    let name: String?
    let referralCode: String
    let visitedReferralsCount: Int
    let convertedReferralsCount: Int
    let campaignId: String
    let referredById: String?
}
