import Foundation
import UIKit
import Display
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import ItemListUI
import PresentationDataUtils
import AccountContext
import GiftViewScreen

// The Vanity mod's screen: what your own profile shows on this device only.
// Everything changed here is marked MOD wherever it appears.

private final class VanitySettingsArguments {
    let context: AccountContext
    let toggleEnabled: (Bool) -> Void
    let updatePhone: (String) -> Void
    let updateUsernames: (String) -> Void
    let updateLevel: (String) -> Void
    let updateStars: (String) -> Void
    let updateSlug: (String) -> Void
    let addBySlug: () -> Void
    let openBuilder: () -> Void
    let openGift: (String) -> Void
    let updateChannelSubscribers: (Int64, String) -> Void
    let updateChannelViews: (Int64, String) -> Void
    let removeChannel: (Int64) -> Void
    let addChannel: () -> Void

    init(context: AccountContext, toggleEnabled: @escaping (Bool) -> Void, updatePhone: @escaping (String) -> Void, updateUsernames: @escaping (String) -> Void, updateLevel: @escaping (String) -> Void, updateStars: @escaping (String) -> Void, updateSlug: @escaping (String) -> Void, addBySlug: @escaping () -> Void, openBuilder: @escaping () -> Void, openGift: @escaping (String) -> Void, updateChannelSubscribers: @escaping (Int64, String) -> Void, updateChannelViews: @escaping (Int64, String) -> Void, removeChannel: @escaping (Int64) -> Void, addChannel: @escaping () -> Void) {
        self.context = context
        self.toggleEnabled = toggleEnabled
        self.updatePhone = updatePhone
        self.updateUsernames = updateUsernames
        self.updateLevel = updateLevel
        self.updateStars = updateStars
        self.updateSlug = updateSlug
        self.addBySlug = addBySlug
        self.openBuilder = openBuilder
        self.openGift = openGift
        self.updateChannelSubscribers = updateChannelSubscribers
        self.updateChannelViews = updateChannelViews
        self.removeChannel = removeChannel
        self.addChannel = addChannel
    }
}

private enum VanitySettingsSection: Int32 {
    case main
    case profile
    case gifts
    case channels
}

private enum VanitySettingsEntry: ItemListNodeEntry, Equatable {
    case enabled(Bool)
    case enabledInfo
    case profileHeader
    case phone(String)
    case usernames(String)
    case level(String)
    case stars(String)
    case profileInfo
    case giftsHeader
    case slug(String)
    case addBySlug(Bool)
    case builder
    case gift(Int32, String, String, String)
    case giftsInfo
    case channelsHeader
    case channelTitle(Int32, Int64, String)
    case channelSubscribers(Int32, Int64, String)
    case channelViews(Int32, Int64, String)
    case channelRemove(Int32, Int64)
    case addChannel
    case channelsInfo

    var section: ItemListSectionId {
        switch self {
        case .enabled, .enabledInfo:
            return VanitySettingsSection.main.rawValue
        case .profileHeader, .phone, .usernames, .level, .stars, .profileInfo:
            return VanitySettingsSection.profile.rawValue
        case .giftsHeader, .slug, .addBySlug, .builder, .gift, .giftsInfo:
            return VanitySettingsSection.gifts.rawValue
        case .channelsHeader, .channelTitle, .channelSubscribers, .channelViews, .channelRemove, .addChannel, .channelsInfo:
            return VanitySettingsSection.channels.rawValue
        }
    }

