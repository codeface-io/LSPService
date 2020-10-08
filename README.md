# Language Service Host

## What?

A web server for hosting a "language service" locally. The service then allows to access local [LSP](https://microsoft.github.io/language-server-protocol/) language servers via WebSockets:

![LanguageServiceHost](https://raw.githubusercontent.com/flowtoolz/LanguageServiceHost/master/Documentation/language_service_host_idea.jpg)

## Why?

To decouple editors (IDEs) from the language servers. Possible benefits:

* **Editors can be sandboxed and (hopefully) even be distributed via the Mac App Store.**
* In the future, the Language Service Host could be a machine's central place for locating, installing and running LSP language servers, which is something each editor still has to do by itself right now.
* Even further ahead, running the Language Service as a remote web service might have some interesting applications where LSP is used for static code analysis rather than code editing.

## How?

The singular purpose of the Language Service is to forward LSP messages from some editor to some LSP language server and vice versa. WebSocket here is just a means of data transport. The Language Service "API" shall know nothing about the LSP standard itself. Encoding and decoding LSP messages and generally representing LSP with proper types remains a concern of- and in control of the editor.

I'm writing this project on a Mac in Swift using [Vapor](https://github.com/vapor/vapor), and it should be possible to build it on Linux as well. Also, while the Language Service is intended to work with language servers for all languages, I'm using the Swift language server (`sourcekit-lsp`) to get this going.

Overall, this is really just an experimental seed right now. I've never done any backend development and have finally just figured out how to talk to [`sourcekit-lsp`](https://github.com/apple/sourcekit-lsp) and how to use WebSocket on server- and client side. I appreciate any advice and help! 🙏🏻

## To Do

* [x] Implement PoC with WebSockets. Not simply REST because:
  * Mapping responses to requests requires decoding messages to get their ID, which remains a concern of the client.
  * Language servers also send more "spontaneous" messages/notifications in addition to direct request responses.
  * Performance?
* [ ] Ensure this approach would actually fly with the Mac App Store review, because:
  * The editor app would need to encourage the user to download and install the Language Service Host, but apps in the App Store are not allowed to lead the user to some website, at least as it relates to purchase funnels.
  * The Language Service Host is not really a web API. And it could be argued that it is more of a plugin that effects the behaviour of the editor app, which would break App Store rules.
* [ ] Let Language Service locate `sourcekit-lsp`
* [ ] Allow to use multiple different language servers. Maybe have an endpoint for each language, like `ws://127.0.0.1:<service port>/<language>`
* [ ] Add basic API so client editors can ask what languages are available
* [ ] Possibly build a package/framework that helps Swift clients (editors) with using the LSH, consider using or extending <https://github.com/chimehq/SwiftLSPClient>
* [ ] Add web frontend (end necessary endpoints) for managing language servers, consider using [Leaf](https://github.com/vapor/leaf)
* [ ] Enable serving multiple clients who need services for the same language at the same time
