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
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        if (self.image != nil) {
            imageView.image = UIImage(cgImage: image!)
        }
    }
    
    @IBAction func finish(view: UIView!) {
        self.dismiss(animated: true, completion: nil)
    }
}
