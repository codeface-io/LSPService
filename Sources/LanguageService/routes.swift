import Vapor
import Foundation

func routes(_ app: Application) throws {
    app.get { getRequest -> String in
        return "Hello, I'm a Language Service. You sent me a get request"
    }

    app.post { postRequest -> String in
        return "Post request body: \(postRequest.body.string ?? "nil")"
    }
}
