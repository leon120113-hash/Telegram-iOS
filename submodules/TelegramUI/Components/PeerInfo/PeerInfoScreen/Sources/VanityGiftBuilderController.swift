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

// The Vanity mod's gift builder: a base gift, then the model, backdrop and symbol of the
// collectible — picked in Telegram's own variants screen, with every option drawn — its
// number and how many were issued. The gift as it will look stays at the top throughout.

private final class VanityGiftBuilderArguments {
    let context: AccountContext
    let selectBase: () -> Void
    let openVariants: (StarGift.UniqueGift.Attribute.AttributeType?) -> Void
    let updateNumber: (String) -> Void
    let updateTotal: (String) -> Void
    let openPreview: () -> Void
    let add: () -> Void

    init(context: AccountContext, selectBase: @escaping () -> Void, openVariants: @escaping (StarGift.UniqueGift.Attribute.AttributeType?) -> Void, updateNumber: @escaping (String) -> Void, updateTotal: @escaping (String) -> Void, openPreview: @escaping () -> Void, add: @escaping () -> Void) {
        self.context = context
        self.selectBase = selectBase
        self.openVariants = openVariants
        self.updateNumber = updateNumber
        self.updateTotal = updateTotal
        self.openPreview = openPreview
        self.add = add
    }
}

private enum VanityGiftBuilderSection: Int32 {
    case preview
    case base
    case attributes
    case number
    case actions
}

private enum VanityGiftBuilderEntry: ItemListNodeEntry, Equatable {
    case preview(StarGift.UniqueGift?, String, String)
    case base(String)
    case loading
    case attributesHeader
    case variants
    case model(String)
    case backdrop(String)
    case symbol(String)
    case poolInfo(String)
    case numberHeader
    case number(String)
    case total(String)
    case add(Bool)
    case openPreview(Bool)
    case info

    var section: ItemListSectionId {
        switch self {
        case .preview:
            return VanityGiftBuilderSection.preview.rawValue
        case .base, .loading:
            return VanityGiftBuilderSection.base.rawValue
        case .attributesHeader, .variants, .model, .backdrop, .symbol, .poolInfo:
            return VanityGiftBuilderSection.attributes.rawValue
        case .numberHeader, .number, .total:
            return VanityGiftBuilderSection.number.rawValue
        case .add, .openPreview, .info:
            return VanityGiftBuilderSection.actions.rawValue
        }
    }

    var stableId: Int32 {
        switch self {
        case .preview:
            return 0
        case .base:
            return 10
        case .loading:
            return 11
        case .attributesHeader:
            return 20
        case .variants:
            return 21
        case .model:
            return 22
        case .backdrop:
            return 23
        case .symbol:
            return 24
        case .poolInfo:
            return 25
        case .numberHeader:
            return 30
        case .number:
            return 31
        case .total:
            return 32
        case .add:
            return 40
        case .openPreview:
            return 41
        case .info:
            return 42
        }
    }

    static func <(lhs: VanityGiftBuilderEntry, rhs: VanityGiftBuilderEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! VanityGiftBuilderArguments
        switch self {
        case let .preview(gift, title, subtitle):
            return VanityGiftPreviewItem(context: arguments.context, presentationData: presentationData, gift: gift, layout: .large, title: title, subtitle: subtitle, sectionId: self.section, action: nil)
        case let .base(label):
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, title: "Подарок", label: label, sectionId: self.section, style: .blocks, action: {
                arguments.selectBase()
            })
        case .loading:
            return ItemListTextItem(presentationData: presentationData, text: .plain("Загружаю модели, фоны и символы…"), sectionId: self.section)
        case .attributesHeader:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: "ВНЕШНИЙ ВИД", sectionId: self.section)
        case .variants:
            return ItemListActionItem(presentationData: presentationData, systemStyle: .glass, title: "Выбрать модель, фон и символ", kind: .generic, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                arguments.openVariants(nil)
            })
        case let .model(label):
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, title: "Модель", label: label, sectionId: self.section, style: .blocks, action: {
                arguments.openVariants(.model)
            })
        case let .backdrop(label):
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, title: "Фон", label: label, sectionId: self.section, style: .blocks, action: {
                arguments.openVariants(.backdrop)
            })
        case let .symbol(label):
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, title: "Символ", label: label, sectionId: self.section, style: .blocks, action: {
                arguments.openVariants(.pattern)
            })
        case let .poolInfo(text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        case .numberHeader:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: "НОМЕР", sectionId: self.section)
        case let .number(text):
            return ItemListSingleLineInputItem(presentationData: presentationData, systemStyle: .glass, title: NSAttributedString(string: "Номер #"), text: text, placeholder: "1", type: .number, sectionId: self.section, textUpdated: { value in
                arguments.updateNumber(value)
            }, action: {})
        case let .total(text):
            return ItemListSingleLineInputItem(presentationData: presentationData, systemStyle: .glass, title: NSAttributedString(string: "Всего выпущено"), text: text, placeholder: "10000", type: .number, sectionId: self.section, textUpdated: { value in
                arguments.updateTotal(value)
            }, action: {})
        case let .add(enabled):
            return ItemListActionItem(presentationData: presentationData, systemStyle: .glass, title: "Добавить в профиль", kind: enabled ? .generic : .disabled, alignment: .center, sectionId: self.section, style: .blocks, action: {
                arguments.add()
            })
        case let .openPreview(enabled):
            return ItemListActionItem(presentationData: presentationData, systemStyle: .glass, title: "Открыть в окне подарка", kind: enabled ? .generic : .disabled, alignment: .center, sectionId: self.section, style: .blocks, action: {
                arguments.openPreview()
            })
        case .info:
            return ItemListTextItem(presentationData: presentationData, text: .plain("Подарок встанет в профиле первым, с красной лентой \(VanityMod.mark). Он есть только на этом телефоне."), sectionId: self.section)
        }
    }
}

