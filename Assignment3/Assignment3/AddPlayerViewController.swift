import UIKit
import FirebaseFirestore
import FirebaseStorage

class AddPlayerViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {

    // MARK: - IBOutlets
    @IBOutlet weak var nameField: UITextField!
    @IBOutlet weak var positionField: UITextField!
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var uploadButton: UIButton!
    @IBOutlet weak var loadingLabel: UILabel!
    @IBOutlet weak var saveButton: UIButton!

    // MARK: - Properties
    var teamName: String?
    var selectedImage: UIImage?

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    // MARK: - Image Upload
    @IBAction func uploadTapped(_ sender: UIButton) {
        let picker = UIImagePickerController()
        picker.delegate = self
        picker.sourceType = .photoLibrary
        present(picker, animated: true)
    }

    func imagePickerController(_ picker: UIImagePickerController,
                               didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        if let image = info[.originalImage] as? UIImage {
            imageView.image = image
            selectedImage = image
        }
        dismiss(animated: true)
    }

    // MARK: - Save Player
    @IBAction func saveTapped(_ sender: UIButton) {
        guard let team = teamName,
              let name = nameField.text?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty,
              let position = positionField.text?.trimmingCharacters(in: .whitespacesAndNewlines), !position.isEmpty else {
            showError("All fields are required.")
            return
        }

        // 1️⃣ Check for duplicate player name
        let playersRef = Firestore.firestore()
            .collection("teams")
            .document(team)
            .collection("players")
        playersRef.whereField("name", isEqualTo: name).getDocuments { snapshot, error in
            if let error = error {
                self.showError("Failed to validate name: \(error.localizedDescription)")
                return
            }
            if let docs = snapshot?.documents, !docs.isEmpty {
                self.showError("A player named \"\(name)\" already exists.")
                return
            }

            // 2️⃣ No duplicate — proceed to upload image or save directly
            if let image = self.selectedImage {
                self.uploadImage(image) { imageURL in
                    if let url = imageURL {
                        self.persistPlayer(name: name, position: position, imageURL: url, team: team)
                    } else {
                        self.showError("Image upload failed.")
                    }
                }
            } else {
                self.persistPlayer(name: name, position: position, imageURL: nil, team: team)
            }
        }
    }

    private func persistPlayer(name: String, position: String, imageURL: String?, team: String) {
        var data: [String: Any] = ["name": name, "position": position]
        if let photo = imageURL {
            data["photoURL"] = photo
        }
        Firestore.firestore()
            .collection("teams")
            .document(team)
            .collection("players")
            .addDocument(data: data) { error in
                if let error = error {
                    self.showError("Save failed: \(error.localizedDescription)")
                } else {
                    self.navigationController?.popViewController(animated: true)
                }
            }
    }

    // MARK: - Image Upload Helper
    private func uploadImage(_ image: UIImage, completion: @escaping (String?) -> Void) {
        guard let data = image.jpegData(compressionQuality: 0.8) else {
            completion(nil)
            return
        }
        let fileName = UUID().uuidString + ".jpg"
        let storageRef = Storage.storage().reference().child("playerImages/\(fileName)")
        storageRef.putData(data, metadata: nil) { _, error in
            if let error = error {
                print("Upload error: \(error.localizedDescription)")
                completion(nil)
                return
            }
            storageRef.downloadURL { url, _ in
                completion(url?.absoluteString)
            }
        }
    }
    
    // MARK: - Loading Helper
        private func finishLoading() {
            DispatchQueue.main.async {
                self.loadingLabel.isHidden = true
                self.saveButton.isEnabled = true
                self.uploadButton.isEnabled = true
            }
        }

    // MARK: - Error Handling
    private func showError(_ message: String) {
        let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
