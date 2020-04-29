//
//  NPlayerView.swift
//  NPlayer
//
//  Created by Neo on 2019/12/9.
//  Copyright © 2019 TaiHao. All rights reserved.
//

import UIKit
import AVFoundation

public class NPlayerView: UIView {
    override public class var layerClass: AnyClass {
        get {
            return AVPlayerLayer.self
        }
    }
    
    public var playerLayer: AVPlayerLayer {
        get {
            let avLayer = self.layer as! AVPlayerLayer
            if UIDevice.current.userInterfaceIdiom == .pad {
                avLayer.videoGravity = .resizeAspect
            } else {
                avLayer.videoGravity = .resizeAspectFill
            }
            return avLayer
        }
    }
}
