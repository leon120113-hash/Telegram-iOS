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

// The Vanity mod's gift builder: a base gift, then the model, backdrop and pattern of the
// collectible, its number and how many were issued.

private final class VanityGiftBuilderArguments {
    let selectBase: () -> Void
    let selectModel: () -> Void
    let selectBackdrop: () -> Void
    let selectPattern: () -> Void
    let updateNumber: (String) -> Void
    let updateTotal: (String) -> Void
    let preview: () -> Void
    let add: () -> Void

    init(selectBase: @escaping () -> Void, selectModel: @escaping () -> Void, selectBackdrop: @escaping () -> Void, selectPattern: @escaping () -> Void, updateNumber: @escaping (String) -> Void, updateTotal: @escaping (String) -> Void, preview: @escaping () -> Void, add: @escaping () -> Void) {
        self.selectBase = selectBase
        self.selectModel = selectModel
        self.selectBackdrop = selectBackdrop
        self.selectPattern = selectPattern
        self.updateNumber = updateNumber
        self.updateTotal = updateTotal
        self.preview = preview
        self.add = add
    }
}

private enum VanityGiftBuilderSection: Int32 {
    case base
    case attributes
    case number
    case actions
}

private enum VanityGiftBuilderEntry: ItemListNodeEntry, Equatable {
    case base(String)
    case loading
    case model(String)
    case backdrop(String)
    case pattern(String)
    case number(String)
    case total(String)
    case preview(Bool)
    case add(Bool)
    case info

    var section: ItemListSectionId {
        switch self {
        case .base, .loading:
            return VanityGiftBuilderSection.base.rawValue
        case .model, .backdrop, .pattern:
            return VanityGiftBuilderSection.attributes.rawValue
        case .number, .total:
            return VanityGiftBuilderSection.number.rawValue
        case .preview, .add, .info:
            return VanityGiftBuilderSection.actions.rawValue
        }
    }

    var stableId: Int32 {
        switch self {
        case .base:
            return 0
        case .loading:
            return 1
        case .model:
            return 10
        case .backdrop:
            return 11
        case .pattern:
            return 12
        case .number:
            return 20
        case .total:
            return 21
        case .preview:
            return 30
        case .add:
            return 31
        case .info:
            return 32
        }
    }

    static func <(lhs: VanityGiftBuilderEntry, rhs: VanityGiftBuilderEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! VanityGiftBuilderArguments
        switch self {
        case let .base(label):
            return ItemListDisclosureItem(presentationData: presentationData, title: "Подарок", label: label, sectionId: self.section, style: .blocks, action: {
                arguments.selectBase()
            })
        case .loading:
            return ItemListTextItem(presentationData: presentationData, text: .plain("Загружаю модели, фоны и узоры…"), sectionId: self.section)
        case let .model(label):
            return ItemListDisclosureItem(presentationData: presentationData, title: "Модель", label: label, sectionId: self.section, style: .blocks, action: {
                arguments.selectModel()
            })
        case let .backdrop(label):
            return ItemListDisclosureItem(presentationData: presentationData, title: "Фон", label: label, sectionId: self.section, style: .blocks, action: {
                arguments.selectBackdrop()
            })
        case let .pattern(label):
            return ItemListDisclosureItem(presentationData: presentationData, title: "Узор", label: label, sectionId: self.section, style: .blocks, action: {
                arguments.selectPattern()
            })
        case let .number(text):
            return ItemListSingleLineInputItem(presentationData: presentationData, title: NSAttributedString(string: "Номер #"), text: text, placeholder: "1", type: .number, sectionId: self.section, textUpdated: { value in
                arguments.updateNumber(value)
            }, action: {})
        case let .total(text):
            return ItemListSingleLineInputItem(presentationData: presentationData, title: NSAttributedString(string: "Всего выпущено"), text: text, placeholder: "10000", type: .number, sectionId: self.section, textUpdated: { value in
                arguments.updateTotal(value)
            }, action: {})
        case let .preview(enabled):
            return ItemListActionItem(presentationData: presentationData, title: "Посмотреть, как выглядит", kind: enabled ? .generic : .disabled, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                arguments.preview()
            })
        case let .add(enabled):
            return ItemListActionItem(presentationData: presentationData, title: "Добавить в профиль", kind: enabled ? .generic : .disabled, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                arguments.add()
            })
        case .info:
            return ItemListTextItem(presentationData: presentationData, text: .plain("Подарок появится в твоём профиле первым, с отметкой \(VanityMod.mark). Он есть только на этом телефоне."), sectionId: self.section)
        }
    }
}

private struct VanityBaseGift: Equatable {
    let id: Int64
    let title: String
    let total: Int32?
}

