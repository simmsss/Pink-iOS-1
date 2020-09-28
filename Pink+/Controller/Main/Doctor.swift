//
//  Doctor.swift
//  Pink+
//
//  Created by Utkarsh Sharma on 27/09/20.
//

import UIKit
import FirebaseDatabase
import CDAlertView
import SVProgressHUD
import Alamofire
import SwiftyJSON
import FirebaseStorage

class Doctor: UIViewController, UITableViewDelegate, UITableViewDataSource {
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var symptomButton: UIButton!
    
    var cytologyNameDict:[Int: String] = [:]
    var cytologyAgeDict:[Int: String] = [:]
    var cytologyimageurl:[Int: String] = [:]
    var cytologyImages:[Int: UIImage] = [:]
    var cytologyResult:[Int: String] = [:]
    var remarks:[Int: String] = [:]
    
    var selectedName = ""
    var selectedAge = ""
    var selectedImage: UIImage?
    var selectedImageurl = ""
    var selectedRemarks = ""
    
    var radiusField: UITextField!
    var textureField: UITextField!
    var perimeterField: UITextField!
    var areaField: UITextField!
    var smoothnessField: UITextField!
    var remarkField: UITextField!
    
    var ref: DatabaseReference!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        ref = Database.database().reference()
        
        getCytology()
        
        tableView.delegate = self
        tableView.dataSource = self
    }
    
    @IBAction func mlrecurrenceBtnPressed(_ sender: Any) {
        
    }
    
    @IBAction func symptomButtonPressed(_ sender: Any) {
        
    }
    
}


