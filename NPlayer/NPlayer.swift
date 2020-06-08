//
//  NPlayer.swift
//  NPlayer
//
//  Created by Neo on 2019/12/9.
//  Copyright © 2019 TaiHao. All rights reserved.
//

import Foundation
import AVFoundation

public protocol NPlayerDelegate: NSObjectProtocol {
    
    /// 播放结束
    ///
    /// - Parameter player: 当前播放器
    func playerDidPlayEnd(player: NPlayer)
    
    /// 播放失败
    ///
    /// - Parameters:
    ///   - player: 当前播放器
    ///   - failed: 失败原因
    func playerDidPlay(player: NPlayer, failed: Error?)
    
    /// 播放进度
    ///
    /// - Parameters:
    ///   - player: 当前播放器
    ///   - progress: 当前 playItem 进度
    func playerDidPlay(player: NPlayer, progress: Double)
    
    /// 当前缓冲进度
    ///
    /// - Parameters:
    ///   - player: 当前播放器
    ///   - progress: 当前缓冲进度
    func playerDidLoadTimeRange(player: NPlayer, progress: Double)
    
    /// 播放器当前缓冲状态
    /// - Parameters:
    ///   - player: 当前播放器
    ///   - status: 当前缓冲状态
    func playerBuffer(player: NPlayer, status: NPlayer.BufferState)
    
    /// 播放内容若为视频，则画面准备好的回调
    ///
    /// - Parameter player: 当前播放器
    func playerLayerCanDisplay(player: NPlayer)
    
    /// 监听进度的时间间隔
    func playerPeriodicTimescale() -> CMTime
    
}

extension NPlayerDelegate {
    public func playerPeriodicTimescale() -> CMTime {
        return CMTime(value: 1, timescale: 1)
    }
}

// MARK: - base
public class NPlayer: NSObject {
    
    @objc public enum PlayState: Int {
        case unknow
        case playing
        case pause
        case stop
        case failure
    }
    
    @objc public enum BufferState: Int {
        case loading
        case likelyToKeepUp
        case failure
    }
    
    /// 单例
    public static let shared = NPlayer()
        
    public weak var delegate: NPlayerDelegate?
    
    public var player: AVPlayer?
    
    public var state = PlayState.unknow
    
    /// 内容为视频时的画面显示容器
    public var playerView: NPlayerView?
    
    private var progressObserver: Any?
    
    public override init() {
        super.init()
        self.addPlayerNotifications()
    }
    
    private var currentItem: AVPlayerItem?
    
    deinit {
        self.destroy()
    }
    
    func destroy() {
        self.removeObserverStatus(fromPlayerItem: currentItem)
        self.removeObserverLoadedTimeRanges(fromPlayerItem: currentItem)
        self.removeObserverTimeControlStatus(forPlayer: player)
        self.removeObserverPlayerLayerDisplay(forPlayerLayer: playerView?.playerLayer)

        playerView = nil
        currentItem = nil
        
        self.removeProgressObserver()
    }
    
    /// 设置播放器资源
    public var asset: AVAsset? {
        
        willSet {
            self.destroy()
        }
        
        didSet {
            guard let asset = asset else {
                return
            }
            
            currentItem = AVPlayerItem(asset: asset)
            
            self.observerStatus(forPlayerItem: currentItem)
            self.observerLoadedTimeRanges(forPlayerItem: currentItem)
           
            // 重设currentItem
            player = AVPlayer(playerItem: currentItem)
            player?.replaceCurrentItem(with: currentItem)
            
            self.observerTimeControlStatus(forPlayer: player)

            // 监听播放进度
            let scale = delegate?.playerPeriodicTimescale() ?? CMTime(value: 1, timescale: 1)
            progressObserver = player?.addPeriodicTimeObserver(forInterval: scale , queue: DispatchQueue.main, using: { [weak self] (time) in
                
                let currentSeconds = CMTimeGetSeconds(time)
                guard let duration = self?.currentItem?.duration else {
                    return
                }
                
                let totalSeconds = CMTimeGetSeconds(duration)
                var progress: Double = 0
                if totalSeconds > 0 {
                    progress = currentSeconds/totalSeconds
                   
                }

                if let s = self {
                    s.delegate?.playerDidPlay(player: s, progress: progress)
                }
            })
            
            playerView = NPlayerView()
            playerView?.playerLayer.player = player
            self.observerPlayerLayerDisplay(forPlayerLayer: playerView?.playerLayer)
        }
    }
    
