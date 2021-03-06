//
//  Session.swift
//  scratch_ui
//
//  Created by Artorias on 2020-01-16.
//  Copyright © 2020 Artorias. All rights reserved.
//

import Foundation
import SwiftUI
import FirebaseFirestore
import FirebaseStorage
import FirebaseAuth
import Firebase


class Session: ObservableObject {
    @Published var user_id: String?
    @Published var user_image: UIImage?
    @Published var user_info = [String:String]()
    @Published var auto_hashtag = false
    @Published var user_image_list = [[UIImage?]]()
    @Published var user_image_tracker = [[String]]()
    @Published var comment_user_image = [String: UIImage]()
    @Published var global_image = [ImageHelper?]()
    
    func calculateAspectRatio(image: UIImage) -> CGFloat {
        let imageW = image.size.width
        let imageH = image.size.height
        let imageAspectRatio = imageW/imageH
        return imageAspectRatio
    }
    
    func loadGlobalData () {
        if self.global_image.count == 0 {
            self.loadGlobalImage()
        }
    }
    
    func loadGlobalImage () {
        let db = Firestore.firestore().collection("photos").document("general")
        db.getDocument { (snapshot, error) in
            if error != nil {
                print(error!.localizedDescription)
            }
            else {
                var temp_image_tracker = snapshot!.data()!["photos"] as! [String]
                temp_image_tracker.reverse()
                self.global_image = [ImageHelper?](repeating: nil, count: temp_image_tracker.count)
                for i in (0..<temp_image_tracker.count) {
                    let image_name = temp_image_tracker[i]
                    let storage_ref = Storage.storage().reference(withPath: "photos/\(image_name)_thumbnail.jpg")
                    storage_ref.getData(maxSize: 5*1024*1024) { (data, error) in
                        if error != nil {
                            print(error!.localizedDescription)
                        }
                        else {
                            let image_helper = ImageHelper(name: image_name, image: UIImage(data: data!))
                            self.global_image[i] = image_helper
                            print(image_helper)
                        }
                    }
                    
                }
            }
        }
    }
    
    func loadCommensUserImages (comments :[[String: String]]) {
        for comment in comments {
            print(comment)
            let user_id = comment["user_id"]!
            if self.comment_user_image[user_id] == nil {
                let storage_ref = Storage.storage().reference(withPath: "\(user_id)/user_img_thumbnail.jpg")
                storage_ref.getData(maxSize: 5*1024*1024) { (data, error) in
                    if error != nil {
                        print(error!.localizedDescription)
                    }
                    else {
                        self.comment_user_image[user_id] = UIImage(data: data!)
                    }
                }
            }
        }
    }
    
    func loadComment (image_name: String, completion: @escaping (_ comments: [[String: String]]) -> Void) {
        let db = Firestore.firestore().collection("photos").document(image_name)
        db.getDocument { (snapshot, error) in
            if error != nil {
                print(error!.localizedDescription)
            }
            else {
                let comments = snapshot!.data()!["comment"] as! [[String: String]]
                completion(comments)
            }
        }
    }
    
    func postComment (comment: String, image_name: String, completion: @escaping () -> Void) {
        let db = Firestore.firestore().collection("photos").document(image_name)
        db.getDocument { (snapshot, error) in
            if error != nil {
                print(error!.localizedDescription)
            }
            else {
                var comments = snapshot!.data()!["comment"] as! [[String: String]]
                let new_comment = ["user_id": self.user_id!, "comment": comment, "username": self.user_info["username"]]
                comments.append(new_comment as! [String : String])
                db.setData(["comment": comments], merge: true)
                completion()
            }
        }
    }
    
    func signOut () {
        self.user_image = nil
        self.user_info = [String:String]()
        self.user_image_list = [[UIImage?]]()
        self.user_image_tracker = [[String]]()
        self.global_image = [ImageHelper?]()
        self.comment_user_image = [String: UIImage]()
        self.user_id = nil
    }
    