private struct VanityGiftBuilderState: Equatable {
    var base: VanityBaseGift?
    var isLoading = false
    var models: [StarGift.UniqueGift.Attribute] = []
    var backdrops: [StarGift.UniqueGift.Attribute] = []
    var patterns: [StarGift.UniqueGift.Attribute] = []
    var model: Int = 0
    var backdrop: Int = 0
    var pattern: Int = 0
    var number = "1"
    var total = "10000"

    var attributes: [StarGift.UniqueGift.Attribute]? {
        guard self.models.indices.contains(self.model), self.backdrops.indices.contains(self.backdrop), self.patterns.indices.contains(self.pattern) else {
            return nil
        }
        return [self.models[self.model], self.backdrops[self.backdrop], self.patterns[self.pattern]]
    }
}

private func attributeName(_ attribute: StarGift.UniqueGift.Attribute) -> String {
    switch attribute {
    case let .model(name, _, _, _), let .pattern(name, _, _), let .backdrop(name, _, _, _, _, _, _):
        return name
    case .originalInfo:
        return ""
    }
}

private func attributeRarity(_ attribute: StarGift.UniqueGift.Attribute) -> String {
    let rarity: StarGift.UniqueGift.Attribute.Rarity
    switch attribute {
    case let .model(_, _, value, _), let .pattern(_, _, value), let .backdrop(_, _, _, _, _, _, value):
        rarity = value
    case .originalInfo:
        return ""
    }
    switch rarity {
    case let .permille(value):
        return value > 0 ? "\(Double(value) / 10.0)%" : "< 0.1%"
    case .uncommon:
        return "Uncommon"
    case .rare:
        return "Rare"
    case .epic:
        return "Epic"
    case .legendary:
        return "Legendary"
    }
}

private func attributeLabel(_ list: [StarGift.UniqueGift.Attribute], _ index: Int) -> String {
    guard list.indices.contains(index) else {
        return "—"
    }
    return "\(attributeName(list[index])) · \(attributeRarity(list[index]))"
}

/// every attribute of one kind the server knows for a gift, by name, without repeats
private func mergeAttributes(_ lists: [[StarGift.UniqueGift.Attribute]], kind: StarGift.UniqueGift.Attribute.AttributeType) -> [StarGift.UniqueGift.Attribute] {
    var seen = Set<String>()
    var result: [StarGift.UniqueGift.Attribute] = []
    for list in lists {
        for attribute in list where attribute.attributeType == kind {
            let name = attributeName(attribute)
            if !seen.contains(name) {
                seen.insert(name)
                result.append(attribute)
            }
        }
    }
    return result.sorted(by: { attributeName($0) < attributeName($1) })
}

private func vanityGiftBuilderEntries(state: VanityGiftBuilderState) -> [VanityGiftBuilderEntry] {
    var entries: [VanityGiftBuilderEntry] = []
    entries.append(.base(state.base?.title ?? "Выбрать"))
    if state.isLoading {
        entries.append(.loading)
    }
    if state.base != nil && !state.isLoading {
        entries.append(.model(attributeLabel(state.models, state.model)))
        entries.append(.backdrop(attributeLabel(state.backdrops, state.backdrop)))
        entries.append(.pattern(attributeLabel(state.patterns, state.pattern)))
        entries.append(.number(state.number))
        entries.append(.total(state.total))
    }
    let ready = state.attributes != nil
    entries.append(.preview(ready))
    entries.append(.add(ready))
    entries.append(.info)
    return entries
}