extension Doctor {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return cytologyNameDict.count
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "CytologyCell", for: indexPath) as? CytologyCell

        cell?.selectionStyle = .none
        
        cell?.nameLabel.text = cytologyNameDict[indexPath.row]
        cell?.ageLabel.text = "Age: \(cytologyAgeDict[indexPath.row]!)"
        cell?.currentResultLbl.text = "Current result: \(cytologyResult[indexPath.row]!)"
        cell?.cytologyImage.image = UIImage(named: "educateDef")
        cell?.remarksLbl.text = "Remarks: \(remarks[indexPath.row] ?? "None")"
        
        let storage = Storage.storage()
        let storageRef = storage.reference()
        let spaceRef = storageRef.child("uploads/\(cytologyNameDict[indexPath.row]!)cytology.png")

        // Download in memory with a maximum allowed size of 1MB (1 * 1024 * 1024 bytes)
        spaceRef.getData(maxSize: 1 * 1024 * 1024) { data, error in
          if let error = error {
                print(error)
          } else {
                self.cytologyImages[indexPath.row] = UIImage(data: data!)
                cell?.cytologyImage.image = self.cytologyImages[indexPath.row]
          }
        }
        
        return cell!
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        selectedName = cytologyNameDict[indexPath.row]!
        selectedAge = cytologyAgeDict[indexPath.row]!
        selectedImage = cytologyImages[indexPath.row]!
        selectedImageurl = cytologyimageurl[indexPath.row]!
        
        self.displayForm(message: "Please enter the cytology report readings to get a ML-based evaluation for possible presence of Breast Cancer.")
    }
    
    func displayForm(message:String){
            //create alert
            let alert = UIAlertController(title: "ML Cytology Report Evaluation", message: message, preferredStyle: .alert)
                
            //create cancel button
            let cancelAction = UIAlertAction(title: "Cancel" , style: .cancel)
        
            let imageAction = UIAlertAction(title: "See Report", style: .default) { (action) in
                if let url = URL(string: self.selectedImageurl) {
                    UIApplication.shared.open(url)
                } else {
                    let alert = CDAlertView(title: "Oops, something's not right!", message: "Can't open this image. Please try again later.", type: .error)
                    let doneAction = CDAlertViewAction(title: "Okay! 💪")
                    alert.add(action: doneAction)
                    alert.show()
                }
            }
            
            //create save button
            let saveAction = UIAlertAction(title: "Submit", style: .default) { (action) -> Void in
               //validation logic goes here
                if((self.radiusField.text?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)!
                    || (self.textureField.text?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)!
                    || (self.perimeterField.text?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)!
                    || (self.areaField.text?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)!
                    || (self.smoothnessField.text?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)! ){
                    self.radiusField.text = ""
                    self.textureField.text = ""
                    self.perimeterField.text = ""
                    self.areaField.text = ""
                    self.smoothnessField.text = ""
                    
                    self.displayForm(message: "One of the values entered was invalid. Please enter all information")
                }
                
                // handle api here
                
                let radius: String! = self.radiusField.text!
                let texture: String! = self.textureField.text!
                let perimeter: String! = self.perimeterField.text!
                let area: String! = self.areaField.text!
                let smoothness: String! = self.smoothnessField.text!
                
                let stringToPass = "\(radius ?? ""),\(texture ?? ""),\(perimeter ?? ""),\(area ?? ""),\(smoothness ?? "")"
                
                print(stringToPass)
                
                let parameters = ["data": stringToPass]
                
                let url = "https://bcpd.herokuapp.com/predict"
                
                SVProgressHUD.show(withStatus: "Calculating....")
                
                AF.request(url, method: .post, parameters: parameters, encoding: JSONEncoding.default).responseJSON { (response) in
                    switch (response.result) {
                        case .success(let data):
                            SVProgressHUD.dismiss()
                            guard let json = data as? [String : AnyObject] else {
                                SVProgressHUD.showError(withStatus: "Failed to get expected response from webserver.")
                                return
                            }

                            // Then make sure you get the actual key/value types you expect
                            let pred = json["Prediction"] as? String
                            if(pred=="Benign"){
                                let alert = CDAlertView(title: "Benign", message: "According to our ML evaluation, we don't seem to detect a presence of cancerous breast cancer tumor. We can proudly state that we have an accuracy score of 93% and a very high precision and recall for detection non-cancerous cells. This, however, shouldn't be treated as a fail-proof result. We advice you cross-verify.", type: .success)
                                var remarks = "None"
                                remarks = self.remarkField.text ?? "None"
                                self.ref.child("cytologyreports/\(self.selectedName)/Result").setValue("Benign")
                                self.ref.child("cytologyreports/\(self.selectedName)/Remarks").setValue(remarks)
                                let doneAction = CDAlertViewAction(title: "Thanks! 😁")
                                alert.add(action: doneAction)
                                alert.show()
                                self.getCytology()
                            } else if(pred=="Malignant") {
                                let alert = CDAlertView(title: "Malignant", message: "According to our ML evaluation, it seems like there might be traces of a cancerous breast cancer tumor. We have a high precision, recall and accuracy for detecting this. Cross-verification is highly recommended.", type: .notification)
                                var remarks = "None"
                                remarks = self.remarkField.text ?? "None"
                                self.ref.child("users/\(self.selectedName)/Result").setValue("Malignant")
                                self.ref.child("cytologyreports/\(self.selectedName)/Remarks").setValue(remarks)
                                let doneAction = CDAlertViewAction(title: "Sure!")
                                alert.add(action: doneAction)
                                alert.show()
                                self.getCytology()
                            }
                            
                            break
                        case .failure(let error):
                            SVProgressHUD.dismiss()
                            SVProgressHUD.showError(withStatus: "Something went wrong. It's not you, it's us.")
                            print(Error.self)
                    }
                    SVProgressHUD.dismiss()
                }
            }
            
            //add button to alert
            alert.addAction(cancelAction)
            alert.addAction(imageAction)
            alert.addAction(saveAction)
            
            alert.addTextField(configurationHandler: {(textField: UITextField!) in
                textField.placeholder = "Enter the mean radius (e.g., 17.99)"
                textField.keyboardType = .decimalPad
                self.radiusField = textField
            })
            
            alert.addTextField(configurationHandler: {(textField: UITextField!) in
                textField.placeholder = "Enter mean texture (e.g., 10.38)"
                textField.keyboardType = .decimalPad
                self.textureField = textField
            })
            
            alert.addTextField(configurationHandler: {(textField: UITextField!) in
                textField.placeholder = "Enter mean perimeter (e.g., 122.8)"
                textField.keyboardType = .decimalPad
                self.perimeterField = textField
            })
        
            alert.addTextField(configurationHandler: {(textField: UITextField!) in
                textField.placeholder = "Enter mean area (e.g., 1000)"
                textField.keyboardType = .decimalPad
                self.areaField = textField
            })
            
            alert.addTextField(configurationHandler: {(textField: UITextField!) in
                textField.placeholder = "Enter mean smoothness (e.g., 0.1184)"
                textField.keyboardType = .decimalPad
                self.smoothnessField = textField
            })
        
            alert.addTextField(configurationHandler: {(textField: UITextField!) in
                textField.placeholder = "Enter your remarks here"
                textField.keyboardType = .default
                self.remarkField = textField
            })
        
            self.present(alert, animated: true, completion: nil)
        }
    
    func getCytology(){
        self.tableView.isHidden = true
        SVProgressHUD.show()
        
        self.cytologyNameDict.removeAll()
        self.cytologyAgeDict.removeAll()
        
        var counter = 0
        ref.child("cytologyreports").observeSingleEvent(of: .value, with: { (snapshot) in
          let value = snapshot.value as? NSDictionary
            if ((value) != nil) {
                
                let json = JSON(value!)
                counter = 0
                for (key, subjson):(String, JSON) in json {
                    self.cytologyNameDict[counter] = key
                    self.cytologyAgeDict[counter] = subjson["Age"].stringValue
                    self.cytologyResult[counter] = subjson["Result"].stringValue
                    self.cytologyimageurl[counter] = subjson["Media"].stringValue
                    self.remarks[counter] = subjson["Remarks"].stringValue
                    counter = counter + 1
                    
                    self.tableView.isHidden = false
                    SVProgressHUD.dismiss()
                }
                
                if(self.cytologyNameDict.count == 0){
                    SVProgressHUD.dismiss()
                    let alert = CDAlertView(title: "Oops, something's not right!", message: "No cytology reports to show. Please try again later.", type: .error)
                    let doneAction = CDAlertViewAction(title: "Sure! 💪")
                    alert.add(action: doneAction)
                    alert.show()
                } else {
                    self.tableView.reloadData()
                }
            } else {
                SVProgressHUD.dismiss()
                let alert = CDAlertView(title: "Oops, something's not right!", message: "No reports to show. Please try again later", type: .error)
                let doneAction = CDAlertViewAction(title: "Sure! 💪")
                alert.add(action: doneAction)
                alert.show()
            }
          }) { (error) in
            SVProgressHUD.dismiss()
            print(error.localizedDescription)
        }
    }
}