    func deleteImage (name: String) {
        var user_image_tracker_temp = [String]()
        for i in self.user_image_tracker {
            user_image_tracker_temp += i
        }
        var user_image_list_temp = [UIImage?]()
        for i in self.user_image_list {
            user_image_list_temp += i
        }
        if let index = user_image_tracker_temp.firstIndex(of: name) {
            user_image_tracker_temp.remove(at: index)
            user_image_list_temp.remove(at: index)
            self.user_image_tracker = self.rearrage(list: user_image_tracker_temp) as! [[String]]
            self.user_image_list = self.rearrage(list: user_image_list_temp as [Any]) as! [[UIImage]]
        }
        let db = Firestore.firestore()
        db.collection("users").document(self.user_id!).getDocument { (snapshot, error) in
            if error != nil {
                print(error!.localizedDescription)
            }
            else {
                var photos = snapshot!.data()!["photos"] as! [String]
                if let index = photos.firstIndex(of: name) {
                    photos.remove(at: index)
                    db.collection("users").document(self.user_id!).setData(["photos": photos], merge: true)
                }
            }
        }
        db.collection("photos").document("general").getDocument { (snapshot, error) in
            if error != nil {
                print(error!.localizedDescription)
            }
            else {
                var photos = snapshot!.data()!["photos"] as! [String]
                if let index = photos.firstIndex(of: name) {
                    photos.remove(at: index)
                    db.collection("photos").document("general").setData(["photos": photos], merge: true)
                }
            }
        }
        db.collection("photos").document(name).delete() { error in
            if error != nil {
                print(error!.localizedDescription)
            }
        }
        let storage_ref = Storage.storage().reference(withPath: "photos/\(name).jpg")
        storage_ref.delete { (error) in
            if error != nil {
                print(error!.localizedDescription)
            }
        }
        let storage_ref_thumbnail = Storage.storage().reference(withPath: "photos/\(name)_thumbnail.jpg")
        storage_ref_thumbnail.delete { (error) in
            if error != nil {
                print(error!.localizedDescription)
            }
        }
    }
    
    func getImageDetail (name: String, completion: @escaping (_ result: [String: String]) -> Void) {
        let db = Firestore.firestore().collection("photos").document(name)
        var result = [String: String]()
        db.getDocument { (snapshot, error) in
            if error != nil {
                print(error!.localizedDescription)
            }
            else {
                result["caption"] = snapshot!.data()!["caption"] as? String
                result["hash_tag"] = snapshot!.data()!["hash_tag"] as? String
                result["uploader"] = snapshot!.data()!["uploader"] as? String
                completion(result)
            }
        }
    }
    
    func loadFullImage (name: String, completion: @escaping (_ result: UIImage?) -> Void) {
        let storage_ref = Storage.storage().reference(withPath: "photos/\(name).jpg")
        storage_ref.getData(maxSize: 5*1024*1024) { (data, error) in
            let full_image = UIImage(data: data!)
            completion(full_image)
        }
    }
    
    func loadAllUserImages () {
        let db = Firestore.firestore().collection("users").document(self.user_id!)
        db.getDocument { (snapshot, error) in
            if error != nil {
                print(error!.localizedDescription)
            }
            else {
                var user_image_name_list = snapshot!.data()!["photos"] as! [String]
                user_image_name_list.reverse()
                self.user_image_tracker = self.rearrangeImageatLogin(images: user_image_name_list, total: user_image_name_list.count)
                for row in (0..<self.user_image_tracker.count) {
                    for col in (0..<self.user_image_tracker[row].count) {
                        let current_image = self.user_image_tracker[row][col]
                        let storage_ref = Storage.storage().reference(withPath: "photos/\(current_image)_thumbnail.jpg")
                        storage_ref.getData(maxSize: 5*1024*1024) { (data, error) in
                            if error != nil {
                                print(error!.localizedDescription)
                            }
                            else {
                                self.user_image_list[row][col] = UIImage(data: data!)
                            }
                        }
                    }
                }
            }
        }
    }
    
    func rearrage (list: [Any]) -> [[Any]] {
        var arranged_list = [[Any]]()
        var temp = [Any]()
        let total = list.count
        var count = 0
        for item in list {
            count += 1
            if temp.count < 3 {
                temp.append(item)
                
            }
            else {
                arranged_list.append(temp)
                temp = [item]
            }
        }
        if count == total && temp.count > 0 {
            arranged_list.append(temp)
        }
        return arranged_list
    }
    