    var stableId: Int32 {
        switch self {
        case .enabled:
            return 0
        case .enabledInfo:
            return 1
        case .profileHeader:
            return 10
        case .phone:
            return 11
        case .usernames:
            return 12
        case .level:
            return 13
        case .stars:
            return 14
        case .profileInfo:
            return 15
        case .giftsHeader:
            return 100
        case .slug:
            return 101
        case .addBySlug:
            return 102
        case .builder:
            return 103
        case let .gift(index, _, _, _):
            return 110 + index
        case .giftsInfo:
            return 999
        case .channelsHeader:
            return 1000
        case let .channelTitle(index, _, _):
            return 1010 + index * 4
        case let .channelSubscribers(index, _, _):
            return 1011 + index * 4
        case let .channelViews(index, _, _):
            return 1012 + index * 4
        case let .channelRemove(index, _):
            return 1013 + index * 4
        case .addChannel:
            return 9998
        case .channelsInfo:
            return 9999
        }
    }

    static func <(lhs: VanitySettingsEntry, rhs: VanitySettingsEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! VanitySettingsArguments
        switch self {
        case let .enabled(value):
            return ItemListSwitchItem(presentationData: presentationData, title: "Включить мод", value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.toggleEnabled(value)
            })
        case .enabledInfo:
            return ItemListTextItem(presentationData: presentationData, text: .plain("Всё, что задано здесь, видно только на этом телефоне и не отправляется в Telegram. Подменённое всегда помечено значком \(VanityMod.mark)."), sectionId: self.section)
        case .profileHeader:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: "ПРОФИЛЬ", sectionId: self.section)
        case let .phone(text):
            return ItemListSingleLineInputItem(presentationData: presentationData, title: NSAttributedString(string: "Номер"), text: text, placeholder: "+888 0000 0000", type: .regular(capitalization: false, autocorrection: false), sectionId: self.section, textUpdated: { value in
                arguments.updatePhone(value)
            }, action: {})
        case let .usernames(text):
            return ItemListSingleLineInputItem(presentationData: presentationData, title: NSAttributedString(string: "Юзернеймы"), text: text, placeholder: "name1, name2", type: .regular(capitalization: false, autocorrection: false), sectionId: self.section, textUpdated: { value in
                arguments.updateUsernames(value)
            }, action: {})
        case let .level(text):
            return ItemListSingleLineInputItem(presentationData: presentationData, title: NSAttributedString(string: "Уровень"), text: text, placeholder: "0 — настоящий", type: .number, sectionId: self.section, textUpdated: { value in
                arguments.updateLevel(value)
            }, action: {})
        case let .stars(text):
            return ItemListSingleLineInputItem(presentationData: presentationData, title: NSAttributedString(string: "Звёзды"), text: text, placeholder: "0 — настоящие", type: .number, sectionId: self.section, textUpdated: { value in
                arguments.updateStars(value)
            }, action: {})
        case .profileInfo:
            return ItemListTextItem(presentationData: presentationData, text: .plain("Юзернеймы через запятую: первый — основной. Пустое поле — показывается настоящее значение. Звёзды только показываются: платежи используют настоящий баланс."), sectionId: self.section)
        case .giftsHeader:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: "ПОДАРКИ", sectionId: self.section)
        case let .slug(text):
            return ItemListSingleLineInputItem(presentationData: presentationData, title: NSAttributedString(string: "Ссылка"), text: text, placeholder: "t.me/nft/PlushPepe-1", type: .regular(capitalization: false, autocorrection: false), sectionId: self.section, textUpdated: { value in
                arguments.updateSlug(value)
            }, action: {
                arguments.addBySlug()
            })
        case let .addBySlug(isLoading):
            return ItemListActionItem(presentationData: presentationData, title: isLoading ? "Ищу подарок…" : "Добавить копию по ссылке", kind: isLoading ? .disabled : .generic, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                arguments.addBySlug()
            })
        case .builder:
            return ItemListDisclosureItem(presentationData: presentationData, title: "Создать свой подарок", label: "", sectionId: self.section, style: .blocks, action: {
                arguments.openBuilder()
            })
        case let .gift(_, id, title, subtitle):
            return ItemListDisclosureItem(presentationData: presentationData, title: title, label: subtitle, sectionId: self.section, style: .blocks, action: {
                arguments.openGift(id)
            })
        case .giftsInfo:
            return ItemListTextItem(presentationData: presentationData, text: .plain("Подарки мода стоят первыми в профиле, закреплённые — у аватарки. Нажми на подарок, чтобы посмотреть, закрепить или удалить."), sectionId: self.section)
        case .channelsHeader:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: "МОИ КАНАЛЫ", sectionId: self.section)
        case let .channelTitle(_, _, title):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: title.uppercased(), sectionId: self.section)
        case let .channelSubscribers(_, peerId, text):
            return ItemListSingleLineInputItem(presentationData: presentationData, title: NSAttributedString(string: "Подписчики"), text: text, placeholder: "настоящие", type: .number, sectionId: self.section, textUpdated: { value in
                arguments.updateChannelSubscribers(peerId, value)
            }, action: {})
        case let .channelViews(_, peerId, text):
            return ItemListSingleLineInputItem(presentationData: presentationData, title: NSAttributedString(string: "Просмотры поста"), text: text, placeholder: "настоящие", type: .number, sectionId: self.section, textUpdated: { value in
                arguments.updateChannelViews(peerId, value)
            }, action: {})
        case let .channelRemove(_, peerId):
            return ItemListActionItem(presentationData: presentationData, title: "Убрать канал", kind: .destructive, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                arguments.removeChannel(peerId)
            })
        case .addChannel:
            return ItemListActionItem(presentationData: presentationData, title: "Добавить канал", kind: .generic, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                arguments.addChannel()
            })
        case .channelsInfo:
            return ItemListTextItem(presentationData: presentationData, text: .plain("Только твои публичные каналы. Просмотры у каждого поста свои — ±20% от среднего."), sectionId: self.section)
        }
    }
}

