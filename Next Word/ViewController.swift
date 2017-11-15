//
//  ViewController.swift
//  Next Word
//
//  Created by Ryan Jennings on 2017-10-01.
//  Copyright © 2017 Ryan Jennings. All rights reserved.
//

import UIKit
import SceneKit
import ARKit
import Vision

let NUM_TILES = 15

internal class GridNode: SKSpriteNode {
    var rows:Int!
    var cols:Int!
    var blockSize:CGFloat!
    
    convenience init?(blockSize:CGFloat,rows:Int,cols:Int) {
        guard let texture = GridNode.gridTexture(blockSize: blockSize,rows: rows, cols:cols) else {
            return nil
        }
        self.init(texture: texture, color:SKColor.clear, size: texture.size())
        self.anchorPoint = CGPoint(x: 0, y: 0)
        self.blockSize = blockSize
        self.rows = rows
        self.cols = cols
    }
    
    class func gridTexture(blockSize:CGFloat,rows:Int,cols:Int) -> SKTexture? {
        // Add 1 to the height and width to ensure the borders are within the sprite
        let size = CGSize(width: CGFloat(cols)*blockSize+1.0, height: CGFloat(rows)*blockSize+1.0)
        UIGraphicsBeginImageContext(size)
        
        guard let context = UIGraphicsGetCurrentContext() else {
            return nil
        }
        let bezierPath = UIBezierPath()
        let offset:CGFloat = 0.5
        // Draw vertical lines
        for i in 0...cols {
            let x = CGFloat(i)*blockSize + offset
            bezierPath.move(to: CGPoint(x: x, y: 0))
            bezierPath.addLine(to: CGPoint(x: x, y: size.height))
        }
        // Draw horizontal lines
        for i in 0...rows {
            let y = CGFloat(i)*blockSize + offset
            bezierPath.move(to: CGPoint(x: 0, y: y))
            bezierPath.addLine(to: CGPoint(x: size.width, y: y))
        }
        SKColor.blue.setStroke()
        bezierPath.lineWidth = 1.0
        bezierPath.stroke()
        context.addPath(bezierPath.cgPath)
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return SKTexture(image: image!)
    }
    
    func point(row:Int, col:Int) -> CGPoint {
        let offset = blockSize / 2.0 + 0.5
        let x = max(0, CGFloat(col) * blockSize - (blockSize * CGFloat(cols)) / 2.0) + offset
        let y = max(0, CGFloat(rows - row - 1) * blockSize - (blockSize * CGFloat(rows)) / 2.0) + offset
        return CGPoint(x:x, y:y)
    }
}

internal class OverlayScene : SKScene {
    
    static let numTiles = 15
    var grid: GridNode
    
    override init(size: CGSize) {
        
        let tileSize = min(size.width,size.height)/CGFloat(OverlayScene.numTiles)-1.0
        
        guard let node = GridNode(blockSize: tileSize, rows: OverlayScene.numTiles, cols: OverlayScene.numTiles) else {
            fatalError("unable to create grid node")
        }
        
        self.grid = node;
        
        super.init(size: size)
        
        let xPos = CGFloat(15.0/2.0)
        
        if (size.height > size.width) {
            grid.position = CGPoint(x: xPos, y: (size.height/2)-(size.width/2))
        } else if (size.width > size.height) {
            grid.position = CGPoint(x: (size.width/2)-(size.height/2), y: xPos)
        }

        addChild(grid)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    var boundingBox: CGRect {
        get {
            let point = grid.point(row: 0, col: 0)
            return CGRect(origin: point, size: self.grid.size)
        }
    }
    
    func pointInGrid(point: CGPoint) -> Bool {
        return grid.frame.contains(point)
    }
    
    func parse(rect: CGRect) -> Bool {
        
        return false
    }
}

class ViewController: UIViewController, ARSCNViewDelegate, ARSessionDelegate {

    @IBOutlet weak var sessionInfoView: UIView!
    @IBOutlet weak var sessionInfoLabel: UILabel!
    @IBOutlet var sceneView: ARSCNView!
    @IBOutlet weak var previewImageView: UIImageView!
    