    private func removeProgressObserver() {
        if progressObserver == nil {
            return
        }
        player?.removeTimeObserver(progressObserver!)
        progressObserver = nil
    }
}

// MARK: - action
extension NPlayer {
    
    /// 播放
    public func play() {
        player?.play()
        state = .playing
    }
    
    /// 暂停
    public func pause() {
        player?.pause()
        state = .pause
    }
    
    /// 恢复播放
    public func resume() {
        player?.play()
        state = .playing
    }
    
    /// 停止播放 位置定位到从头开始
    public func stop() {
        player?.pause()
        self.seek(to: 0, completionHander: nil)
        state = .stop
    }
    
    /// 定位到当前多少秒
    /// - Parameters:
    ///   - to: 当前秒数
    ///   - completionHander: 完成回调
    /// - Returns: 若当前播放item处于非ready状态 返回false
    @discardableResult
    public func seek(to: Double, completionHander: ((Bool) -> ())?) -> Bool{
        let time =  CMTime(value: CMTimeValue(to) * 600, timescale: 600)
        let tolerance = CMTime.zero
        if currentItem?.status == AVPlayerItem.Status.readyToPlay {
            player?.seek(to: time, toleranceBefore: tolerance, toleranceAfter: tolerance, completionHandler: { (completion) in
                if let handler = completionHander {
                    handler(completion)
                }
            })
            return true
        }
        return false
    }
}

// MARK: - observer
extension NPlayer {
   
