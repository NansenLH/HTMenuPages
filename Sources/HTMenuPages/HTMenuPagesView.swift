//
//  HTMenuPagesView.swift
//
//  Created by Nansen on 2025/6/20.
//

import Foundation
import UIKit


public protocol HTMenuPagesViewDataSource: AnyObject {
    /// 一共显示多少个页面. 如果配置了 HTMenuPagesTitleView, 数据会从 HTMenuPagesTitleView 中获取, 不会调用此方法
    func menuPagesShowNumbers(pagesView: HTMenuPagesView) -> Int
    
    /// 加载第 index 个页面
    func menuPagesShowView(pagesView: HTMenuPagesView, index: Int) -> UIViewController & HTMenuPagesViewDelegate
}

public protocol HTMenuPagesViewDelegate: AnyObject {
    /// 页面加载最新数据的方法. 首次加载页面必定会执行此方法
    func menuPagesLoadData(pageIndex: Int, onScreen: Bool)
    
    /// 当前页,用户再次点击标题. 可以执行操作:判断是否在最上面, 如果在最上面, 应该刷新数据, 不在最上面, 显示最上面的数据
    func menuPagesClickTitle(pageIndex: Int)
    
    /// 页面即将显示(首次直接加载的页面不会执行此方法, 滑动后加载的页面会执行此方法)
    func menuPagesWillShow(pageIndex: Int)
    
    /// 移出屏幕外
    func menuPagesDidOffScreen(pageIndex: Int)
}

/// 加载模式
public enum HTMenuPagesViewLoadMode {
    /// 只加载当前
    case current
    
    /// 加载所有
    case all
    
    /// 加载当前的和相邻的前后两个
    case near
}

public class HTMenuPagesView: UIView {
    
    public var loadMode: HTMenuPagesViewLoadMode = .current
    
    public var pageIndex: Int = 0
    
    weak var titleView: HTMenuPagesTitleView?
    
    weak var dataSource: HTMenuPagesViewDataSource?
    
    private var pageCount: Int = 0
    
    private var pages: [HTMenuPageItemView] = []
    
    private lazy var scrollView: HTMenuScrollView = {
        let view = HTMenuScrollView()
        view.isPagingEnabled = true
        view.showsVerticalScrollIndicator = false
        view.showsHorizontalScrollIndicator = false
        view.bounces = false
        view.delegate = self
        return view
    }()
    
    let scrollContentView: UIView = {
        let v = UIView() 
        return v
    }()
    
    public init(mode: HTMenuPagesViewLoadMode = .current, titleMenu: HTMenuPagesTitleView, dataSource: HTMenuPagesViewDataSource) {
        self.loadMode = mode
        self.titleView = titleMenu
        self.dataSource = dataSource
        super.init(frame: .zero)
        createUI()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        createUI()
    }
    
    /// 加载数据(老数据全部失效, 所有 vc 全部重新生成)
    public func loadData() {
        guard let delegate = dataSource else { return }
        
        pages.forEach { itemView in
            itemView.clear()
            itemView.removeFromSuperview()
        }
        pages.removeAll()
        
        if let titleView = titleView {
            titleView.loadData()
            pageCount = titleView.totalCount
            pageIndex = titleView.currentIndex
        }
        else {
            pageCount = delegate.menuPagesShowNumbers(pagesView: self)    
            if pageIndex >= pageCount {
                pageIndex = 0
            }
        }
        
        updateWidth()
        
        scrollView.contentOffset = CGPoint(x: CGFloat(pageIndex)*scrollView.bounds.width, y: 0)
        
        if pageCount == 0 { return }
        
        var preView: UIView? = nil
        for index in 0..<pageCount {
            let itemView = HTMenuPageItemView()
            itemView.index = index
            scrollContentView.addSubview(itemView)
            if let pre = preView {
                itemView.snp.makeConstraints { make in
                    make.left.equalTo(pre.snp.right)
                    make.top.bottom.equalToSuperview()
                    make.width.equalTo(scrollView.snp.width)
                }
            }
            else {
                itemView.snp.makeConstraints { make in
                    make.left.equalTo(0)
                    make.top.bottom.equalToSuperview()
                    make.width.equalTo(scrollView.snp.width)
                }
            }
            pages.append(itemView)
            
            preView = itemView
        }
        
        switch loadMode {
            case .current:
                loadNewPage(atIndex: pageIndex, onScreen: true)
            case .all:
                /// 加载所有页面
                for index in 0..<pageCount {
                    loadNewPage(atIndex: index, onScreen: index==pageIndex)
                }
            case .near:
                loadNewPage(atIndex: pageIndex, onScreen: true)
                if pageIndex-1 >= 0 {
                    loadNewPage(atIndex: pageIndex-1, onScreen: false)
                }
                if pageIndex+1 < pageCount {
                    loadNewPage(atIndex: pageIndex+1, onScreen: false)
                }
        }
    }
    
