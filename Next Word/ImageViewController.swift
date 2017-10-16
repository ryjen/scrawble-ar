//
//  CapturedImage.swift
//  Next Word
//
//  Created by Ryan Jennings on 2017-10-01.
//  Copyright © 2017 Ryan Jennings. All rights reserved.
//

import UIKit

class ImageViewController : UIViewController {
    
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var button: UIButton!
    
    var image: CGImage?
    var overlay: CGRect?
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        if (self.image != nil) {
            imageView.image = UIImage(cgImage: image!)
        }
        
        if (self.overlay != nil) {
            let layer = CALayer()
            
            layer.bounds = self.overlay!
            layer.borderColor = UIColor.cyan.cgColor
            layer.borderWidth = 2
            
            self.imageView.layer.addSublayer(layer)
        }
    }
    
    @IBAction func finish(view: UIView!) {
        self.dismiss(animated: true, completion: nil)
    }
}
