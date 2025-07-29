//
//  HTMenuTitleView.swift
//
//  Created by Nansen on 2025/6/18.
//

import Foundation
import UIKit
import SnapKit

@MainActor
public protocol HTMenuPagesTitleViewDataSource: AnyObject {
    /// 提供数据源. 刷新调用
    func menuPagesTitleViewShowTitles(titleView: HTMenuPagesTitleView) -> [String]
    
    /// 可以配置leftView,rightView. 刷新调用, 调用前会清空 leftView, rightView 的子控件
    func menuPagesTitleViewConfigLeftRightView(titleView: HTMenuPagesTitleView, leftView: UIView, rightView: UIView)
}

public class HTMenuPagesTitleItemView: UIView {
    
    public var index: Int = 0
    
    public var label: UILabel = UILabel()
    
    var isSelect: Bool = false {
        didSet {
            label.textColor = isSelect ? selectColor : normalColor
            label.font = isSelect ? selectFont : normalFont
        }
    }
    
    var normalColor: UIColor = .black {
        didSet {
            if isSelect == false {
                label.textColor = normalColor
            }
        }
    }
    var normalFont: UIFont = .systemFont(ofSize: 16) {
        didSet {
            if isSelect == false {
                label.font = normalFont
            }
        }
    }
    var selectColor: UIColor = .black {
        didSet {
            if isSelect {
                label.textColor = selectColor
            }
        }
    }
    var selectFont: UIFont = .systemFont(ofSize: 20, weight: .bold) {
        didSet {
            if isSelect {
                label.font = selectFont
            }
        }
    }
    
    init(frame: CGRect,
         nColor: UIColor, 
         nFont: UIFont, 
         sColor: UIColor, 
         sFont: UIFont) {
        self.normalColor = nColor
        self.normalFont = nFont
        self.selectColor = sColor
        self.selectFont = sFont
        super.init(frame: frame)
        setupUI()
    }
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }
    private func setupUI() {
        label.textAlignment = .center
        label.font = normalFont
        label.textColor = normalColor
        addSubview(label)
        label.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.top.left.equalToSuperview()
        }
    }
}

public class HTMenuPagesTitleConfig {
    /// 间距
    public var spacing: CGFloat = 30
    /// 左边宽度
    public var leftViewW: CGFloat = 0
    /// 右边宽度
    public var rightViewW: CGFloat = 0
    
    /// 正常状态
    public var normalColor: UIColor = .black
    public var normalFont: UIFont = .systemFont(ofSize: 16)
    
    /// 选中状态
    public var selectColor: UIColor = .black
    public var selectFont: UIFont = .systemFont(ofSize: 20, weight: .bold)
    
    /// 底部线的配置
    public var showLine: Bool = true
    public var lineColor: UIColor = .black
    public var lineBottomMargin: CGFloat = 0
    public var lineHeight: CGFloat = 2.0
    
    /// 如果不够滑动, 居中显示(间距会变大)
    public var ifThinAtCenter = true
    
    public init() {}
}



public class HTMenuPagesTitleView: UIView {
    /// 数据源
    weak var dataSource: HTMenuPagesTitleViewDataSource?
    /// 配置项
    var config: HTMenuPagesTitleConfig = HTMenuPagesTitleConfig()
    /// 当前选中的Index
    var currentIndex: Int = 0
    /// 标签的总个数
    var totalCount: Int {
        return itemTitleArr.count
    }
    /// 新选择了一个标签
    var didChooseItemHandler: ((_ titleItemView: HTMenuPagesTitleItemView) -> Void)?
    /// 再次点击了这个标签
    var didClickItemAgainHanlder:((_ titleItemView: HTMenuPagesTitleItemView) -> Void)?
    
    /// 刷新数据
    private var needUpdateUI: Bool = false
    
    
    private lazy var scrollView: HTMenuScrollView = {
        let view = HTMenuScrollView()
        view.showsVerticalScrollIndicator = false
        view.showsHorizontalScrollIndicator = false
        view.bounces = true
        view.delegate = self
        return view
    }()
    
    
    private lazy var leftView: UIView = UIView()
    private lazy var rightView: UIView = UIView()
    private lazy var itemContentView: UIView = UIView()
    private var lineView: UIView?
    