    /// 加载指定页面, 已有数据也销毁重新加载
    func loadNewPage(atIndex: Int, onScreen: Bool) {
        guard let delegate = dataSource, pageCount > 0 else { return }
        
        guard atIndex >= 0 && atIndex < pageCount else {
            assertionFailure("HTMenuPagesView [loadNewPage(atIndex:)] 越界!!! index=\(atIndex), pageCount=\(pageCount)")
            return
        }
        
        /// 加载指定页面的 vc
        let itemView = pages[atIndex]
        itemView.clear()
        
        let vc = delegate.menuPagesShowView(pagesView: self, index: atIndex)
        itemView.viewController = vc
        vc.menuPagesLoadData(pageIndex: atIndex, onScreen: onScreen)
    }
    
    /// 展示指定页面, 如果没有数据就加载, 有数据什么也不做
    func showPage(atIndex: Int, onScreen: Bool) {
        guard let delegate = dataSource else { return }
        guard atIndex >= 0 && atIndex < pages.count else {
            assertionFailure("HTMenuPagesView [showPage(atIndex:)] 越界!!! index=\(atIndex), pageCount=\(pageCount)")
            return
        }
        
        let itemView = pages[atIndex]
        if let vc = itemView.viewController {
            if onScreen {
                vc.menuPagesWillShow(pageIndex: atIndex)
            }
        }
        else {
            let vc = delegate.menuPagesShowView(pagesView: self, index: atIndex)
            itemView.viewController = vc
            vc.menuPagesLoadData(pageIndex: atIndex, onScreen: onScreen)
        }
    }
    func scrollDidDisapperPage(atIndex: Int) {
        pages[atIndex].viewController?.menuPagesDidOffScreen(pageIndex: atIndex)
    }
    
    private func draggingEnd() {
        isDragging = false
        
        dragDirect = .none
        scrollView.isUserInteractionEnabled = true
        
        let endIndex = lround(scrollView.contentOffset.x / scrollView.frame.width)
        if endIndex != pageIndex {
            scrollDidDisapperPage(atIndex: pageIndex)
            pageIndex = endIndex
            
            if let titleV = titleView {
                titleV.pageDraggingEnd(atIndex: pageIndex)
            }
            
            if loadMode == .near {
                if endIndex-1 >= 0 {
                    showPage(atIndex: endIndex-1, onScreen: false)    
                }
                if endIndex+1 < pageCount {
                    showPage(atIndex: endIndex+1, onScreen: false)
                }
            }
        }
        
    }
    
    /// 重新加载页面(原页面销毁)
    public func reloadPage(atIndex: Int, onScreen: Bool) {
        guard let delegate = dataSource, pageCount > 0 else { return }
        
        guard atIndex >= 0 && atIndex < pageCount else {
            assertionFailure("HTMenuPagesView [reloadPage(atIndex:)] 越界!!! index=\(atIndex), pageCount=\(pageCount)")
            return
        }
        
        let itemView = pages[atIndex]
        itemView.clear()
        let vc = delegate.menuPagesShowView(pagesView: self, index: atIndex)
        itemView.viewController = vc
        vc.menuPagesLoadData(pageIndex: atIndex, onScreen: onScreen)
    }
    
    
    private func createUI() {
        backgroundColor = .clear
        
        addSubview(scrollView)
        scrollView.snp.makeConstraints { make in
            make.left.right.top.bottom.equalToSuperview()
        }
        
        scrollView.addSubview(scrollContentView)
        scrollContentView.snp.makeConstraints { make in
            make.edges.equalTo(scrollView)
            make.height.equalTo(scrollView)
            make.width.equalTo(0)
        }
        
        createEmptyView()
        
        if let titleView = titleView {
            titleView.didChooseItemHandler = { [weak self] titleItemView in
                guard let ws = self else { return }
                ws.titleViewClickItem(index: titleItemView.index)
            }
            
            titleView.didClickItemAgainHanlder = { [weak self] titleItemView in
                guard let ws = self else { return }
                ws.titleViewClickItemAgain(index: titleItemView.index)
            }
        }
    }
    
