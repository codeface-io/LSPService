# Language Service Host

## What?

An app that locally runs a web service (the "Language Service") which then allows editors and IDEs to use local [LSP](https://microsoft.github.io/language-server-protocol/) language servers simply via WebSockets.

## Why?

To make life easier for editors (and their developers) and to enable some future perspectives:

* **Mac Editors can be sandboxed and probably even be distributed via the Mac App Store.**
* **Editors don't need to locate, install, run and talk to language servers.**
* In the future, the Language Service could be a machine's central place for managing LSP language servers, possibly also through a web front end.
* Even further ahead, running the Language Service as a remote web service might have some interesting applications, in particular where LSP is used for static code analysis or remote inspection.

## How?

The singular purpose of the Language Service is to present language servers (for different languages) as simple WebSockets:

![LanguageServiceHost](https://raw.githubusercontent.com/flowtoolz/LanguageServiceHost/master/Documentation/language_service_host_idea.jpg)

The Language Service forwards LSP messages from some editor to some LSP language server and vice versa. It knows nothing about the LSP standard itself. Encoding and decoding LSP messages and generally representing LSP with proper types remains a concern of the editors. 

Editors, on the otherhand, know nothing about how to locate, install, run and talk to language servers. This remains a concern of the Language Service.

Although the Language Service is intended to work with language servers for all languages, I focus on the Swift language server (`sourcekit-lsp`) to get this going.

## To Do

* [x] Implement proof of concept with WebSockets
* [x] Let the Language Service locate `sourcekit-lsp` for the Swift endpoint
* [x] Have a dynamic endpoint for all languages, like `ws://127.0.0.1:<service port>/languageservice/api/<language>`
* [ ] Document how to use the LSH, possibly also provide binary
* [ ] Allow to use multiple different language servers. Proof concept by supporting/testing at least one additional language server (Python or Java)
* [ ] Ensure this approach would actually fly with the Mac App Store review, because:
  * The editor app would need to encourage the user to download and install the Language Service Host, but apps in the App Store are not allowed to lead the user to some website, at least as it relates to purchase funnels.
  * The Language Service Host is not really a web API. And it could be argued that it is more of a plugin that effects the behaviour of the editor app, which would break App Store rules.
* [ ] Add basic API so client editors can ask what languages are available
* [ ] Possibly build a package/framework that helps Swift clients (editors) with using the LSH, consider using or extending <https://github.com/chimehq/SwiftLSPClient>
* [ ] Add web frontend (end necessary endpoints) for managing language servers, consider using [Leaf](https://github.com/vapor/leaf)
* [ ] Enable serving multiple clients who need services for the same language at the same time
