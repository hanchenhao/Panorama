//
//  PanoramaView.swift
//  Panorama
//
//  Created by 韩陈昊 on 16/6/7.
//  Copyright © 2016年 SunriseTribe. All rights reserved.
//

import Foundation
import CoreMotion
import GLKit
import OpenGLES

class PanoramaView: GLKView {
    
    private var FPS = 60
    private var FOV_MIN = 1 //最小放大倍数
    private var FOV_MAX = 155 //最大放大倍数
    private var Z_NEAR: Float = 0.1
    private var Z_FAR: Float = 100.0
    
    private var sphere: Sphere!
    private var meridians: Sphere!
    private var motionManager: CMMotionManager!
    private var pinchGesture: UIPinchGestureRecognizer!
    private var panGesture: UIPanGestureRecognizer!
    private var _projectionMatrix: GLKMatrix4!
    private var _attitudeMatrix: GLKMatrix4!
    private var _offsetMatrix: GLKMatrix4!
    private var _aspectRatio: Float!
    private var circlePoints = Array(count: 64 * 3, repeatedValue: GLfloat())
    
    private var _fieldOfView: Float!
    private var _numberOfTouches: Int!
    private var _touchToPan: Bool!
    private var _pinchToZoom: Bool!
    private var _orientToDevice: Bool!
    private var _lookVector: GLKVector3!
    private var _lookAzimuth: Float!
    private var _lookAltitude: Float!
    var _showTouches: Bool!
    private var _touches: Set<UITouch>!
    
    
    required init?(coder decoder: NSCoder){
        super.init(coder: decoder)
    }
    
    convenience init() {
        self.init(frame: UIScreen.mainScreen().bounds)
    }
    
    override convenience init(frame: CGRect) {
        let context = EAGLContext.init(API: EAGLRenderingAPI.OpenGLES1)
        EAGLContext.setCurrentContext(context)
        self.init(frame: frame, context: context)
        self.context = context
    }
    
    override init(frame: CGRect, context: EAGLContext) {
        super.init(frame: frame, context: context)
        self.context = context
        self.initDevice()
        self.initOpenGL(context)
        sphere = Sphere(stacks: 48, slices: 48, radius: 10.0, textureFile: nil)
        meridians = Sphere(stacks: 48, slices: 48, radius: 8.0, textureFile: "equirectangular-projection-lines.png")
    }
    
    override func didMoveToSuperview() {
        // this breaks MVC, but useful for setting GLKViewController's frame rate
        var responder: UIResponder = self
        while (responder as? GLKViewController) == nil {
            if let resp = responder.nextResponder() {
                responder = resp
            } else {
                break
            }
        }
        if let resp = responder as? GLKViewController {
            resp.preferredFramesPerSecond = FPS
        }
    }
    