    fileprivate let inceptionv3model = Inceptionv3()
    fileprivate var squares: [CGRect] = []
    fileprivate var tiles: [CGRect: VNRectangleObservation] = [:]
    fileprivate var previewImage: CVPixelBuffer?
    fileprivate var sequenceRequestHandler: VNSequenceRequestHandler?
    fileprivate var capturedAnchors: [ARPlaneAnchor: SCNNode] = [:]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set the view's delegate
        self.sceneView.delegate = self
        self.sceneView.showsStatistics = true
        self.sceneView.antialiasingMode = .multisampling4X
        self.sceneView.autoenablesDefaultLighting = true
        self.sceneView.debugOptions = [ARSCNDebugOptions.showFeaturePoints, ARSCNDebugOptions.showWorldOrigin]
        
        self.sceneView.overlaySKScene = OverlayScene(size: self.view.frame.size)
        self.sequenceRequestHandler = VNSequenceRequestHandler()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        setupAR()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        sceneView.session.pause()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Release any cached data, images, etc that aren't in use.
    }
    
    override func willTransition(to newCollection: UITraitCollection,
                        with coordinator: UIViewControllerTransitionCoordinator) {
        super.willTransition(to: newCollection, with: coordinator)
        
        updateOverlay()
    }
    
    // MARK: - ARSCNViewDelegate
    
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        // Place content only for anchors found by plane detection.
        guard let planeAnchor = anchor as? ARPlaneAnchor else { return }
        
        // Create a SceneKit plane to visualize the plane anchor using its position and extent.
        let plane = SCNPlane(width: CGFloat(planeAnchor.extent.x), height: CGFloat(planeAnchor.extent.z))
        let planeNode = SCNNode(geometry: plane)
        planeNode.simdPosition = float3(planeAnchor.center.x, 0, planeAnchor.center.z)
        
        let greenMaterial = SCNMaterial()
        greenMaterial.diffuse.contents = UIColor.green
        greenMaterial.transparency = 0.5
        plane.materials = [greenMaterial]
        
        /*
         `SCNPlane` is vertically oriented in its local coordinate space, so
         rotate the plane to match the horizontal orientation of `ARPlaneAnchor`.
         */
        planeNode.eulerAngles.x = -.pi / 2
        
        /*
         Add the plane visualization to the ARKit-managed node so that it tracks
         changes in the plane anchor as plane estimation continues.
         */
        node.addChildNode(planeNode)
        
        print("Added node for: \(planeAnchor.identifier)")
        
        self.capturedAnchors[planeAnchor] = node
        
        identifyBoard()
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        guard let planeAnchor = anchor as?  ARPlaneAnchor,
            let planeNode = node.childNodes.first,
            let plane = planeNode.geometry as? SCNPlane
            else { return }
        
        // Plane estimation may shift the center of a plane relative to its anchor's transform.
        planeNode.simdPosition = float3(planeAnchor.center.x, 0, planeAnchor.center.z)
        
        /*
         Plane estimation may extend the size of the plane, or combine previously detected
         planes into a larger one. In the latter case, `ARSCNView` automatically deletes the
         corresponding node for one plane, then calls this method to update the size of
         the remaining plane.
         */
        plane.width = CGFloat(planeAnchor.extent.x)
        plane.height = CGFloat(planeAnchor.extent.z)
        