private struct VanityGiftBuilderState: Equatable {
    var base: StarGift?
    var isLoading = false
    var attributes: [StarGift.UniqueGift.Attribute] = []
    var model: StarGift.UniqueGift.Attribute?
    var backdrop: StarGift.UniqueGift.Attribute?
    var symbol: StarGift.UniqueGift.Attribute?
    var number = "1"
    var total = "10000"
    /// gifts whose backdrops and symbols are in the pool, of all there are
    var poolDone = 0
    var poolTotal = 0

    var baseGift: StarGift.Gift? {
        if case let .generic(gift) = self.base {
            return gift
        }
        return nil
    }

    var selected: [StarGift.UniqueGift.Attribute]? {
        guard let model = self.model, let backdrop = self.backdrop, let symbol = self.symbol else {
            return nil
        }
        return [model, backdrop, symbol]
    }

    var numberValue: Int32 {
        return Int32(clamping: max(1, Int(self.number.filter { $0.isASCII && $0.isNumber }.prefix(9)) ?? 1))
    }

    var totalValue: Int32 {
        return Int32(clamping: max(1, Int(self.total.filter { $0.isASCII && $0.isNumber }.prefix(9)) ?? 1))
    }
}

private func attributeName(_ attribute: StarGift.UniqueGift.Attribute?) -> String {
    guard let attribute else {
        return "—"
    }
    switch attribute {
    case let .model(name, _, _, _), let .pattern(name, _, _), let .backdrop(name, _, _, _, _, _, _):
        return name
    case .originalInfo:
        return "—"
    }
}

/// attributes from several lists, without repeats
private func mergeAttributes(_ lists: [[StarGift.UniqueGift.Attribute]]) -> [StarGift.UniqueGift.Attribute] {
    var seen = Set<String>()
    var result: [StarGift.UniqueGift.Attribute] = []
    for list in lists {
        for attribute in list where attribute.attributeType != .originalInfo {
            let key = VanityMod.attributeKey(attribute)
            if !seen.contains(key) {
                seen.insert(key)
                result.append(attribute)
            }
        }
    }
    return result
}

/// every model, backdrop and symbol the server lists for a gift: its resale filters, then its upgrade samples
private func fetchGiftAttributes(context: AccountContext, giftId: Int64) -> Signal<[StarGift.UniqueGift.Attribute], NoError> {
    return Signal { subscriber in
        let resaleContext = ResaleGiftsContext(account: context.account, giftId: giftId, forCrafting: false)
        let resale = resaleContext.state
        |> filter { state in
            return !state.attributes.isEmpty || state.dataState != .loading
        }
        |> take(1)
        |> map { state -> [StarGift.UniqueGift.Attribute] in
            return state.attributes
        }
        |> timeout(8.0, queue: .mainQueue(), alternate: .single([]))
        let preview = context.engine.payments.starGiftUpgradePreview(giftId: giftId)
        |> map { preview -> [StarGift.UniqueGift.Attribute] in
            return preview?.attributes ?? []
        }
        let disposable = (combineLatest(resale, preview)
        |> map { resale, preview -> [StarGift.UniqueGift.Attribute] in
            return mergeAttributes([resale, preview])
        }).start(next: { attributes in
            subscriber.putNext(attributes)
        }, completed: {
            subscriber.putCompletion()
        })
        return ActionDisposable {
            // * the context lives until the request is done with
            let _ = resaleContext
            disposable.dispose()
        }
    }
}