    func updateAfterUplaod (last_upload: UIImage) {
        let db = Firestore.firestore().collection("users").document(self.user_id!)
        db.getDocument { (snapshot, error) in
            if error != nil {
                print(error!.localizedDescription)
            }
            else {
                var images_name = snapshot!.data()!["photos"] as! [String]
                images_name.reverse()
                let last_image = last_upload
                var images = [UIImage]()
                for rows in self.user_image_list {
                    images += rows as! [UIImage]
                }
                images.insert(last_image, at: 0)
                self.user_image_tracker = self.rearrage(list: images_name) as! [[String]]
                self.user_image_list = self.rearrage(list: images) as! [[UIImage]]
                self.loadGlobalImage()

            }
        }
    }
    
    func rearrangeImageatLogin (images: [String], total: Int) -> [[String]] {
        var arranged_image_name = [[String]]()
        var arranged_images = [[UIImage?]]()
        var temp = [String]()
        var temp_image = [UIImage?]()
        var count = 0
        for image in images {
            count += 1
            if temp.count < 3{
                temp.append(image)
                temp_image.append(nil)
            }
            else {
                arranged_image_name.append(temp)
                arranged_images.append(temp_image)
                temp = [String]()
                temp_image = [UIImage?]()
                temp.append(image)
                temp_image.append(nil)
            }
        }
        if count == total && temp.count > 0 {
            arranged_image_name.append(temp)
            arranged_images.append(temp_image)
        }
        self.user_image_list = arranged_images
        return arranged_image_name
    }
    
    func loadData () {
        if self.user_image == nil {
            self.loadUserImage()
        }
        if self.user_info.isEmpty {
            self.loadUserInfo()
        }
        if self.user_image_list.count == 0{
            self.loadAllUserImages()
        }
    }
    
    func uploadImage(image: UIImage, hash: String, caption: String, completion: @escaping (_ err: String?) -> Void) {
//        print(self.user_id!)
        let db = Firestore.firestore()
        db.collection("photos").document("general").getDocument { (document, error) in
            if error != nil {
                completion(error!.localizedDescription)
            }
            else {
                var total_photo = document!.data()!["total"] as! Int
                var all_photos = document!.data()!["photos"] as! [String]
                let photo_name = String(total_photo)
                total_photo += 1
                all_photos.append(photo_name)
                db.collection("photos").document("general").setData(["photos": all_photos, "total": total_photo], merge: true)
                
                db.collection("photos").document(photo_name).setData(["hash_tag": hash, "comment": [], "caption": caption, "uploader": self.user_id!], merge: true)
                db.collection("users").document(self.user_id!).getDocument { (document, error) in
                    if error != nil {
                        completion(error!.localizedDescription)
                    }
                    else {
                        var all_user_photos = document!.data()!["photos"] as! [String]
                        all_user_photos.append(photo_name)
                        db.collection("users").document(self.user_id!).setData(["photos": all_user_photos], merge: true)
                        self.uploadImageHelper(image: image, name: photo_name) { (error) in
                            if error != nil {
                                print(error!)
                            }
                        }
                    }
                }
            }
        }
        
    }
    
    func uploadImageHelper (image: UIImage, name: String, completion: @escaping (_ err: String?) -> Void) {
        // original image
        let upload_ref = Storage.storage().reference(withPath: "photos/\(name).jpg")
        guard let image_data = image.jpegData(compressionQuality: 0.75) else {
            completion("Oh no! Something went wrong!")
            return
        }
        let meta_data = StorageMetadata.init()
        meta_data.contentType = "image/jpeg"
        upload_ref.putData(image_data, metadata: meta_data) { (junk, error) in
            if error != nil {
                completion(error!.localizedDescription)
                return
            }
            

        }

        // thumbnail
        let upload_ref_thumbnail = Storage.storage().reference(withPath: "photos/\(name)_thumbnail.jpg")
        guard let image_data_thumbnail = image.jpegData(compressionQuality: 0.25) else {
            completion("Oh no! Something went wrong!")
            return
        }
        upload_ref_thumbnail.putData(image_data_thumbnail, metadata: meta_data) { (junk, error) in
            if error != nil {
                completion(error!.localizedDescription)
                return
            }
            else {
                self.updateAfterUplaod(last_upload: image)
            }

        }
    }
    