    override public func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        
        DispatchQueue.main.async {
            switch keyPath {
            case self.observerKeyPathStatus:
             
                if let current = self.currentItem {
                    self.handlePlayer(status: current.status)
                }
                
            case self.observerKeyPathLoadedTimeRanges:
                guard let ranges = change?[NSKeyValueChangeKey.newKey] as? Array<NSValue> else {
                    return
                }
                
                guard let range = ranges.first?.timeRangeValue else {
                    return
                }
                
                self.handlePlayer(LoadedTimeRange: range)
                
            case self.observerKeyPathTimeControlStatus:
                if let player = self.player {
                    self.handlePlayerBuffer(status: player.timeControlStatus)
                }
                
            case self.observerKeyPathPlayerLayerReadyForDisplay:
                if let isReadyForDisplay = self.playerView?.playerLayer.isReadyForDisplay {
                   self.handlePlayer(readyForDisplay: isReadyForDisplay)
                }
            default:
                let _ = 1
            }
        }
    }
    
    private func handlePlayer(status: AVPlayerItem.Status) {
        if status == .failed {
            delegate?.playerBuffer(player: self, status: .failure)
            state = .failure
            delegate?.playerDidPlay(player: self, failed: currentItem?.error)
        } else if status == .readyToPlay {
            delegate?.playerBuffer(player: self, status: .likelyToKeepUp)
        }
    }
    
    private func handlePlayer(LoadedTimeRange: CMTimeRange) {
        let startTime = CMTimeGetSeconds(LoadedTimeRange.start)
        let duration = CMTimeGetSeconds(LoadedTimeRange.duration)
        let total = startTime + duration
        
        guard let currentItemDuration = self.currentItem?.duration, CMTIME_IS_NUMERIC(currentItemDuration) else {
            return
        }
        
        let itemDuration = CMTimeGetSeconds(currentItemDuration)
        if itemDuration != 0 {
            let progress = total/itemDuration
            delegate?.playerDidLoadTimeRange(player: self, progress: progress)
        }
    }
    
    private func handlePlayerBuffer(status: AVPlayer.TimeControlStatus) {
        if status == .waitingToPlayAtSpecifiedRate {
            delegate?.playerBuffer(player: self, status: .loading)
        } else {
            delegate?.playerBuffer(player: self, status: .likelyToKeepUp)
        }
    }
    
    private func handlePlayer(readyForDisplay: Bool) {
        if readyForDisplay {
            delegate?.playerLayerCanDisplay(player: self)
        }
    }
    
    private var observerKeyPathStatus: String {
        return "status"
    }
    
    private var observerKeyPathLoadedTimeRanges: String {
        return "loadedTimeRanges"
    }
    
    private var observerKeyPathTimeControlStatus: String {
        return "timeControlStatus"
    }
    
    private var observerKeyPathPlayerLayerReadyForDisplay: String {
        return "readyForDisplay"
    }
    
    // status
    private func observerStatus(forPlayerItem: AVPlayerItem?) {
        forPlayerItem?.addObserver(self, forKeyPath: observerKeyPathStatus, options: [.old, .new], context: nil)
    }
    
    private func removeObserverStatus(fromPlayerItem: AVPlayerItem?) {
        fromPlayerItem?.removeObserver(self, forKeyPath: observerKeyPathStatus)
    }
    
    // time ranges
    private func observerLoadedTimeRanges(forPlayerItem: AVPlayerItem?) {
        forPlayerItem?.addObserver(self, forKeyPath: observerKeyPathLoadedTimeRanges, options: [.old, .new], context: nil)
    }
    
    private func removeObserverLoadedTimeRanges(fromPlayerItem: AVPlayerItem?) {
        fromPlayerItem?.removeObserver(self, forKeyPath: observerKeyPathLoadedTimeRanges)
    }
    
    // timeControlStatus
    private func observerTimeControlStatus(forPlayer: AVPlayer?) {
        forPlayer?.addObserver(self, forKeyPath: observerKeyPathTimeControlStatus, options: [.old, .new], context: nil)
    }
    
    private func removeObserverTimeControlStatus(forPlayer: AVPlayer?) {
        forPlayer?.removeObserver(self, forKeyPath: observerKeyPathTimeControlStatus)
    }
    
    // player layer display
    private func observerPlayerLayerDisplay(forPlayerLayer: AVPlayerLayer?) {
        forPlayerLayer?.addObserver(self, forKeyPath: observerKeyPathPlayerLayerReadyForDisplay, options: [.old, .new], context: nil)
    }
    
    private func removeObserverPlayerLayerDisplay(forPlayerLayer: AVPlayerLayer?) {
        forPlayerLayer?.removeObserver(self, forKeyPath: observerKeyPathPlayerLayerReadyForDisplay)
    }
    
}

// MARK: - notification
private extension NPlayer {
    
    func addPlayerNotifications() {
        NotificationCenter.default.addObserver(self, selector: #selector(playerDidPlayToEndTime(_:)), name: Notification.Name.AVPlayerItemDidPlayToEndTime, object: currentItem)
        
        NotificationCenter.default.addObserver(self, selector: #selector(playerFailedToPlayToEndTime(_:)), name: Notification.Name.AVPlayerItemFailedToPlayToEndTime, object: currentItem)
    }
    
    func removeNotifications() {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc func playerDidPlayToEndTime(_ notification: Notification) {
        if let item = notification.object as? AVPlayerItem, item == currentItem {
            state = .stop
            delegate?.playerDidPlayEnd(player: self)
        }
    }
    
    @objc func playerFailedToPlayToEndTime(_ notification: Notification) {
        if let item = notification.object as? AVPlayerItem, item == currentItem {
            delegate?.playerBuffer(player: self, status: .failure)
            
            state = .failure
            let reason = notification.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey]
            delegate?.playerDidPlay(player: self, failed: reason as? Error ?? nil)
        }
    }
}

