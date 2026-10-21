import Foundation
import Postbox
import SwiftSignalKit

// Vanity mod: a local-only look for your own profile — a phone number, usernames, a level,
// a Stars balance, collectible gifts and your channels' numbers. Nothing here is sent to
// Telegram; everything it changes carries a visible MOD mark.

public struct VanityChannel: Codable, Equatable {
    public var peerId: Int64
    public var title: String
    public var subscribers: Int32?
    /// views of an average post: each post gets ±20% of it, steady per post
    public var views: Int32?

    public init(peerId: Int64, title: String, subscribers: Int32?, views: Int32?) {
        self.peerId = peerId
        self.title = title
        self.subscribers = subscribers
        self.views = views
    }
}

public struct VanityGift: Codable, Equatable {
    public var id: String
    public var gift: StarGift.UniqueGift
    public var pinned: Bool
    public var date: Int32

    public init(id: String, gift: StarGift.UniqueGift, pinned: Bool, date: Int32) {
        self.id = id
        self.gift = gift
        self.pinned = pinned
        self.date = date
    }
}

public struct VanitySettings: Codable, Equatable {
    public var enabled: Bool
    public var phone: String
    /// the first one is the main username, the rest show as "also"
    public var usernames: [String]
    /// a Stars rating level, 0 — the real one
    public var level: Int32
    /// a Stars balance to show, 0 — the real one
    public var stars: Int64
    public var channels: [VanityChannel]
    public var gifts: [VanityGift]

    public static let defaultSettings = VanitySettings(enabled: true, phone: "", usernames: [], level: 0, stars: 0, channels: [], gifts: [])

    public init(enabled: Bool, phone: String, usernames: [String], level: Int32, stars: Int64, channels: [VanityChannel], gifts: [VanityGift]) {
        self.enabled = enabled
        self.phone = phone
        self.usernames = usernames
        self.level = level
        self.stars = stars
        self.channels = channels
        self.gifts = gifts
    }

    private enum CodingKeys: String, CodingKey {
        case enabled
        case phone
        case usernames
        case level
        case stars
        case channels
        case gifts
    }

    // * fields added later must not lose what was saved before them
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled) ?? true
        self.phone = try container.decodeIfPresent(String.self, forKey: .phone) ?? ""
        self.usernames = try container.decodeIfPresent([String].self, forKey: .usernames) ?? []
        self.level = try container.decodeIfPresent(Int32.self, forKey: .level) ?? 0
        self.stars = try container.decodeIfPresent(Int64.self, forKey: .stars) ?? 0
        self.channels = try container.decodeIfPresent([VanityChannel].self, forKey: .channels) ?? []
        self.gifts = (try? container.decodeIfPresent([VanityGift].self, forKey: .gifts)) ?? []
    }
}

public final class VanityMod {
    public static let shared = VanityMod()
    public static let mark = "MOD"

    private static let storageKey = "tgmod.vanity.settings"

    private let lock = NSLock()
    private var current: VanitySettings
    private let promise: ValuePromise<VanitySettings>

    private init() {
        var settings = VanitySettings.defaultSettings
        if let data = UserDefaults.standard.data(forKey: VanityMod.storageKey), let decoded = try? JSONDecoder().decode(VanitySettings.self, from: data) {
            settings = decoded
        }
        self.current = settings
        self.promise = ValuePromise(settings, ignoreRepeated: true)
    }

    public var settings: VanitySettings {
        self.lock.lock()
        defer {
            self.lock.unlock()
        }
        return self.current
    }

    public var settingsSignal: Signal<VanitySettings, NoError> {
        return self.promise.get()
    }