private struct VanitySettingsState: Equatable {
    var slug: String = ""
    var isAddingBySlug: Bool = false
}

private func numberText<T: BinaryInteger>(_ value: T?) -> String {
    guard let value, value > 0 else {
        return ""
    }
    return "\(value)"
}

private func vanitySettingsEntries(settings: VanitySettings, state: VanitySettingsState) -> [VanitySettingsEntry] {
    var entries: [VanitySettingsEntry] = []
    entries.append(.enabled(settings.enabled))
    entries.append(.enabledInfo)

    entries.append(.profileHeader)
    entries.append(.phone(settings.phone))
    entries.append(.usernames(settings.usernames.joined(separator: ", ")))
    entries.append(.level(numberText(settings.level)))
    entries.append(.stars(numberText(settings.stars)))
    entries.append(.profileInfo)

    entries.append(.giftsHeader)
    entries.append(.slug(state.slug))
    entries.append(.addBySlug(state.isAddingBySlug))
    entries.append(.builder)
    for (index, gift) in settings.gifts.enumerated() {
        let names = gift.gift.attributes.compactMap { attribute -> String? in
            switch attribute {
            case let .model(name, _, _, _), let .pattern(name, _, _), let .backdrop(name, _, _, _, _, _, _):
                return name
            default:
                return nil
            }
        }
        let title = "\(gift.pinned ? "📌 " : "")\(gift.gift.title) #\(gift.gift.number)"
        entries.append(.gift(Int32(index), gift.id, title, names.first ?? ""))
    }
    entries.append(.giftsInfo)

    entries.append(.channelsHeader)
    for (index, channel) in settings.channels.enumerated() {
        entries.append(.channelTitle(Int32(index), channel.peerId, channel.title))
        entries.append(.channelSubscribers(Int32(index), channel.peerId, numberText(channel.subscribers)))
        entries.append(.channelViews(Int32(index), channel.peerId, numberText(channel.views)))
        entries.append(.channelRemove(Int32(index), channel.peerId))
    }
    entries.append(.addChannel)
    entries.append(.channelsInfo)

    return entries
}