    /// 切换页面, 不使用动画, 直接设置
    private func titleViewClickItem(index: Int) {
        guard index >= 0, index < pageCount else {
            assertionFailure("HTMenuPagesView [titleViewChoosedItem:] 越界!!! titleIndex=\(index), pageCount=\(pageCount)")
            return
        }
        
        showPage(atIndex: index, onScreen: true)
        
        scrollView.contentOffset = CGPoint(x: CGFloat(index)*scrollView.bounds.width, y: 0)
        scrollDidDisapperPage(atIndex: pageIndex)
        
        pageIndex = index
        if loadMode == .near {
            if index-1 >= 0 {
                showPage(atIndex: index-1, onScreen: false)    
            }
            if index+1 < pageCount {
                showPage(atIndex: index+1, onScreen: false)
            }
        }
    } 
    /// 再次点击标题
    private func titleViewClickItemAgain(index: Int) {
        guard index == pageIndex else {
            assertionFailure("HTMenuPagesView [titleViewClickItemAgain:] index不一致!!! titleIndex=\(index), pageIndex=\(pageIndex)")
            return
        }
        guard let vc = pages[index].viewController else {
            assertionFailure("HTMenuPagesView [titleViewClickItemAgain:] 未加载VC titleIndex=\(index)")
            return
        }
        
        vc.menuPagesClickTitle(pageIndex: index)
    }
    
    
    public let emptyLabel: UILabel = {
        let emptyLabel = UILabel()
        emptyLabel.text = "暂无数据"
        emptyLabel.textColor = UIColor(red: 138.0/255.0, green: 138.0/255.0, blue: 138.0/255.0, alpha: 1.0)
        emptyLabel.font = .systemFont(ofSize: 14)
        emptyLabel.textAlignment = .center
        return emptyLabel
    }()
    private func createEmptyView() {
        scrollContentView.addSubview(emptyLabel)
        emptyLabel.snp.makeConstraints { make in
            make.left.equalToSuperview()
            make.width.equalTo(scrollView.snp.width)
            make.centerY.equalToSuperview()
        }
    }
    
    public override func layoutSubviews() {
        super.layoutSubviews()
        updateWidth()
    }
    
    private func updateWidth() {
        var showW = bounds.width
        guard showW > 0 else { return }
        
        if pageCount > 0 {
            showW = bounds.width * CGFloat(pageCount)
        }
        scrollContentView.snp.updateConstraints { make in
            make.width.equalTo(showW)
        }
    }
    
    private var isDragging: Bool = false
    
    private var dragDirect: HTDragDirection = .none
    
    private var dragStartX: CGFloat = 0
    
    private enum HTDragDirection: Int {
        case none = 0
        case left = 1
        case right = 2
    }
}

extension HTMenuPagesView: UIScrollViewDelegate {
    
    /// 手势滚动
    public func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        dragStartX = scrollView.contentOffset.x
        isDragging = true
    }
    
    /// 手势将要松开
    public func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
        scrollView.isUserInteractionEnabled = false
    }
    
    /// 手势结束了
    public func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate {
            draggingEnd()
        }
    }
    
    /// 完全停止滚动
    public func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        draggingEnd()
    }
    
//    /// 代码滚动结束
//    public func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
//
//    }
    
    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard isDragging else { return }
        
        let diff = scrollView.contentOffset.x - dragStartX
        
        if let titleV = titleView {
            let p = abs(diff/scrollView.bounds.width)
            if diff < 0, pageIndex > 0 {
                titleV.pageDragging(fromIndex: pageIndex, toIndex: pageIndex-1, percent: p)    
            }
            else if diff == 0 {
                titleV.pageDragging(fromIndex: pageIndex, toIndex: pageIndex, percent: 0)
            }
            else if diff > 0, pageIndex < pageCount-1 {
                titleV.pageDragging(fromIndex: pageIndex, toIndex: pageIndex+1, percent: p)
            }
        }
        
        
        if diff == 0 {
            dragDirect = .none
        }
        else if diff < 0 && dragDirect != .left {
            dragDirect = .left
            if pageIndex > 0 {
                showPage(atIndex: (pageIndex-1), onScreen: true)
            }
        }
        else if diff > 0 && dragDirect != .right {
            dragDirect = .right
            if pageIndex < (pageCount-1) {
                showPage(atIndex: (pageIndex+1), onScreen: true)
            }
        }
    }
}


class HTMenuPageItemView: UIView {
    
    var index: Int = 0
    
    var viewController: (UIViewController & HTMenuPagesViewDelegate)? {
        didSet {
            oldValue?.view.removeFromSuperview()
            
            if let vc = viewController {
                addSubview(vc.view)
                vc.view.snp.makeConstraints { make in
                    make.edges.equalToSuperview()
                }
            }
        }
    }
    
    deinit {
        clear()
    }
    
    func clear() {
        viewController?.view.removeFromSuperview()
        viewController = nil
    }
}
