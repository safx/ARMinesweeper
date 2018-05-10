//
//  ViewController.swift
//  ARMine
//
//  Created by safx on 2017/08/25.
//  Copyright © 2017 safx. All rights reserved.
//

import UIKit
import SceneKit
import ARKit


class ViewController: UIViewController, ARSCNViewDelegate {
    
    let cellWidth: Float = 0.5
    
    var debugMessage: String = ""
    
    @IBOutlet var sceneView: ARSCNView!
    @IBOutlet weak var debugLabel: UILabel!
    var gameFieldCenter: SCNVector3?
    var gameFieldCenterPole: SCNNode?
    var gameFieldNode: SCNNode?
    var gameCells: [SCNNode:(Int, Int)] = [:]
    var userStayingCell: SCNNode? = nil
    var userStayingStartTime: TimeInterval = 0
    var userLocation:(Int, Int) = (-1, -1)
    var cursorPlane: SCNNode?
    
    var gameField: GameField? = nil
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set the view's delegate
        sceneView.delegate = self
        
        // Show statistics such as fps and timing information
        sceneView.showsStatistics = true
        sceneView.debugOptions = [ARSCNDebugOptions.showWorldOrigin]
        
        // Create a new scene
        //let scene = SCNScene(named: "art.scnassets/ship.scn")!
        let scene = SCNScene()
        
        // Set the scene to the view
        sceneView.scene = scene
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Create a session configuration if null
        let configuration = sceneView.session.configuration ??
            ViewController.newConfiguration()
        
        // Run the view's session
        sceneView.session.run(configuration)
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
    
    private class func newConfiguration() -> ARWorldTrackingConfiguration {
        //let config = ARWorldTrackingSessionConfiguration()
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = .horizontal
        return config
    }
    