    public func update(_ f: (inout VanitySettings) -> Void) {
        self.lock.lock()
        var settings = self.current
        f(&settings)
        self.current = settings
        self.lock.unlock()

        if let data = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(data, forKey: VanityMod.storageKey)
        }
        self.promise.set(settings)
    }

    private func isMine(_ peerId: EnginePeer.Id, accountPeerId: EnginePeer.Id) -> Bool {
        return peerId == accountPeerId && self.settings.enabled
    }

    /// the number to show in place of your own, digits only — or nil
    public func phone(peerId: EnginePeer.Id, accountPeerId: EnginePeer.Id) -> String? {
        guard self.isMine(peerId, accountPeerId: accountPeerId) else {
            return nil
        }
        let digits = self.settings.phone.filter { $0.isASCII && $0.isNumber }
        return digits.isEmpty ? nil : digits
    }

    /// your usernames as the mod shows them, the main one first — or nil
    public func usernames(peerId: EnginePeer.Id, accountPeerId: EnginePeer.Id) -> [String]? {
        guard self.isMine(peerId, accountPeerId: accountPeerId) else {
            return nil
        }
        let usernames = self.settings.usernames.map(VanityMod.cleanUsername).filter { !$0.isEmpty }
        return usernames.isEmpty ? nil : usernames
    }

    public func level(peerId: EnginePeer.Id, accountPeerId: EnginePeer.Id) -> Int32? {
        guard self.isMine(peerId, accountPeerId: accountPeerId) else {
            return nil
        }
        let level = self.settings.level
        return level > 0 ? level : nil
    }

    /// a Stars balance to show in place of yours — display only, never used to pay
    public func stars() -> Int64? {
        let settings = self.settings
        return settings.enabled && settings.stars > 0 ? settings.stars : nil
    }

    public func channel(peerId: EnginePeer.Id) -> VanityChannel? {
        let settings = self.settings
        guard settings.enabled else {
            return nil
        }
        let value = peerId.toInt64()
        return settings.channels.first(where: { $0.peerId == value })
    }

    public func subscribers(peerId: EnginePeer.Id) -> Int32? {
        guard let subscribers = self.channel(peerId: peerId)?.subscribers, subscribers > 0 else {
            return nil
        }
        return subscribers
    }

    /// a post's views: the channel's average moved by up to ±20%, the same way every time
    public func views(peerId: EnginePeer.Id, messageId: Int32) -> Int32? {
        guard let views = self.channel(peerId: peerId)?.views, views > 0 else {
            return nil
        }
        let seed = abs(sin(Double(messageId) * 12.9898) * 43758.5453).truncatingRemainder(dividingBy: 1.0)
        return max(1, Int32((Double(views) * (0.8 + seed * 0.4)).rounded()))
    }

    /// the mod's gifts for a profile, newest first
    public func gifts(peerId: EnginePeer.Id, accountPeerId: EnginePeer.Id) -> [VanityGift] {
        guard self.isMine(peerId, accountPeerId: accountPeerId) else {
            return []
        }
        return self.settings.gifts
    }

    public static func cleanUsername(_ username: String) -> String {
        var value = username.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.hasPrefix("@") {
            value.removeFirst()
        }
        return value.filter { ($0.isASCII && ($0.isLetter || $0.isNumber)) || $0 == "_" }
    }

    /// a slug the mod's gifts carry, so nothing mistakes them for real ones
    public static func isVanitySlug(_ slug: String) -> Bool {
        return slug.hasPrefix(VanityMod.slugPrefix)
    }

    private static let slugPrefix = "MOD-"

    /// a collectible as you would own it: no resale, no value, no original details
    public static func ownedCopy(of gift: StarGift.UniqueGift, accountPeerId: EnginePeer.Id, id: Int64, number: Int32? = nil, total: Int32? = nil, attributes: [StarGift.UniqueGift.Attribute]? = nil) -> StarGift.UniqueGift {
        let number = number ?? gift.number
        let total = total ?? gift.availability.total
        let attributes = (attributes ?? gift.attributes).filter { attribute in
            if case .originalInfo = attribute {
                return false
            }
            return true
        }
        let slugTitle = gift.title.filter { $0.isASCII && ($0.isLetter || $0.isNumber) }
        return StarGift.UniqueGift(
            id: id,
            giftId: gift.giftId,
            title: gift.title,
            number: number,
            slug: "\(VanityMod.slugPrefix)\(slugTitle.isEmpty ? "Gift" : slugTitle)-\(number)",
            owner: .peerId(accountPeerId),
            attributes: attributes,
            availability: StarGift.UniqueGift.Availability(issued: min(number, total), total: total),
            giftAddress: nil,
            resellAmounts: nil,
            resellForTonOnly: false,
            releasedBy: gift.releasedBy,
            valueAmount: nil,
            valueCurrency: nil,
            valueUsdAmount: nil,
            flags: [],
            themePeerId: nil,
            peerColor: nil,
            hostPeerId: nil,
            minOfferStars: nil,
            craftChancePermille: nil
        )
    }

    /// a collectible put together from a base gift and the model, backdrop and pattern picked for it
    public static func customGift(giftId: Int64, title: String, number: Int32, total: Int32, attributes: [StarGift.UniqueGift.Attribute], accountPeerId: EnginePeer.Id, id: Int64) -> StarGift.UniqueGift {
        let base = StarGift.UniqueGift(
            id: id,
            giftId: giftId,
            title: title,
            number: number,
            slug: "",
            owner: nil,
            attributes: attributes,
            availability: StarGift.UniqueGift.Availability(issued: min(number, total), total: total),
            giftAddress: nil,
            resellAmounts: nil,
            resellForTonOnly: false,
            releasedBy: nil,
            valueAmount: nil,
            valueCurrency: nil,
            valueUsdAmount: nil,
            flags: [],
            themePeerId: nil,
            peerColor: nil,
            hostPeerId: nil,
            minOfferStars: nil,
            craftChancePermille: nil
        )
        return VanityMod.ownedCopy(of: base, accountPeerId: accountPeerId, id: id)
    }

    public func addGift(_ gift: StarGift.UniqueGift) {
        let date = Int32(Date().timeIntervalSince1970)
        let id = "\(Int64(Date().timeIntervalSince1970 * 1000))-\(Int32.random(in: 0 ..< 10000))"
        self.update { settings in
            settings.gifts.insert(VanityGift(id: id, gift: gift, pinned: false, date: date), at: 0)
        }
    }

    public func removeGift(id: String) {
        self.update { settings in
            settings.gifts.removeAll(where: { $0.id == id })
        }
    }

    public func toggleGiftPinned(id: String) {
        self.update { settings in
            if let index = settings.gifts.firstIndex(where: { $0.id == id }) {
                settings.gifts[index].pinned = !settings.gifts[index].pinned
            }
        }
    }
}

