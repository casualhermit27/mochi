import Foundation
import LocalAuthentication
import Combine

class BiometricManager: ObservableObject {
    static let shared = BiometricManager()
    
    @Published var isAuthenticated = false
    @Published var errorMsg = ""
    
    // We only need to check authentication if the lock is actually enabled
    func authenticate() {
        let context = LAContext()
        var error: NSError?
        
        // Check if biometric authentication is possible
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            let reason = "Unlock Mochi to view your data."
            
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, authenticationError in
                DispatchQueue.main.async {
                    if success {
                        self.isAuthenticated = true
                        self.errorMsg = ""
                    } else {
                        self.isAuthenticated = false
                        self.errorMsg = authenticationError?.localizedDescription ?? "Authentication failed"
                    }
                }
            }
        } else {
            // No biometrics available, try to fallback to passcode
            let reason = "Unlock Mochi to view your data."
            context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, authenticationError in
                DispatchQueue.main.async {
                    if success {
                        self.isAuthenticated = true
                        self.errorMsg = ""
                    } else {
                        self.isAuthenticated = false
                        self.errorMsg = authenticationError?.localizedDescription ?? "Authentication failed"
                    }
                }
            }
        }
    }
}