        if (self.capturedAnchors[planeAnchor] != node) {
            print("Updated node for: \(planeAnchor.identifier)")
        
            self.capturedAnchors[planeAnchor] = node
        
            identifyBoard()
        }
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didRemove node: SCNNode, for anchor: ARAnchor) {
        guard let planeAnchor = anchor as?  ARPlaneAnchor, let planeNode = node.childNodes.first
            else { return }
        
        planeNode.removeFromParentNode()
        
        print("Removed node for: \(planeAnchor.identifier)")
        
        self.capturedAnchors.removeValue(forKey: planeAnchor)
    }
    
    // MARK: - ARSessionDelegate
    
    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        
        updateSessionInfoLabel()

    }
    
    func session(_ session: ARSession, didRemove anchors: [ARAnchor]) {

        updateSessionInfoLabel()
    }
    
    func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
        updateSessionInfoLabel()
    }
    
    // MARK: - ARSessionObserver
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        // Present an error message to the user.
        updateSessionInfoLabel(for: "Session failed: \(error.localizedDescription)")
        setupAR()
    }
    
    func sessionWasInterrupted(_ session: ARSession) {

        // Inform the user that the session has been interrupted, for example, by presenting an overlay.
        updateSessionInfoLabel(for: "Session was interrupted")
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        // Reset tracking and/or remove existing anchors if consistent tracking is required.
        updateSessionInfoLabel(for: "Session interruption ended")
        setupAR()
    }
    
    // MARK: - Private methods
    
    // MARK: - UI Related
    
    private func updateOverlay() {
        self.sceneView.overlaySKScene = OverlayScene(size: CGSize(width: self.sceneView.frame.size.height, height: self.sceneView.frame.size.width))
    }
    
    private func updateSessionInfoLabel() {
        // Update the UI to provide feedback on the state of the AR experience.
        let message: String
        guard let frame = self.capturedFrame else { return }
        switch frame.camera.trackingState {
        case .normal where frame.anchors.isEmpty:
            // No planes detected; provide instructions for this app's AR interactions.
            message = "Move the device around to detect horizontal surfaces."
            
        case .normal:
            // No feedback needed when tracking is normal and planes are visible.
            message = ""
            
        case .notAvailable:
            message = "Tracking unavailable."
            
        case .limited(.excessiveMotion):
            message = "Tracking limited - Move the device more slowly."
            
        case .limited(.insufficientFeatures):
            message = "Tracking limited - Point the device at an area with visible surface detail, or improve lighting conditions."
            
        case .limited(.initializing):
            message = "Initializing AR session."
            
        }
        
        updateSessionInfoLabel(for: message)
    }
    
    private func updateSessionInfoLabel(for message: String) {
        sessionInfoLabel.text = message
        sessionInfoView.isHidden = message.isEmpty
    }
    
    private func setPreviewImage(image: CGImage?) {
        self.previewImageView.image = UIImage(cgImage: image!)
        self.previewImageView.isHidden = false
    }
    
    private var capturedFrame: ARFrame? {
        get {
            return self.sceneView?.session.currentFrame
        }
    }
    
    //    private var capturedImage: CVPixelBuffer? {
    //        get {
    //            return self.capturedFrame?.capturedImage
    //        }
    //    }
    
    private var overlay: OverlayScene? {
        get {
            return self.sceneView.overlaySKScene as? OverlayScene
        }
    }
    
    // MARK: - Configuration
    
    private func setupAR() {
        
        guard ARWorldTrackingConfiguration.isSupported else {
            fatalError("""
                ARKit is not available on this device. For apps that require ARKit
                for core functionality, use the `arkit` key in the key in the
                `UIRequiredDeviceCapabilities` section of the Info.plist to prevent
                the app from installing. (If the app can't be installed, this error
                can't be triggered in a production scenario.)
                In apps where AR is an additive feature, use `isSupported` to
                determine whether to show UI for launching AR experiences.
            """) // For details, see https://developer.apple.com/documentation/arkit
        }
        
        self.squares.removeAll()
        self.tiles.removeAll()
        self.capturedAnchors.removeAll()
        self.previewImage = nil
        
        DispatchQueue.main.async {
            self.previewImageView.isHidden = true
        }
        
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = .horizontal
        configuration.worldAlignment = .camera
        sceneView.session.delegate = self
        print("Setting up AR");
        sceneView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
    }
    
    /// only support back camera
    private var exifOrientationFromDeviceOrientation: Int32 {
        let exifOrientation: DeviceOrientation
        enum DeviceOrientation: Int32 {
            case top0ColLeft = 1
            case top0ColRight = 2
            case bottom0ColRight = 3
            case bottom0ColLeft = 4
            case left0ColTop = 5
            case right0ColTop = 6
            case right0ColBottom = 7
            case left0ColBottom = 8
        }
        switch UIDevice.current.orientation {
        case .portraitUpsideDown:
            exifOrientation = .left0ColBottom
        case .landscapeLeft:
            exifOrientation = .top0ColLeft
        case .landscapeRight:
            exifOrientation = .bottom0ColRight
        default:
            exifOrientation = .right0ColTop
        }
        return exifOrientation.rawValue
    }
    
    private func generateTileRegions() -> [CGRect] {
        
        var values: [CGRect] = []
        
        let xmod = 1 / CGFloat(NUM_TILES)
        let ymod = 1 / CGFloat(NUM_TILES)
        
        for i in 0..<NUM_TILES {
            let xpos = xmod * CGFloat(i)
            for j in 0..<NUM_TILES {
                let ypos = ymod * CGFloat(j)
                values.append(CGRect(x: xpos, y: ypos, width: xmod, height: ymod))
            }
        }
        
        
        //        let pointCloud = self.capturedFrame!.rawFeaturePoints
        //        let points = pointCloud!.points
        //
        //        for point in points {
        //
        //
        //        }
        
        return values
    }
    private func resetAnchors() {
        self.capturedAnchors.removeAll()
        //        for anchor in self.capturedFrame!.anchors {
        //            self.sceneView.session.remove(anchor: anchor)
        //        }
    }
    
    // MARK: - Board Identifying
    
    lazy var findBoardRequest: VNCoreMLRequest = {
        // Load the ML model through its generated class and create a Vision request for it.
        do {
            let model = try VNCoreMLModel(for: Inceptionv3().model)
            let request = VNCoreMLRequest(model: model, completionHandler: self.handleFindBoard)
            request.imageCropAndScaleOption = VNImageCropAndScaleOption.centerCrop
            return request
        } catch {
            fatalError("Can't load Vision ML model: \(error)")
        }
    }()
    
    private func handleFindBoard(request: VNRequest, error: Error?) {
        guard let observations = request.results else {
            print("Find scrabble board: no results:\(error!)")
            return
        }
    
        let classifications = observations[0...4]
            .flatMap({ $0 as? VNClassificationObservation })
            .filter({ $0.confidence > 0.2 })
        
        let message = classifications
            .map({ "\($0.identifier) \($0.confidence)" }).joined(separator: "\n")
        
        DispatchQueue.main.async {
            self.updateSessionInfoLabel(for: message)
        }
        
        if (self.isScrabble(classifications: classifications)) {
            self.parseScrabbleBoard()
        } else {
            print("Did not find scrabble board: \(message)")
        }
    }
    
    private func parseScrabbleBoard() {
        
        self.previewImage = self.capturedFrame!.capturedImage
        
        let hud = self.overlay!.boundingBox.scaleAndCrop(to: self.previewImage!.extent, fit: true)
        
        DispatchQueue.main.async {
            self.setPreviewImage(image: self.previewImage!.toCGImage(in: hud, orientation: UIImageOrientation.left))
        }
        
        self.squares = generateTileRegions()

        print("Finding squares in scrabble board")

        do {
            var requests = Array<VNImageBasedRequest>()
            
            for square in squares {
                requests.append(self.findSquaresRequest(subRect: square))
            }
            try sequenceRequestHandler!.perform(requests, on: self.previewImage!)
        } catch {
            print(error)
        }
    }
    
    private func isScrabble(classifications: Array<VNClassificationObservation>) -> Bool {
        if (classifications.count == 0) {
            return false
        }
        return classifications.first!.identifier.contains("crossword")
    }
    
    private func identifyBoard() {
     
//        var requestOptions:[VNImageOption : Any] = [:]
        
        
//        if let cameraIntrinsicData = CMGetAttachment(pixelBuffer, kCMSampleBufferAttachmentKey_CameraIntrinsicMatrix, nil) {
//            requestOptions = [.cameraIntrinsics:cameraIntrinsicData]
//        }
        
        //let hud = self.overlay!.boundingBox.scaleAndCrop(to: pixelBuffer.extent, fit: true)

        //self.capturedImage = pixelBuffer.toCGImage(rect: hud, for: UIImageOrientation.left)
//
//        let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation:
//                CGImagePropertyOrientation(rawValue: UInt32(self.exifOrientationFromDeviceOrientation))!, options: requestOptions)
        do {
            
            if self.squares.count == 0 {
                guard let frame = self.capturedFrame else { return }
                let pixelBuffer = frame.capturedImage;
                print("Finding scrabble board in image")
                try sequenceRequestHandler?.perform([self.findBoardRequest], on: pixelBuffer)
            } else  {
                
                let rect = self.squares.last
                
                if (self.tiles[rect!] == nil) {
                    print("Finding squares in scrabble board")
                    try sequenceRequestHandler?.perform([self.findSquaresRequest(subRect: rect!)], on: self.previewImage!)
                } else {
                    print("Tracking squares in scrabble board")
                    let subRect = self.tiles[rect!]
                    try sequenceRequestHandler?.perform([self.trackSquareRequest(rect: subRect!)], on: self.previewImage!)
                }
            }
        } catch {
            print(error)
        }
    }
    
    // MARK: - Alignment Identifying
    
    func findTranslationRequest() -> VNTranslationalImageRegistrationRequest {
        let request = VNTranslationalImageRegistrationRequest(targetedCGImage: self.overlay!.grid.texture!.cgImage(),
                                                              options: [:], completionHandler: self.handleAlignment)
        return request
    }
    
    func findHomographicRequest() -> VNHomographicImageRegistrationRequest {
        let request = VNHomographicImageRegistrationRequest(targetedCGImage: self.overlay!.grid.texture!.cgImage(),
            options: [:], completionHandler: self.handleAlignment)
        return request
    }
    
    private func handleAlignment(request: VNRequest, error: Error?) {
        guard let observations = request.results as? [VNImageAlignmentObservation]
            else { return }
        
        for (i, align) in observations.enumerated() {
            
            if align is VNImageHomographicAlignmentObservation {
                let homo = align as? VNImageHomographicAlignmentObservation
                
                print("Detected homographic alignment \(i): \(homo!.warpTransform)")
            } else if align is VNImageTranslationAlignmentObservation {
                let trans = align as? VNImageTranslationAlignmentObservation
                
                print("Detected translation alignment \(i): \(trans!.alignmentTransform)")
            }
        }
    }
    
    // MARK: - Square Identifying
    
    func findSquaresRequest(subRect: CGRect) -> VNDetectRectanglesRequest {
        let request = VNDetectRectanglesRequest(completionHandler: self.handleFindSquares)
        request.regionOfInterest = subRect
        return request
    }
    
    func trackSquareRequest(rect: VNRectangleObservation) -> VNTrackRectangleRequest {
        let request = VNTrackRectangleRequest(rectangleObservation: rect, completionHandler: self.handleTrackSquare)
        request.regionOfInterest = rect.boundingBox
        return request
    }
    
    private func handleFindSquares(request: VNRequest, error: Error?) {
    
        guard let observations = request.results as? [VNRectangleObservation]
            else { return }
        
//        if (observations.count == 0) {
//            let imageRequest = request as? VNImageBasedRequest
//            do {
//                try self.sequenceRequestHandler?.perform([self.findSquaresRequest(subRect: imageRequest!.regionOfInterest)], on: self.previewImage!)
//            } catch {
//                print(error)
//            }
//        }

        for (i, rect) in observations.enumerated() {
            
            print("Detected square \(i): \(rect.boundingBox)")
            
            do {
                try sequenceRequestHandler?.perform([self.trackSquareRequest(rect: rect)], on: self.previewImage!)
            } catch {
                print(error)
            }
        }
    }
    
    private func handleTrackSquare(request: VNRequest, error: Error?) {
        
        guard let observations = request.results as? [VNRectangleObservation]
            else { return }
        
        for (i, rect) in observations.enumerated() {
            
            let square = self.squares.last
//
//            if (square!.contains(rect.topLeft) && square!.contains(rect.bottomRight)) {
                print("Tracked square: \(i) \(rect.boundingBox)")
                self.tiles[square!] = rect
//            }
//            else {
//                print("Tracked square \(square!) not within rect \(rect)")
//            }
        }
    }
}

