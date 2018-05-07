//
//  Checkbox.swift
//  Traffic Buddy
//
//  Created by Brian Williams on 5/6/18.
//  Copyright © 2018 Brian Williams. All rights reserved.
//

import UIKit

class CheckBox: UIButton {
    let checkedImage = UIImage(named: "check-30px")! as UIImage
    let uncheckedImage = UIImage(named: "outline-30px")! as UIImage
    
    var isChecked: Bool = false {
        didSet {
            if isChecked {
                setImage(checkedImage, for: UIControlState.normal)
            } else {
                setImage(uncheckedImage, for: UIControlState.normal)
            }
        }
    }
    
    override func awakeFromNib() {
        self.addTarget(self, action:#selector(buttonClicked(sender:)), for: UIControlEvents.touchUpInside)
        self.isChecked = false
    }
    
    @objc func buttonClicked(sender: UIButton) {
        if sender == self {
            isChecked = !isChecked
        }
    }
}
