//
//  ViewController.swift
//  EditTransaction
//
//  Created by Suyash Anthwal on 12/04/26.
//

import UIKit

class EditTransactionViewController: UIViewController {
    
    
    @IBOutlet weak var TransactionAmount: UITextField!
    @IBOutlet weak var TransactionDateandTime: UIDatePicker!
    
    @IBAction func doneButton(_ sender: Any) {
    }
    
    @IBAction func cancelButton(_ sender: Any) {
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
    }
}

