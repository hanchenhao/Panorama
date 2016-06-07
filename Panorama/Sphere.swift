//
//  Sphere.swift
//  Panorama
//
//  Created by 韩陈昊 on 16/6/7.
//  Copyright © 2016年 SunriseTribe. All rights reserved.
//

import Foundation
import GLKit
import OpenGLES

class Sphere: NSObject {
    
    var m_TextureInfo: GLKTextureInfo?
    var m_TexCoordsData: Array<GLfloat>!
    var m_VertexData: Array<GLfloat>!
    var m_NormalData: Array<GLfloat>!
    var m_Stacks: GLint!
    var m_Slices: GLint!
    var m_Scale: GLfloat!
    
    init(stacks: GLint, slices: GLint, radius: GLfloat, textureFile: String?) {
        super.init()
        if(textureFile != nil){
            m_TextureInfo = self.loadTextureFromBundle(textureFile)
        }
        m_Scale = radius
        m_Stacks = stacks
        m_Slices = slices
        m_VertexData = Array(count: 3 * Int((m_Slices * 2 + 2) * m_Stacks), repeatedValue: GLfloat())
        m_NormalData = Array(count: 3 * Int((m_Slices * 2 + 2) * m_Stacks), repeatedValue: GLfloat())
        m_TexCoordsData = Array(count: 2 * Int((m_Slices * 2 + 2) * m_Stacks), repeatedValue: GLfloat())
        // Latitude
        var total1 = 0
        var total2 = 0
        for phiIdx in 0 ..< m_Stacks {
            //starts at -pi/2 goes to pi/2
            //the first circle M_PI = 3.14159265358979
            let pi = 3.141593
            let phi0 = double(pi * (Double(phiIdx) / Double(m_Stacks) - 0.5))
            //second one
            let phi1 = double(pi * (Double(phiIdx + 1) / Double(m_Stacks) - 0.5))
            
            let cosPhi0 = double(cos(phi0))
            let sinPhi0 = double(sin(phi0))
            let cosPhi1 = double(cos(phi1))
            let sinPhi1 = double(sin(phi1))
            
            //longitude
            for thetaIdx in 0 ..< m_Slices {
                let theta = double(-2.0 * pi * (Double(thetaIdx) * (1.0 / Double(m_Slices - 1))))
                let cosTheta = double(cos(theta + pi * 0.5))
                let sinTheta = double(sin(theta + pi * 0.5))
                //get x-y-x of the first vertex of stack
                m_VertexData[total1 + 0] = float(Double(m_Scale) * cosPhi0 * cosTheta)
                m_VertexData[total1 + 1] = float(Double(m_Scale) * sinPhi0)
                m_VertexData[total1 + 2] = float(Double(m_Scale) * cosPhi0 * sinTheta)
                //the same but for the vertex immediately above the previous one.
                m_VertexData[total1 + 3] = float(Double(m_Scale) * cosPhi1 * cosTheta)
                m_VertexData[total1 + 4] = float(Double(m_Scale) * sinPhi1)
                m_VertexData[total1 + 5] = float(Double(m_Scale) * cosPhi1 * sinTheta)
                
                m_NormalData[total1 + 0] = float(cosPhi0 * cosTheta)
                m_NormalData[total1 + 1] = float(sinPhi0)
                m_NormalData[total1 + 2] = float(cosPhi0 * sinTheta)
                m_NormalData[total1 + 3] = float(cosPhi1 * cosTheta)
                m_NormalData[total1 + 4] = float(sinPhi1)
                m_NormalData[total1 + 5] = float(cosPhi1 * sinTheta)
                
                let texX = float(Double(thetaIdx) / Double(m_Slices - 1))
                m_TexCoordsData[total2 + 0] = 1.0 - texX
                m_TexCoordsData[total2 + 1] = float(Double(phiIdx + 0) / Double(m_Stacks))
                m_TexCoordsData[total2 + 2] = 1.0 - texX
                m_TexCoordsData[total2 + 3] = float(Double(phiIdx + 1) / Double(m_Stacks))
                total1 += 2 * 3
                total2 += 2 * 2
            }
            //Degenerate triangle to connect stacks and maintain winding order
            m_VertexData[total1 + 0] = m_VertexData[total1 - 3]
            m_VertexData[total1 + 1] = m_VertexData[total1 - 2]
            m_VertexData[total1 + 2] = m_VertexData[total1 - 1]
            m_VertexData[total1 + 3] = m_VertexData[total1 - 3]
            m_VertexData[total1 + 4] = m_VertexData[total1 - 2]
            m_VertexData[total1 + 5] = m_VertexData[total1 - 1]
            
            m_NormalData[total1 + 0] = m_NormalData[total1 - 3]
            m_NormalData[total1 + 1] = m_NormalData[total1 - 2]
            m_NormalData[total1 + 2] = m_NormalData[total1 - 1]
            m_NormalData[total1 + 3] = m_NormalData[total1 - 3]
            m_NormalData[total1 + 4] = m_NormalData[total1 - 2]
            m_NormalData[total1 + 5] = m_NormalData[total1 - 1]
            
            m_TexCoordsData[total2 + 0] = m_TexCoordsData[total2 - 2]
            m_TexCoordsData[total2 + 1] = m_TexCoordsData[total2 - 1]
            m_TexCoordsData[total2 + 2] = m_TexCoordsData[total2 - 2]
            m_TexCoordsData[total2 + 3] = m_TexCoordsData[total2 - 1]
        }
    }
    