func vanityGiftBuilderController(context: AccountContext) -> ViewController {
    let statePromise = ValuePromise(VanityGiftBuilderState(), ignoreRepeated: true)
    let stateValue = Atomic(value: VanityGiftBuilderState())
    let updateState: ((inout VanityGiftBuilderState) -> Void) -> Void = { f in
        var state = stateValue.with { $0 }
        f(&state)
        let _ = stateValue.swap(state)
        statePromise.set(state)
    }

    let actionsDisposable = DisposableSet()
    let attributesDisposable = MetaDisposable()
    actionsDisposable.add(attributesDisposable)
    var pushControllerImpl: ((ViewController) -> Void)?
    var presentControllerImpl: ((ViewController) -> Void)?
    var dismissImpl: (() -> Void)?

    let showAlert: (String) -> Void = { text in
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        presentControllerImpl?(textAlertController(context: context, title: nil, text: text, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})]))
    }

    /// a list in an action sheet; picking a row calls back with its index
    let presentList: (String, [String], @escaping (Int) -> Void) -> Void = { title, rows, selected in
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        let actionSheet = ActionSheetController(presentationData: presentationData)
        var items: [ActionSheetItem] = [ActionSheetTextItem(title: title)]
        for (index, row) in rows.enumerated() {
            items.append(ActionSheetButtonItem(title: row, color: .accent, action: { [weak actionSheet] in
                actionSheet?.dismissAnimated()
                selected(index)
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
    }

    let loadAttributes: (VanityBaseGift) -> Void = { base in
        updateState { state in
            state.base = base
            state.isLoading = true
            state.models = []
            state.backdrops = []
            state.patterns = []
            state.model = 0
            state.backdrop = 0
            state.pattern = 0
            if let total = base.total {
                state.total = "\(total)"
            }
        }
        let resaleContext = ResaleGiftsContext(account: context.account, giftId: base.id, forCrafting: false)
        let resaleAttributes = resaleContext.state
        |> filter { state in
            return !state.attributes.isEmpty || state.dataState != .loading
        }
        |> take(1)
        |> map { state -> [StarGift.UniqueGift.Attribute] in
            return state.attributes
        }
        |> timeout(10.0, queue: .mainQueue(), alternate: .single([]))
        let previewAttributes = context.engine.payments.starGiftUpgradePreview(giftId: base.id)
        |> map { preview -> [StarGift.UniqueGift.Attribute] in
            return preview?.attributes ?? []
        }
        attributesDisposable.set((combineLatest(resaleAttributes, previewAttributes)
        |> deliverOnMainQueue).start(next: { resale, preview in
            let _ = resaleContext
            let lists = [resale, preview]
            updateState { state in
                state.isLoading = false
                state.models = mergeAttributes(lists, kind: .model)
                state.backdrops = mergeAttributes(lists, kind: .backdrop)
                state.patterns = mergeAttributes(lists, kind: .pattern)
            }
            if lists.allSatisfy({ $0.isEmpty }) {
                showAlert("Сервер не отдаёт модели для этого подарка. Выбери другой.")
            }
        }))
    }

    let makeGift: () -> StarGift.UniqueGift? = {
        let state = stateValue.with { $0 }
        guard let base = state.base, let attributes = state.attributes else {
            return nil
        }
        let number = Int32(clamping: max(1, Int(state.number.filter { $0.isASCII && $0.isNumber }.prefix(9)) ?? 1))
        let total = Int32(clamping: max(1, Int(state.total.filter { $0.isASCII && $0.isNumber }.prefix(9)) ?? 1))
        return VanityMod.customGift(giftId: base.id, title: base.title, number: number, total: total, attributes: attributes, accountPeerId: context.account.peerId, id: Int64.random(in: 1 ..< Int64.max))
    }

    let arguments = VanityGiftBuilderArguments(selectBase: {
        actionsDisposable.add((context.engine.payments.cachedStarGifts()
        |> take(1)
        |> deliverOnMainQueue).start(next: { gifts in
            var bases: [VanityBaseGift] = []
            var seen = Set<Int64>()
            for gift in gifts ?? [] {
                if case let .generic(gift) = gift, gift.availability != nil, !seen.contains(gift.id) {
                    seen.insert(gift.id)
                    bases.append(VanityBaseGift(id: gift.id, title: gift.title ?? "Gift", total: gift.availability?.total))
                }
            }
            if bases.isEmpty {
                showAlert("Список подарков ещё не загружен. Открой магазин подарков и попробуй снова.")
                return
            }
            presentList("Выбери подарок", bases.map(\.title), { index in
                loadAttributes(bases[index])
            })
        }))
    }, selectModel: {
        let state = stateValue.with { $0 }
        presentList("Модель", state.models.indices.map { attributeLabel(state.models, $0) }, { index in
            updateState { $0.model = index }
        })
    }, selectBackdrop: {
        let state = stateValue.with { $0 }
        presentList("Фон", state.backdrops.indices.map { attributeLabel(state.backdrops, $0) }, { index in
            updateState { $0.backdrop = index }
        })
    }, selectPattern: {
        let state = stateValue.with { $0 }
        presentList("Узор", state.patterns.indices.map { attributeLabel(state.patterns, $0) }, { index in
            updateState { $0.pattern = index }
        })
    }, updateNumber: { value in
        updateState { $0.number = value }
    }, updateTotal: { value in
        updateState { $0.total = value }
    }, preview: {
        if let gift = makeGift() {
            pushControllerImpl?(GiftViewScreen(context: context, subject: .uniqueGift(gift, context.account.peerId)))
        }
    }, add: {
        if let gift = makeGift() {
            VanityMod.shared.addGift(gift)
            dismissImpl?()
        }
    })

    let signal = combineLatest(context.sharedContext.presentationData, statePromise.get())
    |> deliverOnMainQueue
    |> map { presentationData, state -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text("Свой подарок"), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: vanityGiftBuilderEntries(state: state), style: .blocks, animateChanges: false)
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
    dismissImpl = { [weak controller] in
        let _ = (controller?.navigationController as? NavigationController)?.popViewController(animated: true)
    }
    return controller
}
