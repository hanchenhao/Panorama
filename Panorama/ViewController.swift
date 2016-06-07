//
//  ViewController.swift
//  Panorama
//
//  Created by 韩陈昊 on 16/6/7.
//  Copyright © 2016年 SunriseTribe. All rights reserved.
//


import UIKit
import GLKit

class ViewController: GLKViewController {
    
    var panoramaView: PanoramaView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        panoramaView = PanoramaView()
        // 图片大小必须为如下尺寸
        //4096×2048, 2048×1024, 1024×512, 512×256, 256×128 ...
        
        panoramaView.setImageWithName("pano.jpg")

        panoramaView.setOrientToDevice(true)
        panoramaView.setTouchToPan(false)
        panoramaView.setPinchToZoom(true)
        panoramaView._showTouches = false
        self.view = panoramaView
    }
    
    override func glkView(view: GLKView, drawInRect rect: CGRect) {
        panoramaView.draw()
    }
    
    override func prefersStatusBarHidden() -> Bool {
        return true
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    
}
