import UIKit
import FirebaseStorage
import FirebaseFirestore

class EditPlayerViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    //@IBOutlet weak var nameTextField: UITextField!

    @IBOutlet weak var nameTextField: UITextField!
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var positionTextField: UITextField!
    @IBOutlet weak var changeImageButton: UIButton!

    
    var player: Player?
    var teamName: String?
    var documentID: String?
    var newImage: UIImage?
    
    override func viewDidLoad() {
            super.viewDidLoad()
            setupView()
        }

        func setupView() {
            nameTextField.text = player?.name
            positionTextField.text = player?.position

            if let urlString = player?.photoURL,
               let url = URL(string: urlString) {
                URLSession.shared.dataTask(with: url) { data, _, _ in
                    if let data = data {
                        DispatchQueue.main.async {
                            self.imageView.image = UIImage(data: data)
                        }
                    }
                }.resume()
            }
        }

        @IBAction func changeImageTapped(_ sender: UIButton) {
            let picker = UIImagePickerController()
            picker.delegate = self
            picker.sourceType = .photoLibrary
            present(picker, animated: true)
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                imageView.image = image
                newImage = image
            }
            dismiss(animated: true)
        }

        @IBAction func saveChangesTapped(_ sender: UIButton) {
            guard let name = nameTextField.text, !name.isEmpty,
                  let position = positionTextField.text, !position.isEmpty,
                  let team = teamName,
                  let docID = documentID else {
                showError("All fields are required.")
                return
            }

            if let updatedImage = newImage {
                uploadImage(updatedImage) { imageURL in
                    self.savePlayer(name: name, position: position, imageURL: imageURL, team: team, docID: docID)
                }
            } else {
                savePlayer(name: name, position: position, imageURL: player?.photoURL, team: team, docID: docID)
            }
        }

        func uploadImage(_ image: UIImage, completion: @escaping (String?) -> Void) {
            guard let imageData = image.jpegData(compressionQuality: 0.8) else {
                completion(nil)
                return
            }

            let fileName = UUID().uuidString + ".jpg"
            let ref = Storage.storage().reference().child("playerImages/\(fileName)")

            ref.putData(imageData, metadata: nil) { _, error in
                if let error = error {
                    self.showError("Upload failed: \(error.localizedDescription)")
                    completion(nil)
                    return
                }

                ref.downloadURL { url, error in
                    if let error = error {
                        self.showError("Download URL failed: \(error.localizedDescription)")
                        completion(nil)
                        return
                    }
                    completion(url?.absoluteString)
                }
            }
        }

        func savePlayer(name: String, position: String, imageURL: String?, team: String, docID: String) {
            var updatedData: [String: Any] = [
                "name": name,
                "position": position
            ]
            if let url = imageURL {
                updatedData["photoURL"] = url
            }

            Firestore.firestore()
                .collection("teams")
                .document(team)
                .collection("players")
                .document(docID)
                .updateData(updatedData) { error in
                    if let error = error {
                        self.showError("Update failed: \(error.localizedDescription)")
                    } else {
                        print("✅ Player updated.")
                        self.navigationController?.popViewController(animated: true)
                    }
                }
        }

        func showError(_ message: String) {
            let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
        }
    }