    // MARK: - ARSCNViewDelegate
    
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time:
        TimeInterval) {
        guard let currentFrame = sceneView.session.currentFrame else { return }
        
        let count = currentFrame.anchors.count
        let plane = ground
        
        // TODO: limit async range
        DispatchQueue.main.async {
            //self.debugLabel.text = ViewController.format(matrix: currentFrame.camera.transform)
            let vec = ViewController.format(vector: currentFrame.camera.transform.columns.3)
            let planeColumn3 = plane.map { p in ViewController.format(vector: p.transform.columns.3) } ?? ""
            let planeCenter = plane.map { p in ViewController.format(vector3: p.center) } ?? ""
            let planeExtent = plane.map { p in ViewController.format(vector3: p.extent) } ?? ""
            //self.debugLabel.text = "\(self.debugMessage)\n\(vec)\n\(count)\ncolumn3: \(planeColumn3)\ncenter: \(planeCenter)\nextent: \(planeExtent)"
            self.debugLabel.text = "\(self.userLocation)\n\(vec)\n\(count)\ncolumn3: \(planeColumn3)\ncenter: \(planeCenter)\nextent: \(planeExtent)"
            
            let cameraPos = currentFrame.camera.transform.columns.3

            if let nearest = self.nearestCellAt(x: cameraPos.x, y: cameraPos.z) {
                if self.userStayingCell != nearest {
                    self.userStayingCell = nearest
                    self.userStayingStartTime = time
                }
                
                if self.cursorPlane == nil {
                    self.cursorPlane = self.createCursor()
                    
                }
                //self.cursorPlane?.removeFromParentNode()
                //nearest.addChildNode(self.cursorPlane!)
                let cursorPos = SCNVector3(nearest.position.x, nearest.position.y - 0.01, nearest.position.z)
                self.cursorPlane?.runAction(SCNAction.move(to: cursorPos, duration: 0.2))


                let node = self.cursorPlane!
                node.runAction(SCNAction.moveBy(x: 0.5, y: 0, z: 0, duration: 0.2))

                
                if time - self.userStayingStartTime > 3.0 {
                    // open this cell
                    self.cursorPlane?.opacity = 0.8
                    self.userLocation = self.gameCells[nearest]!
                    
                    if let pos = self.gameCells[nearest], let gf = self.gameField {
                        if gf.openAt(pos.0, pos.1) {
                            let s = gf.cellStateAt(pos.0, pos.1)
                            let textNode = self.createNumber(number: s.rawValue)
                            nearest.addChildNode(textNode)
                        } else {
                            self.showBomb(cell: nearest)
                        }
                    }
                } else {
                    self.cursorPlane?.opacity = 0.4
                }
            } else {
                self.userStayingCell = nil
                self.userStayingStartTime = 0
                self.userLocation = (-1, -1)
                if let c = self.cursorPlane {
                    c.removeFromParentNode()
                }
            }
        }
    }
    
    private var ground: ARPlaneAnchor? {
        guard let currentFrame = sceneView.session.currentFrame else { return nil }
        return ViewController.selectLargestPlane(planes: currentFrame.anchors)
    }

    private func nearestCellAt(x: Float, y: Float) -> SCNNode? {
        var node: SCNNode? = nil
        var distance = Float.infinity
        gameCells.forEach { (n, _) in
            let loc = n.simdTransform.columns.3
            let d = (loc.x - x) * (loc.x - x) + (loc.z - y) * (loc.z - y)
            if d < distance {
                distance = d
                node = n
                print(ViewController.format(vector: loc))
            }
        }
        let acceptableDistance: Float = cellWidth * cellWidth * 2
        return distance < acceptableDistance ? node : nil
    }
    

    private class func selectLargestPlane(planes: [ARAnchor]) -> ARPlaneAnchor? {
        var largestPlane: ARPlaneAnchor? = nil
        planes.forEach { p in
            guard let plane = p as? ARPlaneAnchor else { return }
            guard let lp = largestPlane else {
                largestPlane = plane
                return
            }
            let l = lp.extent
            let p = plane.extent
            if l.x * l.z < p.x * p.z {
                largestPlane = plane
            }
        }
        return largestPlane
    }
    
    private class func format(matrix m: matrix_float4x4) -> String {
        let a = format(vector: m.columns.0)
        let b = format(vector: m.columns.1)
        let c = format(vector: m.columns.2)
        let d = format(vector: m.columns.3)
        return "\(a)\n\(b)\n\(c)\n\(d)"
    }
    
    private class func format(vector3 c: vector_float3) -> String {
        let x = String(format: "%+.2f", c.x)
        let y = String(format: "%+.2f", c.y)
        let z = String(format: "%+.2f", c.z)
        return "\(x) \(y) \(z)"
    }
    
    private class func format(vector c: simd_float4) -> String {
        let x = String(format: "%+.2f", c.x)
        let y = String(format: "%+.2f", c.y)
        let z = String(format: "%+.2f", c.z)
        let w = String(format: "%+.2f", c.w)
        return "\(x) \(y) \(z) \(w)"
    }
    
    /*func session(_ session: ARSession, didRemove anchors: [ARAnchor]) {
     }*/
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        // Present an error message to the user
        
    }
    
    func sessionWasInterrupted(_ session: ARSession) {
        // Inform the user that the session has been interrupted, for example, by presenting an overlay
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        // Reset tracking and/or remove existing anchors if consistent tracking is required
    }
    
    @IBAction func startButtonClicked(_ sender: UIButton) {
        //guard let ground = ground else { return }
        //let g = ground.transform.columns.3
        
        guard let gameFieldNode = gameFieldNode else { return }
        let center = gameFieldNode.simdPosition
        let scale = gameFieldNode.simdScale

        let light = SCNLight()
        light.type = .ambient
        light.color = UIColor(white: 0.5, alpha: 1.0)
        let lightNode = SCNNode()
        lightNode.light = light
        sceneView.scene.rootNode.addChildNode(lightNode)
        
        
        let light2 = SCNLight()
        light2.type = .omni
        light2.color = UIColor(white: 0.5, alpha: 1.0)
        let lightNode2 = SCNNode()
        lightNode2.light = light2
        lightNode2.position = SCNVector3(center.x, center.y + 1, center.z)
        sceneView.scene.rootNode.addChildNode(lightNode2)
        
        let xstep = Int(scale.x / cellWidth)
        let zstep = Int(scale.y / cellWidth)
        
        gameField = GameField(width: xstep, height: zstep)
        gameField?.resetField()
        gameField?.placeBombs(count: 2)
        
        for z in 0..<zstep {
            for x in 0..<xstep {
                let w = CGFloat(cellWidth - 0.05)
                let planeGeom = SCNPlane(width: w, height: w)
                planeGeom.cornerRadius = 0.02
                planeGeom.firstMaterial!.diffuse.contents =
                    UIColor.init(red: 1.0, green: 0, blue: 0, alpha: 0.6)
                planeGeom.firstMaterial!.specular.contents = UIColor.white
                let planeNode = SCNNode(geometry: planeGeom)
                planeNode.simdTransform = gameFieldNode.simdTransform
                    .scale(1 / scale.x, 1 / scale.y, 1 / scale.z) // reset scale
                    .translate(-scale.x / 2 + cellWidth / 2 + cellWidth * Float(x), -scale.y / 2 + cellWidth / 2 + cellWidth * Float(z), 0.01)
                sceneView.scene.rootNode.addChildNode(planeNode)
                
                gameCells[planeNode] = (x, z)
            }
        }
        gameFieldNode.removeFromParentNode()
        gameFieldCenterPole?.removeFromParentNode()
    }
    
    // touch events
    
    func hitTest(_ point: CGPoint) -> ARHitTestResult? {
        guard let ground = self.ground else { return nil }
        
        let results = sceneView.hitTest(point, types: .estimatedHorizontalPlane)

        //let s = results.map { ViewController.format(vector: $0.worldTransform.columns.3) } .joined(separator: "\n")
        //debugMessage = "\(s)"
        
        if let result = (results.first { $0.anchor == ground }) {
            return result
        }
        
        if let result = (results.first { fabs($0.worldTransform.columns.3.y - ground.transform.columns.3.y) < 0.05 }) {
            return result
        }
        return nil
    }
    
    @IBAction func handleTapGesture(_ tap: UITapGestureRecognizer) {
        let point = tap.location(in: sceneView)
        
        if gameField != nil { // in Game Mode
            let results = sceneView.hitTest(point, options: [SCNHitTestOption.sortResults: true,  SCNHitTestOption.rootNode: sceneView.scene.rootNode])
            if let first = results.first {
                if let pos = gameCells[first.node], let gf = gameField {
                    if !gf.isOpenedAt(pos.0, pos.1) {
                        toggleFlag(cell: first.node)
                    }
                }
            }
        } else {
            guard let result = hitTest(point) else { return }
            guard let ground = ground else { return }

            let pos = result.worldTransform.columns.3
            print(ViewController.format(vector: pos))
            
            if let post = gameFieldCenterPole, let field = gameFieldNode {
                post.removeFromParentNode()
                field.removeFromParentNode()
            }
            let g = ground.transform.columns.3
            
            gameFieldCenter = SCNVector3(pos.x, 0, pos.z)
            gameFieldCenterPole = addPoleToScene(position: gameFieldCenter!, color: .green)
            gameFieldNode = addPlaneToScene(center: SCNVector3(pos.x, g.y, pos.z))
        }
    }
    
    @IBAction func handleRotatationGesture(_ rotate:
        UIRotationGestureRecognizer) {
        guard let field = gameFieldNode else { return }
        field.simdEulerAngles.y -= Float(rotate.rotation) / 180 * 5
    }
    
    @IBAction func handlePinchGesture(_ pinch: UIPinchGestureRecognizer) {
        guard pinch.numberOfTouches >= 2 else { return }
        guard let field = gameFieldNode else { return }
        
        let s = (Float(pinch.scale) - 1.0) * 0.01
        
        let a = pinch.location(ofTouch: 0, in: sceneView)
        let b = pinch.location(ofTouch: 1, in: sceneView)
        
        if fabs(a.x - b.x) > fabs(a.y - b.y) {
            if field.simdScale.x + s > 1.0 {
                field.simdScale.x += s
            }
        } else {
            if field.simdScale.y + s > 1.0 {
                field.simdScale.y += s
            }
        }
    }
    
    @IBAction func handlePanGesture(_ pan: UIPanGestureRecognizer) {
        guard pan.numberOfTouches == 1 else { return }
        guard let field = gameFieldNode else { return }
        if pan.state != .began {
            let t = pan.translation(in: sceneView)
            field.simdPosition.x += Float(t.x) * 0.01
            field.simdPosition.z += Float(t.y) * 0.01
        }
        pan.setTranslation(CGPoint(x: 0, y: 0), in: sceneView)
    }

    private func addPoleToScene(position: SCNVector3, color: UIColor) -> SCNNode {
        let geom = SCNBox(width: 0.01, height: 2, length: 0.01, chamferRadius: 0)
        geom.firstMaterial!.diffuse.contents = color
        geom.firstMaterial!.specular.contents = UIColor.white
        let node = SCNNode(geometry: geom)
        node.position = position
        sceneView.scene.rootNode.addChildNode(node)
        return node
    }
    
    private func addPlaneToScene(center position: SCNVector3) -> SCNNode {
        let geom = SCNPlane(width: 1, height: 1)
        geom.cornerRadius = 0.02
        geom.firstMaterial!.diffuse.contents = UIColor.init(red: 0, green: 0.4, blue: 0, alpha: 0.4)
        geom.firstMaterial!.specular.contents = UIColor.white
        let node = SCNNode(geometry: geom)
        node.eulerAngles = SCNVector3(-Float.pi / 2, 0, 0)
        node.position = position
        sceneView.scene.rootNode.addChildNode(node)
        return node
    }

    private func createCursor() -> SCNNode {
        let geom = SCNPlane(width: CGFloat(cellWidth + 0.02), height: CGFloat(cellWidth + 0.02))
        geom.cornerRadius = 0.02
        geom.firstMaterial!.diffuse.contents = UIColor.init(red: 0, green: 0.4, blue: 1, alpha: 1)
        geom.firstMaterial!.specular.contents = UIColor.white
        let node = SCNNode(geometry: geom)
        node.eulerAngles = SCNVector3(-Float.pi / 2, 0, 0)
        //node.position = SCNVector3(0, 0, -0.01)
        sceneView.scene.rootNode.addChildNode(node)
        return node
    }

    private func toggleFlag(cell: SCNNode) {
        if cell.childNodes.count > 0 {
            cell.childNodes.forEach { $0.removeFromParentNode() }
        } else {
            let geom = SCNText(string: "?", extrusionDepth: 0.03)
            geom.font = UIFont(name: "Helvetica", size: 0.25);
            let (min, max) = geom.boundingBox
            let node = SCNNode(geometry: geom)
            node.position = SCNVector3(CGFloat(max.x - min.x) / -4, CGFloat(max.y - min.y) / -4 - 1, 0.02) // FIXME: Magic Number
            cell.addChildNode(node)
        }
    }

    private func showBomb(cell: SCNNode) {
        let geom = SCNText(string: "*", extrusionDepth: 0.03)
        geom.font = UIFont(name: "Helvetica", size: 0.25);
        geom.firstMaterial!.diffuse.contents = UIColor.red
        let (min, max) = geom.boundingBox
        let node = SCNNode(geometry: geom)
        node.position = SCNVector3(CGFloat(max.x - min.x) / -4, CGFloat(max.y - min.y) / -4 - 1, 0.02) // FIXME: Magic Number
        cell.addChildNode(node)
    }

    private func createNumber(number: Int) -> SCNNode {
        let geom = SCNText(string: "\(number)", extrusionDepth: 0.03)
        geom.font = UIFont(name: "Helvetica", size: 0.25);
        geom.firstMaterial!.diffuse.contents = UIColor.init(red: 0, green: 0.4, blue: 1, alpha: 1)
        geom.firstMaterial!.specular.contents = UIColor.white
        
        let (min, max) = geom.boundingBox
        let node = SCNNode(geometry: geom)
        //node.eulerAngles = SCNVector3(-Float.pi / 2, 0, 0)
        node.position = SCNVector3(CGFloat(max.x - min.x) / -4, CGFloat(max.y - min.y) / -4 - 1, 0.02) // FIXME: Magic Number
        //sceneView.scene.rootNode.addChildNode(node)
        return node
    }
}