    private var itemTitleArr: [String] = []
    private var itemViewArray: [HTMenuPagesTitleItemView] = []
    private var itemTextWidthArray: [CGFloat] = []
    
    private var isDragging: Bool = false
    private var pageIsDragging: Bool = false {
        didSet {
            if pageIsDragging {
                scrollView.isUserInteractionEnabled = false
            }
            else {
                scrollView.isUserInteractionEnabled = true
            }
        }
    }
    
    public override func layoutSubviews() {
        super.layoutSubviews()
        
        if needUpdateUI {
            needUpdateUI = false
            updateUI()
        }
    }
    
    public init(config: HTMenuPagesTitleConfig, dataSource: HTMenuPagesTitleViewDataSource) {
        self.config = config
        self.dataSource = dataSource
        super.init(frame: CGRect.zero)
        setupUI()
    }
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }
    
    
    public func loadData() {
        guard let dataSource = dataSource else { return }
        
        itemTitleArr.removeAll()
        let titles = dataSource.menuPagesTitleViewShowTitles(titleView: self)
        itemTitleArr.append(contentsOf: titles)
        
        if currentIndex >= totalCount {
            currentIndex = 0
        }
        
        if bounds.height > 0 {
            updateUI()
        }
        else {
            needUpdateUI = true
        }
    }
    
    /// pages手动拖动, 从 from 到 to 移动, percent 是相对整页的百分比
    public func pageDragging(fromIndex: Int, toIndex: Int, percent: Double) {
        guard fromIndex == currentIndex else {
            assertionFailure("HTMenuTitleView [pageDragging] currentIndex 不匹配!!! fromIndex=\(fromIndex), currentIndex=\(currentIndex)")
            return
        }
        
        let totalCount = itemTextWidthArray.count
        guard (0..<totalCount).contains(fromIndex), (0..<totalCount).contains(toIndex) else {
            assertionFailure("HTMenuTitleView [pageDragging] 参数 越界!!! fromIndex=\(fromIndex), toIndex=\(toIndex), count=\(totalCount)")
            return
        }
        
        let p = max(0.0, min(percent, 1.0))
        
        pageIsDragging = true
        
        if let line = lineView {
            
            let lineWFr = itemTextWidthArray[fromIndex]
            let lineWTo = itemTextWidthArray[toIndex]
            let lineCenterXFr = itemViewArray[fromIndex].frame.midX
            let lineCenterXTo = itemViewArray[toIndex].frame.midX
            
            let cx = (1.0-p)*lineCenterXFr + p*lineCenterXTo
            let w = (1.0-p)*lineWFr + p*lineWTo
            let h = line.frame.height
            let y = line.frame.minY
            let x = cx-w/2.0
            line.frame = CGRect(x: x, y: y, width: w, height: h)
            
            
            /// 自动居中显示
            let offsetX = cx - scrollView.bounds.width/2.0
            let maxOffsetX = scrollView.contentSize.width - scrollView.bounds.width
            let minOffsetX: CGFloat = 0
            var targetOffsetX = offsetX
            targetOffsetX = max(minOffsetX, min(targetOffsetX, maxOffsetX))
            scrollView.contentOffset = CGPoint(x: targetOffsetX, y: 0)
        }
    }
    
    public func pageDraggingEnd(atIndex: Int) {
        guard (0..<itemTitleArr.count).contains(atIndex) else {
            assertionFailure("HTMenuTitleView [pageDraggingEnd] atIndex 不匹配!!! atIndex=\(atIndex), count=\(itemTitleArr.count)")
            return
        }
        
        pageIsDragging = false
        
        if atIndex != currentIndex {
            itemViewArray[currentIndex].isSelect = false
            itemViewArray[atIndex].isSelect = true
            currentIndex = atIndex
        }
        
        /// 移动横线
        if let line = lineView {
            let showLineW = itemTextWidthArray[atIndex]
            let itemView = itemViewArray[atIndex]
            line.frame = CGRect(x: (itemView.frame.midX - showLineW/2.0), 
                                y: line.frame.minY, 
                                width: showLineW, 
                                height: line.frame.height)
        }
        
        /// 居中显示
        let frame = itemViewArray[atIndex].frame
        let centerX = frame.midX - scrollView.bounds.width / 2
        let maxOffsetX = scrollView.contentSize.width - scrollView.bounds.width
        let minOffsetX: CGFloat = 0
        var targetOffsetX = centerX
        targetOffsetX = max(minOffsetX, min(targetOffsetX, maxOffsetX))
        scrollView.contentOffset = CGPoint(x: targetOffsetX, y: 0)
    }
    
    
    private func setupUI() {
        backgroundColor = .clear
        
        addSubview(scrollView)
        scrollView.snp.makeConstraints { make in
            make.left.right.bottom.equalToSuperview()
            make.top.equalToSuperview()
        }
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(tapAction(_ :)))
        itemContentView.addGestureRecognizer(tap)
        itemContentView.clipsToBounds = true
        scrollView.addSubview(itemContentView)
        itemContentView.snp.makeConstraints { make in
            make.edges.equalTo(scrollView)
            make.height.equalTo(scrollView)
            make.width.equalTo(0)
        }
        
        itemContentView.addSubview(leftView)
        leftView.snp.makeConstraints { make in
            make.left.top.bottom.equalToSuperview()
            make.width.equalTo(config.leftViewW)
        }
        
        itemContentView.addSubview(rightView)
        rightView.snp.makeConstraints { make in
            make.right.top.bottom.equalToSuperview()
            make.width.equalTo(config.rightViewW)
        }
        
        if config.showLine {
            lineView = UIView()
            lineView!.backgroundColor = config.lineColor
            lineView!.frame = CGRect(x: 0, y: 0, width: 0, height: config.lineHeight)
            itemContentView.addSubview(lineView!)
        }
    }
    
    private func updateUI() {
        guard bounds.height > 0 else { return }
        
        let showH = scrollView.frame.height
        let showW = scrollView.frame.width
        
        /// 清除数据
        leftView.subviews.forEach { $0.removeFromSuperview() }
        rightView.subviews.forEach { $0.removeFromSuperview() }
        
        itemViewArray.forEach { $0.removeFromSuperview() }
        itemViewArray.removeAll()
        itemTextWidthArray.removeAll()
        
        scrollView.contentOffset = .zero
        
        /// 刷新左右View的UI
        dataSource?.menuPagesTitleViewConfigLeftRightView(titleView: self, leftView: leftView, rightView: rightView)
        
        if itemTitleArr.isEmpty {
            let contentW = config.ifThinAtCenter ? showW : (config.leftViewW+config.rightViewW)
            itemContentView.snp.updateConstraints { make in
                make.width.equalTo(contentW)
            }
            if let line = lineView {
                line.frame = CGRect(x: 0, 
                                    y: scrollView.bounds.height - config.lineHeight - config.lineBottomMargin, 
                                    width: 0, 
                                    height: line.frame.height)
            }
            return
        }
        
        var itemX: CGFloat = config.leftViewW
        let itemH: CGFloat = scrollView.frame.height
        for (index, text) in itemTitleArr.enumerated() {
            
            let textW1 = calculateTextSize(text: text, font: config.normalFont).width
            let textW2 = calculateTextSize(text: text, font: config.selectFont).width
            let textW = max(textW1, textW2)
            itemTextWidthArray.append(textW)
            
            let itemW = textW + config.spacing
            let itemV = HTMenuPagesTitleItemView(frame: CGRect(x: itemX, y: 0, width: itemW, height: itemH), 
                                                 nColor: config.normalColor, 
                                                 nFont: config.normalFont, 
                                                 sColor: config.selectColor, 
                                                 sFont: config.selectFont)
            itemV.index = index
            itemV.label.text = text
            itemContentView.addSubview(itemV)
            itemViewArray.append(itemV)
            
            itemX += itemW
            
            if index == currentIndex {
                itemV.isSelect = true
            }
        }
        
        
        itemX += config.rightViewW
        if config.ifThinAtCenter && itemX < showW {
            itemX = showW
            let itemW = (showW - config.leftViewW - config.rightViewW) / CGFloat(itemTitleArr.count)
            var newX: CGFloat = config.leftViewW
            itemViewArray.forEach { itemView in
                itemView.frame = CGRect(x: newX, y: 0, width: itemW, height: showH)
                newX += itemW
            }
        }
        
        itemContentView.snp.updateConstraints { make in
            make.width.equalTo(itemX)
        }
        
        if let line = lineView {
            line.frame = CGRect(x: (itemViewArray[currentIndex].frame.midX - itemTextWidthArray[currentIndex]/2.0), 
                                y: scrollView.frame.height-config.lineHeight-config.lineBottomMargin, 
                                width: itemTextWidthArray[currentIndex], 
                                height: line.frame.height)  
        }
        
        scrollToCenter(index: currentIndex, animate: false)
    }
    
    private func calculateTextSize(text: String, font: UIFont) -> CGSize {
        let maxSize = CGSizeMake(CGFLOAT_MAX, font.lineHeight+5)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font
        ]
        let size = (text as NSString).boundingRect(with: maxSize, 
                                                   options: [.usesLineFragmentOrigin, .usesFontLeading], 
                                                   attributes: attributes, 
                                                   context: nil)
        return CGSize(width: ceil(size.width), height: ceil(size.height))
    }
    
    /// 标签点击事件
    @objc private func tapAction(_ sender: UITapGestureRecognizer) {
        guard itemViewArray.count > 0, pageIsDragging == false else { return }
        
        let locationP = sender.location(in: itemContentView)
        guard !leftView.frame.contains(locationP), !rightView.frame.contains(locationP) else { return }
        
        var tapIndex: Int = 0
        for (index, itemView) in itemViewArray.enumerated() {
            if itemView.frame.contains(locationP) {
                tapIndex = index
                break
            }
        }
        
        let itemView = itemViewArray[tapIndex]
        if tapIndex == currentIndex {
            if let handler = didClickItemAgainHanlder {
                handler(itemView)
            }
            return
        }
        
        /// 切换选中数据, 移动横线到选中数据
        changeSelectIndex(index: tapIndex)
        
        /// 告知外层切换选中数据
        if let handler = didChooseItemHandler {
            handler(itemView)
        }
    }
    
    private func changeSelectIndex(index: Int) {
        guard index != currentIndex else { return }
        
        itemViewArray[currentIndex].isSelect = false
        itemViewArray[index].isSelect = true
        currentIndex = index
        
        /// 移动横线
        if let line = lineView {
            let showLineW = itemTextWidthArray[index]
            let itemView = itemViewArray[index]
            UIView.animate(withDuration: 0.25, delay: 0.0, options: .curveEaseInOut) { 
                line.frame = CGRect(x: (itemView.frame.midX - showLineW/2.0), 
                                    y: line.frame.minY, 
                                    width: showLineW, 
                                    height: line.frame.height)
            }
        }
        
        scrollToCenter(index: index, animate: true)
    }
    
    private func scrollToCenter(index: Int, animate: Bool) {
        guard index >= 0, index < itemViewArray.count, scrollView.contentSize.width > scrollView.bounds.width else { return }
        
        let frame = itemViewArray[index].frame
        let centerX = frame.midX - scrollView.bounds.width / 2
        
        // 计算可滚动的范围
        let maxOffsetX = scrollView.contentSize.width - scrollView.bounds.width
        let minOffsetX: CGFloat = 0
        
        // 确保不会滚动过头
        var targetOffsetX = centerX
        targetOffsetX = max(minOffsetX, min(targetOffsetX, maxOffsetX))
        
        scrollView.setContentOffset(CGPoint(x: targetOffsetX, y: 0), animated: animate)
    }    
}

extension HTMenuPagesTitleView: UIScrollViewDelegate {
    
    public func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        isDragging = true
    }
    
    public func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate {
            isDragging = false
//            adjustToCenterItem()
        }
    }
    
    public func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        isDragging = false
//        adjustToCenterItem()
    }
    
    
//    private func adjustToCenterItem() {
//        guard let centerIndex = findCenterVisibleItem() else { return }
//        
//        if centerIndex == currentIndex {
//            scrollToCenter(index: centerIndex, animate: true)
//        }
//        else {
//            changeSelectIndex(index: centerIndex)
//        }
//    }
//    
//    private func findCenterVisibleItem() -> Int? {
//        let centerX = scrollView.contentOffset.x + scrollView.bounds.width / 2
//        for (index, itemView) in itemViewArray.enumerated() {
//            if itemView.frame.minX <= centerX && itemView.frame.maxX >= centerX {
//                return index
//            }
//        }
//        return nil
//    }
    
}





