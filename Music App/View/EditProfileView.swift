//
//  EditProfileView.swift
//  Music App
//
//  Created by Sanskar Mishra on 7/19/23.
//

import SwiftUI
import PhotosUI
import Firebase
import FirebaseFirestore
import FirebaseStorage

struct EditProfileView: View {
    
    @State var currentUserName: String
    @State var currentUserBio: String
    @State var currentUserEmail: String
    @State var emailID: String = "" //use SAME email for spotify account
    @State var password: String = ""
    @State var userName: String = ""
    @State var userBio: String = ""
    @State var bioLink: String = ""
    @State var userProfilePicData: Data?
    @Environment(\.dismiss) var dismiss
    @State var showImagePicker: Bool = false
    @State var photoItem: PhotosPickerItem?
    @State var showError: Bool = false
    @State var errorMessage: String = ""
    @State var isLoading: Bool = false
    // MARK : UserDefaults
    @AppStorage("log_status") var logStatus: Bool = false
    @AppStorage("user_profile_url") var profileURL: URL?
    @AppStorage("user_name") var userNameStored: String = ""
    @AppStorage("user_UID") var userUID: String = ""
    var body: some View{
        VStack(spacing: 10){
            Text("Edit Profile")
                .font(.largeTitle.bold())
                .hAlign(.leading)
            ViewThatFits {
                ScrollView(.vertical, showsIndicators: false) {
                    HelperView()
                }
                HelperView()
            }
            
        }
        .vAlign(.top)
        .padding(15)
        .overlay(content: {
            LoadingView(show: $isLoading)
        })
        .photosPicker(isPresented: $showImagePicker, selection: $photoItem)
        .onChange(of: photoItem) { newValue in
            // MARK: Extracting UIImage From PhotoItem
            if let newValue{
                Task{
                    do{
                        guard let imageData = try await newValue.loadTransferable(type: Data.self) else{return}
                        //MARK: UI Must Be Updated on Main Thread
                        await MainActor.run(body: {
                            userProfilePicData = imageData
                        })
                    }catch{}
                }
            }
        }
        // MARK: Displaying Alert
        .alert(errorMessage, isPresented: $showError, actions:{})
        
    }
    
    @ViewBuilder
    func HelperView()-> some View {
        VStack(spacing: 12){
            ZStack{
                if let userProfilePicData, let image = UIImage(data: userProfilePicData){
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                }else{
                    Image("null_pfp")
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                }
            }
            .frame(width: 85, height: 85)
            .clipShape(Circle())
            .contentShape(Circle())
            .onTapGesture{
                showImagePicker.toggle()
            }
            .padding(.top,25)
            
            Text("Username: ")
            TextField(currentUserName, text: $userName)
                .textContentType(.emailAddress)
                .border(1, .gray.opacity(0.5))
                
            Text("User Bio: ")
            TextField(currentUserBio, text: $userBio)
                .textContentType(.emailAddress)
                .border(1, .gray.opacity(0.5))

            
            Button(action: updateProfile){
                //Login Button
                Text("Confirm")
                    .foregroundColor(.white)
                    .hAlign(.center)
                    .fillView(.black)
            }
            
            .disableWithOpacity(userName == "" && userBio == "" && userProfilePicData == nil)
            .padding(.top,10)
            
            
        }
        
    }
    
    func updateProfile(){
        //isLoading = true
        closeKeyboard()
        Task{
            do{
                
                //Uploading Profile Photo Into Firebase Storage
                guard let userUID = Auth.auth().currentUser?.uid else{return}
                guard let imageData = userProfilePicData else {return}
                let storageRef = Storage.storage().reference().child("Profile_Images").child(userUID)
                let _ = try await storageRef.putDataAsync(imageData)
                //Downloading photo URL
                let downloadURL = try await storageRef.downloadURL()
                //Creating a user firestore object
                let user = User(username: userName, userBio: userBio, userBioLink: bioLink, userUID: userUID, userEmail: currentUserEmail, userProfileURL: downloadURL)
                // Saving User Doc into Firestore database
                
                let _ = try Firestore.firestore().collection("Users").document(userUID).setData(from: user, completion:{
                    
                    
                    
                    error in
                    if error == nil{
                        //MARK: Print Saved Successfully
                        print("Saved Successfully")
                        userNameStored = userName
                        self.userUID = userUID
                        profileURL = downloadURL
                        logStatus = true
                        
                        
                    }
                })
                
            }catch{
                //MARK: Deleting Created Account In Case of Failure
                await setError(error)
            }
        }
    }
    
    func setError(_ error: Error) async{
        //MARK: UI Must be Uppdated on Main Thread
        await MainActor.run(body: {
            errorMessage = error.localizedDescription
            showError.toggle()
            isLoading = false
        })
    }
}

struct EditProfileView_Previews: PreviewProvider {
    static var previews: some View {
        EditProfileView(currentUserName: "", currentUserBio: "", currentUserEmail: "")
    }
}