    deinit{
        if var name = m_TextureInfo?.name {
            glDeleteTextures(1, &name)
        }
    }
    
    func double(db: Double) -> Double {
        if let t = Double(String(format: "%.6lf", db)) {
            return t
        }
        return db
    }
    
    func float(db: Double) -> Float {
        if let t = Float(String(format: "%.6lf", db)) {
            return t
        }
        return Float(db)
    }
    
    func execute() -> Bool {
        glEnableClientState(UInt32(GL_NORMAL_ARRAY))
        glEnableClientState(UInt32(GL_VERTEX_ARRAY))
        if(m_TexCoordsData != nil){
            glEnable(UInt32(GL_TEXTURE_2D))
            glEnableClientState(UInt32(GL_TEXTURE_COORD_ARRAY))
            if let name = m_TextureInfo?.name {
                glBindTexture(UInt32(GL_TEXTURE_2D), name)
            }
            glTexCoordPointer(2, UInt32(GL_FLOAT), 0, m_TexCoordsData);
        }
        glVertexPointer(3, UInt32(GL_FLOAT), 0, m_VertexData)
        glNormalPointer(UInt32(GL_FLOAT), 0, m_NormalData)
        glDrawArrays(UInt32(GL_TRIANGLE_STRIP), 0, (m_Slices + 1) * 2 * (m_Stacks - 1) + 2)
        glDisableClientState(UInt32(GL_TEXTURE_COORD_ARRAY))
        glDisable(UInt32(GL_TEXTURE_2D))
        glDisableClientState(UInt32(GL_VERTEX_ARRAY))
        glDisableClientState(UInt32(GL_NORMAL_ARRAY))
        return true
    }
    
    func loadTextureFromBundle(filename: String?) -> GLKTextureInfo? {
        if let path = NSBundle.mainBundle().pathForResource(filename, ofType: nil){
            return loadTextureFromPath(path)
        }
        return nil
    }
    
    func loadTextureFromPath(path: String) -> GLKTextureInfo? {
        do {
            let number: NSNumber = true
            let info = try GLKTextureLoader.textureWithContentsOfFile(path, options: [GLKTextureLoaderOriginBottomLeft : number])
            glBindTexture(UInt32(GL_TEXTURE_2D), info.name)
            glTexParameteri(UInt32(GL_TEXTURE_2D), UInt32(GL_TEXTURE_WRAP_S), GL_REPEAT)
            glTexParameteri(UInt32(GL_TEXTURE_2D), UInt32(GL_TEXTURE_WRAP_T), GL_REPEAT)
            glTexParameteri(UInt32(GL_TEXTURE_2D), UInt32(GL_TEXTURE_MAG_FILTER), GL_LINEAR)
            glTexParameteri(UInt32(GL_TEXTURE_2D), UInt32(GL_TEXTURE_MIN_FILTER), GL_LINEAR)
            return info
        } catch let error as NSError {
            print("失败", error.localizedDescription)
            return nil
        }
    }
    
    func loadTextureFromImage(image: UIImage) -> GLKTextureInfo? {
        if image.CGImage == nil {
            return nil
        }
        do {
            let number: NSNumber = true
            let info = try GLKTextureLoader.textureWithCGImage(image.CGImage!, options: [GLKTextureLoaderOriginBottomLeft : number])
            glBindTexture(UInt32(GL_TEXTURE_2D), info.name)
            glTexParameteri(UInt32(GL_TEXTURE_2D), UInt32(GL_TEXTURE_WRAP_S), GL_REPEAT)
            glTexParameteri(UInt32(GL_TEXTURE_2D), UInt32(GL_TEXTURE_WRAP_T), GL_REPEAT)
            glTexParameteri(UInt32(GL_TEXTURE_2D), UInt32(GL_TEXTURE_MAG_FILTER), GL_LINEAR)
            glTexParameteri(UInt32(GL_TEXTURE_2D), UInt32(GL_TEXTURE_MIN_FILTER), GL_LINEAR)
            return info
        } catch let error as NSError {
            print("失败", error.localizedDescription)
            return nil
        }
    }
    
    func swapTexture(textureFile: String){
        if var name = m_TextureInfo?.name {
            glDeleteTextures(1, &name)
        }
        if NSFileManager.defaultManager().fileExistsAtPath(textureFile) {
            m_TextureInfo = loadTextureFromPath(textureFile)
        } else {
            m_TextureInfo = loadTextureFromBundle(textureFile)
        }
    }
    
    func swapTextureWithImage(image: UIImage) {
        if var name = m_TextureInfo?.name {
            glDeleteTextures(1, &name)
        }
        m_TextureInfo = loadTextureFromImage(image)
    }
    
    func getTextureSize() -> CGPoint {
        if let textureInfo = m_TextureInfo {
            return CGPointMake(CGFloat(textureInfo.width), CGFloat(textureInfo.height))
        } else {
            return CGPointZero
        }
    }
}