extension ProfileGiftsContext.State {
    /// your profile's gifts with the Vanity mod's ones in front, where the filter shows collectibles
    func withVanityGifts(_ gifts: [VanityGift]) -> ProfileGiftsContext.State {
        guard !gifts.isEmpty, self.filter.contains(.unique), self.filter.contains(.displayed) else {
            return self
        }
        let vanityGifts = gifts.map { gift in
            ProfileGiftsContext.State.StarGift(
                gift: .unique(gift.gift),
                reference: nil,
                fromPeer: nil,
                date: gift.date,
                text: nil,
                entities: nil,
                nameHidden: false,
                savedToProfile: true,
                pinnedToTop: gift.pinned,
                convertStars: nil,
                canUpgrade: false,
                canExportDate: nil,
                upgradeStars: nil,
                transferStars: nil,
                canTransferDate: nil,
                canResaleDate: nil,
                collectionIds: nil,
                prepaidUpgradeHash: nil,
                upgradeSeparate: false,
                dropOriginalDetailsStars: nil,
                number: nil,
                isRefunded: false,
                canCraftAt: nil
            )
        }
        var state = self
        state.gifts = vanityGifts + state.gifts
        state.filteredGifts = vanityGifts + state.filteredGifts
        if let count = state.count {
            state.count = count + Int32(vanityGifts.count)
        }
        return state
    }
}
