import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import ItemListUI
import AccountContext
import ComponentFlow
import GiftItemComponent

// A Vanity mod gift in a settings list: large, as the builder's live preview, or as a row
// with its picture beside its name. Every one wears the red MOD ribbon.

final class VanityGiftPreviewItem: ListViewItem, ItemListItem {
    enum Layout {
        case large
        case row
    }

    let context: AccountContext
    let presentationData: ItemListPresentationData
    let gift: StarGift.UniqueGift?
    let layout: Layout
    let title: String
    let subtitle: String
    let sectionId: ItemListSectionId
    let action: (() -> Void)?

    var selectable: Bool {
        return self.action != nil
    }

    init(context: AccountContext, presentationData: ItemListPresentationData, gift: StarGift.UniqueGift?, layout: Layout, title: String, subtitle: String, sectionId: ItemListSectionId, action: (() -> Void)?) {
        self.context = context
        self.presentationData = presentationData
        self.gift = gift
        self.layout = layout
        self.title = title
        self.subtitle = subtitle
        self.sectionId = sectionId
        self.action = action
    }

    func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, neighbors: ListViewItemNeighbors, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        async {
            let node = VanityGiftPreviewItemNode()
            let (layout, apply) = node.asyncLayout()(self, params, itemListNeighbors(item: self, topFacet: neighbors.previous?.base(ItemListNeighborFacet.self), bottomFacet: neighbors.next?.base(ItemListNeighborFacet.self)))

            node.contentSize = layout.contentSize
            node.insets = layout.insets

            Queue.mainQueue().async {
                completion(node, {
                    return (nil, { _ in apply() })
                })
            }
        }
    }

    func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: @escaping () -> ListViewItemNode, params: ListViewItemLayoutParams, neighbors: ListViewItemNeighbors, animation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNodeLayout, @escaping (ListViewItemApply) -> Void) -> Void) {
        Queue.mainQueue().async {
            guard let nodeValue = node() as? VanityGiftPreviewItemNode else {
                assertionFailure()
                return
            }

            let makeLayout = nodeValue.asyncLayout()

            async {
                let (layout, apply) = makeLayout(self, params, itemListNeighbors(item: self, topFacet: neighbors.previous?.base(ItemListNeighborFacet.self), bottomFacet: neighbors.next?.base(ItemListNeighborFacet.self)))
                Queue.mainQueue().async {
                    completion(layout, { _ in
                        apply()
                    })
                }
            }
        }
    }

    func selected(listView: ListView) {
        listView.clearHighlightAnimated(true)
        self.action?()
    }
}

final class VanityGiftPreviewItemNode: ListViewItemNode {
    private let backgroundNode: ASDisplayNode
    private let titleNode: TextNode
    private let subtitleNode: TextNode
    private let placeholderNode: TextNode
    private let gift = ComponentView<Empty>()

    private var item: VanityGiftPreviewItem?

    init() {
        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.isLayerBacked = true
        self.backgroundNode.cornerRadius = 12.0

        self.titleNode = TextNode()
        self.titleNode.isUserInteractionEnabled = false
        self.subtitleNode = TextNode()
        self.subtitleNode.isUserInteractionEnabled = false
        self.placeholderNode = TextNode()
        self.placeholderNode.isUserInteractionEnabled = false

        super.init(layerBacked: false)

        self.addSubnode(self.backgroundNode)
        self.addSubnode(self.titleNode)
        self.addSubnode(self.subtitleNode)
        self.addSubnode(self.placeholderNode)
    }