/// "PlushPepe-123", "t.me/nft/PlushPepe-123" or the whole link
private func vanityGiftSlug(_ text: String) -> String? {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    let last = trimmed.split(separator: "/").last.map(String.init) ?? trimmed
    let parts = last.split(separator: "-")
    guard parts.count >= 2, let number = parts.last, !number.isEmpty, number.allSatisfy({ $0.isASCII && $0.isNumber }) else {
        return nil
    }
    return last
}

private func parseCount(_ text: String) -> Int64 {
    let digits = text.filter { $0.isASCII && $0.isNumber }
    return Int64(digits.prefix(15)) ?? 0
}

public func vanitySettingsController(context: AccountContext) -> ViewController {
    let statePromise = ValuePromise(VanitySettingsState(), ignoreRepeated: true)
    let stateValue = Atomic(value: VanitySettingsState())
    let updateState: ((inout VanitySettingsState) -> Void) -> Void = { f in
        var state = stateValue.with { $0 }
        f(&state)
        let _ = stateValue.swap(state)
        statePromise.set(state)
    }

    let actionsDisposable = DisposableSet()
    var pushControllerImpl: ((ViewController) -> Void)?
    var presentControllerImpl: ((ViewController) -> Void)?

    let showAlert: (String) -> Void = { text in
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        presentControllerImpl?(textAlertController(context: context, title: nil, text: text, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})]))
    }

    let arguments = VanitySettingsArguments(context: context, toggleEnabled: { value in
        VanityMod.shared.update { $0.enabled = value }
    }, updatePhone: { value in
        VanityMod.shared.update { $0.phone = value }
    }, updateUsernames: { value in
        let usernames = value.split(whereSeparator: { $0 == "," || $0 == " " }).map { VanityMod.cleanUsername(String($0)) }.filter { !$0.isEmpty }
        VanityMod.shared.update { $0.usernames = usernames }
    }, updateLevel: { value in
        VanityMod.shared.update { $0.level = Int32(min(parseCount(value), 999)) }
    }, updateStars: { value in
        VanityMod.shared.update { $0.stars = parseCount(value) }
    }, updateSlug: { value in
        updateState { $0.slug = value }
    }, addBySlug: {
        let state = stateValue.with { $0 }
        guard !state.isAddingBySlug else {
            return
        }
        guard let slug = vanityGiftSlug(state.slug) else {
            showAlert("Нужна ссылка вида t.me/nft/PlushPepe-123")
            return
        }
        updateState { $0.isAddingBySlug = true }
        actionsDisposable.add((context.engine.payments.getUniqueStarGift(slug: slug)
        |> deliverOnMainQueue).start(next: { gift in
            VanityMod.shared.addGift(VanityMod.ownedCopy(of: gift, accountPeerId: context.account.peerId, id: Int64.random(in: 1 ..< Int64.max)))
            updateState {
                $0.slug = ""
                $0.isAddingBySlug = false
            }
        }, error: { _ in
            updateState { $0.isAddingBySlug = false }
            showAlert("Такой подарок не найден")
        }))
    }, openBuilder: {
        pushControllerImpl?(vanityGiftBuilderController(context: context))
    }, openGift: { id in
        guard let gift = VanityMod.shared.settings.gifts.first(where: { $0.id == id }) else {
            return
        }
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        let actionSheet = ActionSheetController(presentationData: presentationData)
        actionSheet.setItemGroups([
            ActionSheetItemGroup(items: [
                ActionSheetTextItem(title: "\(gift.gift.title) #\(gift.gift.number) · \(VanityMod.mark)"),
                ActionSheetButtonItem(title: "Посмотреть", color: .accent, action: { [weak actionSheet] in
                    actionSheet?.dismissAnimated()
                    pushControllerImpl?(GiftViewScreen(context: context, subject: .uniqueGift(gift.gift, context.account.peerId)))
                }),
                ActionSheetButtonItem(title: gift.pinned ? "Открепить" : "Закрепить у аватарки", color: .accent, action: { [weak actionSheet] in
                    actionSheet?.dismissAnimated()
                    VanityMod.shared.toggleGiftPinned(id: id)
                }),
                ActionSheetButtonItem(title: "Удалить", color: .destructive, action: { [weak actionSheet] in
                    actionSheet?.dismissAnimated()
                    VanityMod.shared.removeGift(id: id)
                })
            ]),
            ActionSheetItemGroup(items: [
                ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
                    actionSheet?.dismissAnimated()
                })
            ])
        ])
        presentControllerImpl?(actionSheet)
    }, updateChannelSubscribers: { peerId, value in
        let count = parseCount(value)
        VanityMod.shared.update { settings in
            if let index = settings.channels.firstIndex(where: { $0.peerId == peerId }) {
                settings.channels[index].subscribers = count > 0 ? Int32(min(count, Int64(Int32.max))) : nil
            }
        }
    }, updateChannelViews: { peerId, value in
        let count = parseCount(value)
        VanityMod.shared.update { settings in
            if let index = settings.channels.firstIndex(where: { $0.peerId == peerId }) {
                settings.channels[index].views = count > 0 ? Int32(min(count, Int64(Int32.max))) : nil
            }
        }
    }, removeChannel: { peerId in
        VanityMod.shared.update { settings in
            settings.channels.removeAll(where: { $0.peerId == peerId })
        }
    }, addChannel: {
        actionsDisposable.add((context.engine.peers.adminedPublicChannels(scope: .all)
        |> take(1)
        |> deliverOnMainQueue).start(next: { channels in
            let presentationData = context.sharedContext.currentPresentationData.with { $0 }
            let existing = Set(VanityMod.shared.settings.channels.map(\.peerId))
            let candidates = channels.compactMap { channel -> (TelegramChannel, Int?)? in
                if case let .channel(peer) = channel.peer, case .broadcast = peer.info, !existing.contains(peer.id.toInt64()) {
                    return (peer, channel.subscriberCount)
                }
                return nil
            }
            if candidates.isEmpty {
                showAlert("Нет публичных каналов, где ты админ, или они уже добавлены.")
                return
            }
            let actionSheet = ActionSheetController(presentationData: presentationData)
            var items: [ActionSheetItem] = [ActionSheetTextItem(title: "Выбери канал")]
            for (peer, subscriberCount) in candidates {
                let title = peer.title
                let peerId = peer.id.toInt64()
                let subscribers = subscriberCount.flatMap { Int32(exactly: $0) }
                items.append(ActionSheetButtonItem(title: title, color: .accent, action: { [weak actionSheet] in
                    actionSheet?.dismissAnimated()
                    VanityMod.shared.update { settings in
                        settings.channels.append(VanityChannel(peerId: peerId, title: title, subscribers: subscribers, views: nil))
                    }
                }))
            }
            actionSheet.setItemGroups([
                ActionSheetItemGroup(items: items),
                ActionSheetItemGroup(items: [
                    ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
                        actionSheet?.dismissAnimated()
                    })
                ])
            ])
            presentControllerImpl?(actionSheet)
        }))
    })

    let signal = combineLatest(context.sharedContext.presentationData, VanityMod.shared.settingsSignal, statePromise.get())
    |> deliverOnMainQueue
    |> map { presentationData, settings, state -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text("Vanity · \(VanityMod.mark)"), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: vanitySettingsEntries(settings: settings, state: state), style: .blocks, animateChanges: false)
        return (controllerState, (listState, arguments))
    }
    |> afterDisposed {
        actionsDisposable.dispose()
    }

    let controller = ItemListController(context: context, state: signal)
    pushControllerImpl = { [weak controller] c in
        (controller?.navigationController as? NavigationController)?.pushViewController(c)
    }
    presentControllerImpl = { [weak controller] c in
        controller?.present(c, in: .window(.root))
    }
    return controller
}
