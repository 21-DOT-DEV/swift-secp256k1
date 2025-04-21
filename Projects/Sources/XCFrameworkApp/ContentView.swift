import P256K
import SwiftUI

public struct ContentView: View {
    public init() {}

    public var body: some View {
        let privateKey = try! P256K.Signing.PrivateKey()
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
