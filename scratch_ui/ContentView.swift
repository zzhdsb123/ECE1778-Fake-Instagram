//
//  ContentView.swift
//  scratch_ui
//
//  Created by Artorias on 2020-01-08.
//  Copyright © 2020 Artorias. All rights reserved.
//

import SwiftUI
import Firebase
import FirebaseStorage


struct DetailView: View {
  let discipline: String
  var body: some View {
    Text(discipline)
  }
}

struct ContentView: View {
    @EnvironmentObject var session: Session

    var body: some View {
        Group {
            if session.user_id != nil {
                AuthView()
            }
            else {
                SignInView()
            }
        }
        
    }
}


#if DEBUG
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
#endif
