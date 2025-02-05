import SwiftUI
import P256K

public struct ContentView: View {
    public init() {}

    public var body: some View {
        let privateKey = try! secp256k1.Signing.PrivateKey()
        let stringKey = String(bytes: privateKey.dataRepresentation)

        Text("KEY: \(stringKey)")
            .padding()
    }
}


struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