    func labelImage (image: UIImage, completion: @escaping (_ hashtag: String?) -> Void) {
        let label_image = VisionImage(image: image)
        let options = VisionOnDeviceImageLabelerOptions()
        options.confidenceThreshold = 0.7
        let labeler = Vision.vision().onDeviceImageLabeler(options: options)
        labeler.process(label_image) { (labels, error) in
            guard error == nil, let labels = labels else { return }
            var hash = ""
            for label in labels {
                hash = hash + "#" + label.text + " "
                print(label.text)
            }
            completion(hash)
        }
    }
    
    func loadUserInfo () {
        let db = Firestore.firestore().collection("users")
        db.document(self.user_id!).getDocument { (data, error) in
            if error != nil {
                print(error!.localizedDescription)
            }
            else {
                let bio = data?.data()?["bio"] as! String
                let username = data?.data()?["username"] as! String
                self.user_info["bio"] = bio
                self.user_info["username"] = username
            }
        }
    }
    
    func loadUserImage () {
        if self.user_image == nil {
            let storage_ref = Storage.storage().reference(withPath: "\(self.user_id!)/user_img_thumbnail.jpg")
            storage_ref.getData(maxSize: 5 * 1024 * 1024) { (data, error) in
                if error != nil {
                    print(error!.localizedDescription)
                }
                else {
                    self.user_image = UIImage(data: data!)
                }
            }
        }
        
    }
    
    func uploadUserImage(user_image: UIImage) {

        let upload_ref = Storage.storage().reference(withPath: "\(self.user_id!)/user_img.jpg")
        guard let image_data = user_image.jpegData(compressionQuality: 0.5) else {
            print("Oh no! Something went wrong!")
            return
        }
        let meta_data = StorageMetadata.init()
        meta_data.contentType = "image/jpeg"
        upload_ref.putData(image_data, metadata: meta_data) { (junk, error) in
            if error != nil {
                print(error!.localizedDescription)
            }
        }
        
        
        let upload_ref_thumbnail = Storage.storage().reference(withPath: "\(self.user_id!)/user_img_thumbnail.jpg")
        guard let image_data_thumbnail = user_image.jpegData(compressionQuality: 0.25) else {
            print("Oh no! Something went wrong!")
            return
        }
        upload_ref_thumbnail.putData(image_data_thumbnail, metadata: meta_data) { (junk, error) in
            if error != nil {
                print(error!.localizedDescription)
            }
            else {
                self.loadUserImage()
            }
        }
    
    }
    
    func signUp(email: String, password: String, confirm_password: String, username: String, bio: String, user_img: UIImage?, completion: @escaping (_ err: String?) -> Void) {
        if email == "" || password == "" || confirm_password == "" || username == "" || bio == "" {
            completion("Please fill in the required field.")
        }
        else if password != confirm_password {
            completion("Passwords do not match.")
        }
        else if user_img == nil {
            completion("Please choose a user photo.")
        }
        else {
            Auth.auth().createUser(withEmail: email, password: password) { (res, err) in
                if err != nil {
                    completion(err!.localizedDescription)
                }
                else {
                    Auth.auth().signIn(withEmail: email, password: password) { (res, error) in
                        if error != nil {
                            completion(error!.localizedDescription)
                        }
                        self.user_id = Auth.auth().currentUser!.uid
                        let db = Firestore.firestore().collection("users")
                        db.document(self.user_id!).setData(["username": username, "bio": bio, "email": email, "photos": [String]()])
                        self.uploadUserImage(user_image: user_img!)
                        
                    }
                }
                
            }
        }
    }
    
    func signIn (email: String, password: String, completion: @escaping (_ err: String?) -> Void) {
        Auth.auth().signIn(withEmail: email, password: password) { (res, error) in
            if error != nil {
                completion(error!.localizedDescription)
            }
            else {
                self.user_id = Auth.auth().currentUser!.uid
            }
        }
    }
}