    func asyncLayout() -> (_ item: VanityGiftPreviewItem, _ params: ListViewItemLayoutParams, _ neighbors: ItemListNeighbors) -> (ListViewItemNodeLayout, () -> Void) {
        let makeTitleLayout = TextNode.asyncLayout(self.titleNode)
        let makeSubtitleLayout = TextNode.asyncLayout(self.subtitleNode)
        let makePlaceholderLayout = TextNode.asyncLayout(self.placeholderNode)

        return { [weak self] item, params, neighbors in
            let theme = item.presentationData.theme
            let isLarge = item.layout == .large
            let sideInset: CGFloat = 16.0 + params.leftInset
            let giftSize: CGFloat = isLarge ? 150.0 : 64.0
            let textWidth = isLarge ? params.width - sideInset * 2.0 : params.width - sideInset * 2.0 - giftSize - 14.0 - params.rightInset

            let titleFont = isLarge ? Font.semibold(17.0) : Font.medium(16.0)
            let (titleLayout, titleApply) = makeTitleLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: item.title, font: titleFont, textColor: theme.list.itemPrimaryTextColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: max(1.0, textWidth), height: .greatestFiniteMagnitude), alignment: isLarge ? .center : .natural, cutout: nil, insets: UIEdgeInsets()))
            let (subtitleLayout, subtitleApply) = makeSubtitleLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: item.subtitle, font: Font.regular(14.0), textColor: theme.list.itemSecondaryTextColor), backgroundColor: nil, maximumNumberOfLines: 2, truncationType: .end, constrainedSize: CGSize(width: max(1.0, textWidth), height: .greatestFiniteMagnitude), alignment: isLarge ? .center : .natural, cutout: nil, insets: UIEdgeInsets()))
            let (placeholderLayout, placeholderApply) = makePlaceholderLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: item.gift == nil ? "Выбери подарок, модель, фон и символ — он появится здесь" : "", font: Font.regular(15.0), textColor: theme.list.itemSecondaryTextColor), backgroundColor: nil, maximumNumberOfLines: 3, truncationType: .end, constrainedSize: CGSize(width: max(1.0, giftSize - 16.0), height: .greatestFiniteMagnitude), alignment: .center, cutout: nil, insets: UIEdgeInsets()))

            let contentHeight: CGFloat
            if isLarge {
                contentHeight = 16.0 + giftSize + 12.0 + titleLayout.size.height + 4.0 + subtitleLayout.size.height + 16.0
            } else {
                contentHeight = giftSize + 16.0
            }
            let contentSize = CGSize(width: params.width, height: contentHeight)
            let insets = itemListNeighborsGroupedInsets(neighbors, params)
            let layout = ListViewItemNodeLayout(contentSize: contentSize, insets: insets)

            return (layout, { [weak self] in
                guard let self else {
                    return
                }
                self.item = item

                let _ = titleApply()
                let _ = subtitleApply()
                let _ = placeholderApply()

                self.backgroundNode.backgroundColor = theme.list.itemBlocksBackgroundColor
                self.backgroundNode.frame = CGRect(origin: CGPoint(x: params.leftInset + 16.0, y: 0.0), size: CGSize(width: params.width - params.leftInset - params.rightInset - 32.0, height: contentHeight))

                let giftFrame: CGRect
                if isLarge {
                    giftFrame = CGRect(origin: CGPoint(x: floor((params.width - giftSize) / 2.0), y: 16.0), size: CGSize(width: giftSize, height: giftSize))
                    self.titleNode.frame = CGRect(origin: CGPoint(x: floor((params.width - titleLayout.size.width) / 2.0), y: giftFrame.maxY + 12.0), size: titleLayout.size)
                    self.subtitleNode.frame = CGRect(origin: CGPoint(x: floor((params.width - subtitleLayout.size.width) / 2.0), y: self.titleNode.frame.maxY + 4.0), size: subtitleLayout.size)
                } else {
                    giftFrame = CGRect(origin: CGPoint(x: sideInset + 12.0, y: 8.0), size: CGSize(width: giftSize, height: giftSize))
                    let textX = giftFrame.maxX + 14.0
                    let textHeight = titleLayout.size.height + 2.0 + subtitleLayout.size.height
                    let textY = floor((contentHeight - textHeight) / 2.0)
                    self.titleNode.frame = CGRect(origin: CGPoint(x: textX, y: textY), size: titleLayout.size)
                    self.subtitleNode.frame = CGRect(origin: CGPoint(x: textX, y: textY + titleLayout.size.height + 2.0), size: subtitleLayout.size)
                }
                self.placeholderNode.frame = CGRect(origin: CGPoint(x: floor(giftFrame.midX - placeholderLayout.size.width / 2.0), y: floor(giftFrame.midY - placeholderLayout.size.height / 2.0)), size: placeholderLayout.size)

                if let gift = item.gift {
                    let _ = self.gift.update(
                        transition: .immediate,
                        component: AnyComponent(GiftItemComponent(
                            context: item.context,
                            theme: theme,
                            strings: item.presentationData.strings,
                            subject: .uniqueGift(gift: gift, price: nil),
                            ribbon: GiftItemComponent.Ribbon(text: VanityMod.mark, font: .larger, color: .red),
                            animateChanges: true,
                            mode: .thumbnail
                        )),
                        environment: {},
                        containerSize: giftFrame.size
                    )
                    if let giftView = self.gift.view {
                        if giftView.superview == nil {
                            giftView.isUserInteractionEnabled = false
                            self.view.addSubview(giftView)
                        }
                        giftView.isHidden = false
                        giftView.frame = giftFrame
                    }
                } else {
                    self.gift.view?.isHidden = true
                }
            })
        }
    }

    override func animateInsertion(_ currentTimestamp: Double, duration: Double, options: ListViewItemAnimationOptions) {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
    }

    override func animateRemoved(_ currentTimestamp: Double, duration: Double) {
        self.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.15, removeOnCompletion: false)
    }
}