    //初始化硬件
    func initDevice() {
        motionManager = CMMotionManager()
        pinchGesture = UIPinchGestureRecognizer(target: self, action: #selector(PanoramaView.pinchHandler))
        pinchGesture.enabled = false
        self.addGestureRecognizer(pinchGesture)
        panGesture = UIPanGestureRecognizer(target: self, action: #selector(PanoramaView.panHandler))
        panGesture.maximumNumberOfTouches = 1
        panGesture.enabled = false
        self.addGestureRecognizer(panGesture)
    }
    
    //设置可视范围
    func setFieldOfView(fieldOfView: Float){
        _fieldOfView = fieldOfView
        rebuildProjectionMatrix()
    }
    
    func setImageWithName(fileName: String){
        sphere.swapTexture(fileName)
    }
    
    func setImage(image: UIImage){
        sphere.swapTextureWithImage(image)
    }
    
    func setTouchToPan(touchToPan: Bool){
        _touchToPan = touchToPan
        panGesture.enabled = _touchToPan
    }
    
    func setPinchToZoom(pinchToZoom: Bool){
        _pinchToZoom = pinchToZoom
        pinchGesture.enabled = _pinchToZoom
    }
    
    func setOrientToDevice(orientToDevice: Bool){
        _orientToDevice = orientToDevice
        if(motionManager.deviceMotionAvailable){
            if orientToDevice {
                motionManager.startDeviceMotionUpdates()
            } else {
                motionManager.stopDeviceMotionUpdates()
            }
        }
    }
    
    // MARK: - OPENGL
    func initOpenGL(context: EAGLContext) {
        if let layer = self.layer as? CAEAGLLayer {
            layer.opaque = false
        }
        _aspectRatio = Float(self.frame.size.width / self.frame.size.height)
        _fieldOfView = 45 + 45 * atanf(_aspectRatio) // hell ya
        rebuildProjectionMatrix()
        _attitudeMatrix = GLKMatrix4Identity
        _offsetMatrix = GLKMatrix4Identity
        customGL()
        makeLatitudeLines()
    }
    
    func rebuildProjectionMatrix() {
        glMatrixMode(UInt32(GL_PROJECTION))
        glLoadIdentity()
        let frustum = Z_NEAR * tanf(_fieldOfView * 0.00872664625997)
        _projectionMatrix = GLKMatrix4MakeFrustum(-frustum, frustum, -frustum / _aspectRatio, frustum / _aspectRatio, Z_NEAR, Z_FAR)
        glMultMatrixf(UnsafePointer<GLfloat>([_projectionMatrix.m]))
        glViewport(0, 0, Int32(self.frame.size.width), Int32(self.frame.size.height))
        glMatrixMode(UInt32(GL_MODELVIEW))
    }
    
    func customGL() {
        glMatrixMode(UInt32(GL_MODELVIEW))
        //    glEnable(GL_CULL_FACE);
        //    glCullFace(GL_FRONT);
        //    glEnable(GL_DEPTH_TEST);
        glEnable(UInt32(GL_BLEND))
        glBlendFunc(UInt32(GL_SRC_ALPHA), UInt32(GL_ONE_MINUS_SRC_ALPHA))
    }
    
    let whiteColor: [GLfloat] = [1.0, 1.0, 1.0, 1.0]
    let clearColor: [GLfloat] = [0.0, 0.0, 0.0, 0.0]
    func draw() {
        glClearColor(0.0, 0.0, 0.0, 0.0)
        glClear(UInt32(GL_COLOR_BUFFER_BIT))
        glPushMatrix() // begin device orientation
        
        let deviceOrientationMatrix = getDeviceOrientationMatrix()
        _attitudeMatrix = GLKMatrix4Multiply(deviceOrientationMatrix, _offsetMatrix)
        updateLook()
        
        glMultMatrixf(UnsafePointer<GLfloat>([_attitudeMatrix.m]))
        
        glMaterialfv(UInt32(GL_FRONT_AND_BACK), UInt32(GL_EMISSION), whiteColor);  // panorama at full color
        sphere.execute()
        glMaterialfv(UInt32(GL_FRONT_AND_BACK), UInt32(GL_EMISSION), clearColor);
        //        [meridians execute];  // semi-transparent texture overlay (15° meridian lines)
        //TODO: add any objects here to make them a part of the virtual reality
        //        glPushMatrix();
        //        // object code
        //        glPopMatrix();
        
        // touch lines
        if(_showTouches == true && _numberOfTouches != nil){
            glColor4f(1.0, 1.0, 1.0, 0.5)
            for touch in _touches {
                glPushMatrix()
                let touchPoint = touch.locationInView(self)
                drawHotspotLines(vectorFromScreenLocation(touchPoint, inAttitude: _attitudeMatrix))
                glPopMatrix()
            }
            glColor4f(1.0, 1.0, 1.0, 1.0)
        }
        glPopMatrix() // end device orientation
    }
    
    // MARK: -  ORIENTATION
    func getDeviceOrientationMatrix() -> GLKMatrix4{
        if _orientToDevice == true && motionManager.deviceMotionActive {
            if let a = motionManager.deviceMotion?.attitude.rotationMatrix{
                // arrangements of mappings of sensor axis to virtual axis (columns)
                // and combinations of 90 degree rotations (rows)
                switch UIApplication.sharedApplication().statusBarOrientation {
                case .LandscapeRight:
                    return GLKMatrix4Make(Float(a.m21), Float(-a.m11), Float(a.m31), 0.0,
                                          Float(a.m23), Float(-a.m13), Float(a.m33), 0.0,
                                          Float(-a.m22), Float(a.m12), Float(-a.m32), 0.0,
                                          0.0 , 0.0 , 0.0 , 1.0)
                case .LandscapeLeft:
                    return GLKMatrix4Make(Float(-a.m21), Float(a.m11), Float(a.m31), 0.0,
                                          Float(-a.m23), Float(a.m13), Float(a.m33), 0.0,
                                          Float(a.m22), Float(-a.m12), Float(-a.m32), 0.0,
                                          0.0 , 0.0 , 0.0 , 1.0)
                case .PortraitUpsideDown:
                    
                    return GLKMatrix4Make(Float(-a.m11), Float(-a.m21), Float(a.m31), 0.0,
                                          Float(-a.m13), Float(-a.m23), Float(a.m33), 0.0,
                                          Float(a.m12), Float(a.m22), Float(-a.m32), 0.0,
                                          0.0 , 0.0 , 0.0 , 1.0)
                default:
                    return GLKMatrix4Make(Float(a.m11), Float(a.m21), Float(a.m31), 0.0,
                                          Float(a.m13), Float(a.m23), Float(a.m33), 0.0,
                                          Float(-a.m12), Float(-a.m22), Float(-a.m32), 0.0,
                                          0.0 , 0.0 , 0.0 , 1.0)
                }
            }
        }
        return GLKMatrix4Identity
    }
    
    func orientToVector(v: GLKVector3) {
        _attitudeMatrix = GLKMatrix4MakeLookAt(0, 0, 0, v.x, v.y, v.z,  0, 1, 0)
        updateLook()
    }
    
    func orientToAzimuth(azimuth: Float, Altitude altitude:Float) {
        orientToVector(GLKVector3Make(-cosf(azimuth), sinf(altitude), sinf(azimuth)))
    }
    
    func updateLook(){
        _lookVector = GLKVector3Make(-_attitudeMatrix.m02,
                                     -_attitudeMatrix.m12,
                                     -_attitudeMatrix.m22)
        _lookAzimuth = atan2f(_lookVector.x, -_lookVector.z)
        _lookAltitude = asinf(_lookVector.y)
    }
    
    func imagePixelAtScreenLocation(point: CGPoint) -> CGPoint{
        return imagePixelFromVector(vectorFromScreenLocation(point, inAttitude: _attitudeMatrix))
    }
    
    func imagePixelFromVector(vector: GLKVector3) -> CGPoint {
        var pxl = CGPointMake(CGFloat((Float(M_PI) - atan2f(-vector.z, -vector.x)) / (2 * Float(M_PI))),
                              CGFloat(acosf(vector.y) / Float(M_PI)))
        let tex = sphere.getTextureSize()
        // if no texture exists, returns between 0.0 - 1.0
        if(!(tex.x == 0.0 && tex.y == 0.0)){
            pxl.x *= tex.x
            pxl.y *= tex.y
        }
        return pxl
    }
    
    func vectorFromScreenLocation(point: CGPoint) -> GLKVector3 {
        return vectorFromScreenLocation(point, inAttitude: _attitudeMatrix)
    }
    
    func vectorFromScreenLocation(point: CGPoint, inAttitude matrix: GLKMatrix4) -> GLKVector3 {
        let inverse = GLKMatrix4Invert(GLKMatrix4Multiply(_projectionMatrix, matrix), nil)
        let screen = GLKVector4Make(2.0 * (Float(point.x / self.frame.size.width) - 0.5),
                                    2.0 * (0.5 - Float(point.y / self.frame.size.height)),
                                    1.0, 1.0)
        //if (SENSOR_ORIENTATION == 3 || SENSOR_ORIENTATION == 4)
        //        screen = GLKVector4Make(2.0*(screenTouch.x/self.frame.size.height-.5),
        //                                2.0*(.5-screenTouch.y/self.frame.size.width),
        //                                1.0, 1.0);
        let vec = GLKMatrix4MultiplyVector4(inverse, screen)
        return GLKVector3Normalize(GLKVector3Make(vec.x, vec.y, vec.z))
        
    }
    
    func screenLocationFromVector(vector: GLKVector3) -> CGPoint {
        let matrix = GLKMatrix4Multiply(_projectionMatrix, _attitudeMatrix)
        let screenVector = GLKMatrix4MultiplyVector3(matrix, vector)
        return CGPointMake(CGFloat(screenVector.x / screenVector.z / 2.0 + 0.5) * self.frame.size.width,
                           CGFloat(0.5 - screenVector.y / screenVector.z / 2) * self.frame.size.height)
    }
    
    //    func computeScreenLocation(location: CGPoint!, fromVector vector: GLKVector3, inAttitude matrix: GLKMatrix4) -> Bool{
    //        //This method returns whether the point is before or behind the screen.
    //        if(location == nil){
    //            return false
    //        }
    //        let matrix = GLKMatrix4Multiply(_projectionMatrix, matrix);
    //        let vector4 = GLKVector4Make(vector.x, vector.y, vector.z, 1);
    //        let screenVector = GLKMatrix4MultiplyVector4(matrix, vector4);
    //        location.x = (screenVector.x/screenVector.w/2.0 + 0.5) * self.frame.size.width;
    //        location.y = (0.5-screenVector.y/screenVector.w/2) * self.frame.size.height;
    //        return (screenVector.z >= 0);
    //    }
    
    // MARK: -  TOUCHES
    override func touchesBegan(touches: Set<UITouch>, withEvent event: UIEvent?) {
        if let allTouches = event?.allTouches() {
            _touches = allTouches
            _numberOfTouches = allTouches.count
        }
    }
    
    override func touchesMoved(touches: Set<UITouch>, withEvent event: UIEvent?) {
        if let allTouches = event?.allTouches() {
            _touches = allTouches
            _numberOfTouches = allTouches.count
        }
    }
    
    override func touchesEnded(touches: Set<UITouch>, withEvent event: UIEvent?) {
        if let allTouches = event?.allTouches() {
            _touches = allTouches
            _numberOfTouches = 0
        }
    }
    
    func touchInRect(rect: CGRect) -> Bool {
        if(_numberOfTouches != nil){
            var found = false
            for touch in _touches {
                let touchPoint = touch.locationInView(self)
                found = found || CGRectContainsPoint(rect, imagePixelAtScreenLocation(touchPoint))
            }
            return found
        }
        return false
    }
    
    var zoom: Float = 0
    func pinchHandler(sender: UIPinchGestureRecognizer){
        _numberOfTouches = sender.numberOfTouches()
        if sender.state == UIGestureRecognizerState.Began {
            zoom = _fieldOfView
        }
        if sender.state == UIGestureRecognizerState.Changed {
            var newFOV = zoom / Float(sender.scale)
            if(newFOV < Float(FOV_MIN)) {
                newFOV = Float(FOV_MIN)
            } else if(newFOV > Float(FOV_MAX)){
                newFOV = Float(FOV_MAX)
            }
            setFieldOfView(newFOV)
        }
        if sender.state == UIGestureRecognizerState.Ended {
            _numberOfTouches = 0
        }
    }
    
    var touchVector: GLKVector3!
    func panHandler(sender: UIPinchGestureRecognizer){
        if sender.state == UIGestureRecognizerState.Began {
            touchVector = vectorFromScreenLocation(sender.locationInView(sender.view), inAttitude: _offsetMatrix)
        } else if sender.state == UIGestureRecognizerState.Changed {
            let nowVector = vectorFromScreenLocation(sender.locationInView(sender.view), inAttitude: _offsetMatrix)
            let q = GLKQuaternionFromTwoVectors(touchVector, v: nowVector)
            _offsetMatrix = GLKMatrix4Multiply(_offsetMatrix, GLKMatrix4MakeWithQuaternion(q))
            // in progress for preventHeadTilt
            //        GLKMatrix4 mat = GLKMatrix4Multiply(_offsetMatrix, GLKMatrix4MakeWithQuaternion(q));
            //        _offsetMatrix = GLKMatrix4MakeLookAt(0, 0, 0, -mat.m02, -mat.m12, -mat.m22,  0, 1, 0);
        } else {
            _numberOfTouches = 0
        }
    }
    
    // MARK: -  MERIDIANS
    func makeLatitudeLines() {
        for i in 0 ..< 64 {
            circlePoints[i * 3 + 0] = -sinf(Float(M_PI) * 2 / 64.0 * Float(i))
            circlePoints[i * 3 + 1] = 0.0
            circlePoints[i * 3 + 2] = cosf(Float(M_PI) * 2 / 64.0 * Float(i))
        }
    }
    
    func drawHotspotLines(touchLocation: GLKVector3) {
        glLineWidth(2.0)
        let scale = sqrtf(1 - powf(touchLocation.y, 2))
        glPushMatrix()
        glScalef(scale, 1.0, scale)
        glTranslatef(0, touchLocation.y, 0)
        glDisableClientState(UInt32(GL_NORMAL_ARRAY))
        glEnableClientState(UInt32(GL_VERTEX_ARRAY))
        glVertexPointer(3, UInt32(GL_FLOAT), 0, circlePoints)
        glDrawArrays(UInt32(GL_LINE_LOOP), 0, 64)
        glDisableClientState(UInt32(GL_VERTEX_ARRAY))
        glPopMatrix()
        
        glPushMatrix()
        glRotatef(-atan2f(-touchLocation.z, -touchLocation.x) * 180 / Float(M_PI), 0, 1, 0);
        glRotatef(90, 1, 0, 0);
        glDisableClientState(UInt32(GL_NORMAL_ARRAY))
        glEnableClientState(UInt32(GL_VERTEX_ARRAY))
        glVertexPointer(3, UInt32(GL_FLOAT), 0, circlePoints)
        glDrawArrays(UInt32(GL_LINE_STRIP), 0, 33)
        glDisableClientState(UInt32(GL_VERTEX_ARRAY))
        glPopMatrix()
    }
    
    deinit{
        EAGLContext.setCurrentContext(nil)
    }
    
    // this really should be included in GLKit
    func GLKQuaternionFromTwoVectors(u: GLKVector3, v: GLKVector3) -> GLKQuaternion{
        let w = GLKVector3CrossProduct(u, v)
        let q = GLKQuaternionMake(w.x, w.y, w.z, GLKVector3DotProduct(u, v))
        let qw = q.w + GLKQuaternionLength(q)
        return GLKQuaternionNormalize(GLKQuaternionMake(q.x, q.y, q.z, qw))
    }
    
}