private func firstAttribute(_ attributes: [StarGift.UniqueGift.Attribute], _ kind: StarGift.UniqueGift.Attribute.AttributeType) -> StarGift.UniqueGift.Attribute? {
    return attributes.first(where: { $0.attributeType == kind })
}

private func makeGift(state: VanityGiftBuilderState, accountPeerId: EnginePeer.Id, id: Int64) -> StarGift.UniqueGift? {
    guard let base = state.baseGift, let attributes = state.selected else {
        return nil
    }
    return VanityMod.customGift(giftId: base.id, title: base.title ?? "Gift", number: state.numberValue, total: state.totalValue, attributes: attributes, accountPeerId: accountPeerId, id: id)
}

private func vanityGiftBuilderEntries(state: VanityGiftBuilderState, accountPeerId: EnginePeer.Id) -> [VanityGiftBuilderEntry] {
    var entries: [VanityGiftBuilderEntry] = []
    let gift = makeGift(state: state, accountPeerId: accountPeerId, id: 0)
    let title = gift.map { "\($0.title) #\($0.number)" } ?? "Твой подарок"
    let subtitle = gift != nil ? "\(attributeName(state.model)) · \(attributeName(state.backdrop)) · \(attributeName(state.symbol))" : ""
    entries.append(.preview(gift, title, subtitle))

    entries.append(.base(state.baseGift?.title ?? "Выбрать"))
    if state.isLoading {
        entries.append(.loading)
    }
    if state.baseGift != nil && !state.isLoading && !state.attributes.isEmpty {
        entries.append(.attributesHeader)
        entries.append(.variants)
        entries.append(.model(attributeName(state.model)))
        entries.append(.backdrop(attributeName(state.backdrop)))
        entries.append(.symbol(attributeName(state.symbol)))
        let pool = VanityMod.shared.attributePool.attributes
        let models = pool.filter { $0.attributeType == .model }.count
        let backdrops = pool.filter { $0.attributeType == .backdrop }.count
        let symbols = pool.filter { $0.attributeType == .pattern }.count
        var poolText = "Модели, фоны и символы всех подарков, и распроданных тоже, подходят к любому: сейчас \(models) моделей, \(backdrops) фонов, \(symbols) символов. Модели этого подарка — первыми."
        if state.poolTotal > 0 && state.poolDone < state.poolTotal {
            poolText += " Собираю: \(state.poolDone) из \(state.poolTotal) подарков…"
        }
        entries.append(.poolInfo(poolText))
        entries.append(.numberHeader)
        entries.append(.number(state.number))
        entries.append(.total(state.total))
    }
    let ready = gift != nil
    entries.append(.add(ready))
    entries.append(.openPreview(ready))
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

    let loadAttributes: (StarGift) -> Void = { base in
        guard case let .generic(gift) = base else {
            return
        }
        updateState { state in
            state.base = base
            state.isLoading = true
            state.attributes = []
            state.model = nil
            state.backdrop = nil
            state.symbol = nil
            if let total = gift.availability?.total {
                state.total = "\(total)"
            }
        }
        attributesDisposable.set((fetchGiftAttributes(context: context, giftId: gift.id)
        |> deliverOnMainQueue).start(next: { attributes in
            VanityMod.shared.addToPool(giftId: gift.id, attributes: attributes)
            updateState { state in
                state.isLoading = false
                state.attributes = attributes
                state.model = firstAttribute(attributes, .model)
                state.backdrop = firstAttribute(attributes, .backdrop)
                state.symbol = firstAttribute(attributes, .pattern)
            }
            if attributes.isEmpty {
                showAlert("Сервер не отдаёт модели для этого подарка. Выбери другой.")
            }
        }))
    }

    let arguments = VanityGiftBuilderArguments(context: context, selectBase: {
        actionsDisposable.add((context.engine.payments.cachedStarGifts()
        |> take(1)
        |> deliverOnMainQueue).start(next: { gifts in
            var bases: [StarGift] = []
            var seen = Set<Int64>()
            for gift in gifts ?? [] {
                if case let .generic(generic) = gift, generic.availability != nil, !seen.contains(generic.id) {
                    seen.insert(generic.id)
                    bases.append(gift)
                }
            }
            if bases.isEmpty {
                showAlert("Список подарков ещё не загружен. Открой магазин подарков и попробуй снова.")
                return
            }
            let presentationData = context.sharedContext.currentPresentationData.with { $0 }
            let actionSheet = ActionSheetController(presentationData: presentationData)
            var items: [ActionSheetItem] = [ActionSheetTextItem(title: "Выбери подарок")]
            for base in bases {
                guard case let .generic(generic) = base else {
                    continue
                }
                items.append(ActionSheetButtonItem(title: generic.title ?? "Gift", color: .accent, action: { [weak actionSheet] in
                    actionSheet?.dismissAnimated()
                    loadAttributes(base)
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
    }, openVariants: { focus in
        let state = stateValue.with { $0 }
        guard let base = state.base, !state.attributes.isEmpty else {
            return
        }
        let focused: StarGift.UniqueGift.Attribute?
        switch focus {
        case .some(.model):
            focused = state.model
        case .some(.backdrop):
            focused = state.backdrop
        case .some(.pattern):
            focused = state.symbol
        default:
            focused = nil
        }
        // * Telegram's own variants screen: every option drawn, the gift at the top as picked;
        // * this gift's own attributes first, then the models, backdrops and symbols of every gift in the pool
        let attributes = mergeAttributes([state.attributes, VanityMod.shared.attributePool.attributes])
        let variants = GiftUpgradeVariantsScreen(context: context, gift: base, attributes: attributes, selectedAttributes: state.selected, focusedAttribute: focused, selectionUpdated: { selected in
            updateState { state in
                for attribute in selected {
                    switch attribute.attributeType {
                    case .model:
                        state.model = attribute
                    case .backdrop:
                        state.backdrop = attribute
                    case .pattern:
                        state.symbol = attribute
                    case .originalInfo:
                        break
                    }
                }
            }
        })
        pushControllerImpl?(variants)
    }, updateNumber: { value in
        updateState { $0.number = value }
    }, updateTotal: { value in
        updateState { $0.total = value }
    }, openPreview: {
        if let gift = makeGift(state: stateValue.with { $0 }, accountPeerId: context.account.peerId, id: Int64.random(in: 1 ..< Int64.max)) {
            pushControllerImpl?(GiftViewScreen(context: context, subject: .uniqueGift(gift, context.account.peerId)))
        }
    }, add: {
        if let gift = makeGift(state: stateValue.with { $0 }, accountPeerId: context.account.peerId, id: Int64.random(in: 1 ..< Int64.max)) {
            VanityMod.shared.addGift(gift)
            dismissImpl?()
        }
    })

    // * the pool of backdrops and symbols: each gift not yet in it is asked once, one after another,
    // * gently enough not to hit flood limits; what is collected stays on the device
    let crawlCancelled = Atomic<Bool>(value: false)
    let crawlDisposable = MetaDisposable()
    actionsDisposable.add(crawlDisposable)
    var crawlGiftIds: [Int64] = []
    var crawlStep: ((Int) -> Void)?
    crawlStep = { index in
        if crawlCancelled.with({ $0 }) {
            crawlStep = nil
            return
        }
        guard index < crawlGiftIds.count else {
            updateState { $0.poolDone = $0.poolTotal }
            crawlStep = nil
            return
        }
        let giftId = crawlGiftIds[index]
        crawlDisposable.set((fetchGiftAttributes(context: context, giftId: giftId)
        |> deliverOnMainQueue).start(next: { attributes in
            VanityMod.shared.addToPool(giftId: giftId, attributes: attributes)
            updateState { $0.poolDone += 1 }
            Queue.mainQueue().after(0.4, {
                crawlStep?(index + 1)
            })
        }))
    }
    actionsDisposable.add((context.engine.payments.cachedStarGifts()
    |> take(1)
    |> deliverOnMainQueue).start(next: { gifts in
        var ids: [Int64] = []
        for gift in gifts ?? [] {
            if case let .generic(generic) = gift, generic.availability != nil, !ids.contains(generic.id) {
                ids.append(generic.id)
            }
        }
        let known = Set(VanityMod.shared.attributePool.giftIds)
        crawlGiftIds = ids.filter { !known.contains($0) }
        updateState { state in
            state.poolTotal = ids.count
            state.poolDone = ids.count - crawlGiftIds.count
        }
        crawlStep?(0)
    }))

    let signal = combineLatest(context.sharedContext.presentationData, statePromise.get())
    |> deliverOnMainQueue
    |> map { presentationData, state -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text("Свой подарок"), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: vanityGiftBuilderEntries(state: state, accountPeerId: context.account.peerId), style: .blocks, animateChanges: true)
        return (controllerState, (listState, arguments))
    }
    |> afterDisposed {
        let _ = crawlCancelled.swap(true)
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
