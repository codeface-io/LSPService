# Language Service Host

## What?

An app that locally hosts a web service (the "Language Service") which then allows editors and IDEs to use local [LSP language servers](https://langserver.org) simply via WebSockets.

## Why?

The [LSP protocol](https://microsoft.github.io/language-server-protocol/) is the present and future of software development tools. But leveraging it for my own tool project turned out to be more difficult than expected. 

Most of all, I want to distribute my tool via the App Store, so it must be sandboxed, which makes it impossible to deal with language servers directly or with any other "tooling" of the tech world.

So I thoutht: What if a language server was simply a local web service? Possible benefits:

* **On macOS, Editors can be sandboxed and probably even be distributed via the App Store.**
* **Editors don't need to locate, install, run and talk to language servers.**
* In the future, the Language Service could be a machine's central place for managing LSP language servers, through a CLI and/or through a web front end.
* Even further down the road, running the Language Service on actual web servers might have interesting applications, in particular where LSP is used for static code analysis or remote inspection.

## How?

The singular purpose of the Language Service is to present LSP language servers as simple WebSockets:

![LanguageServiceHost](https://raw.githubusercontent.com/flowtoolz/LanguageServiceHost/master/Documentation/language_service_host_idea.jpg)

The Language Service forwards LSP messages from some editor to some LSP language server and vice versa. It knows nothing about the LSP standard itself. Encoding and decoding LSP messages and generally representing LSP with proper types remains a concern of the editors. 

Editors, on the other hand, know nothing about how to locate, install, run and talk to language servers. This remains a concern of the Language Service.

Although the Language Service will work with many languages, I focus on the Swift language server (`sourcekit-lsp`) to get this going.

## To Do

* [x] Implement proof of concept with WebSockets and `sourcekit-lsp`
* [x] Let the Language Service locate `sourcekit-lsp` for the Swift endpoint
* [x] Have a dynamic endpoint for all languages, like `ws://127.0.0.1:<service port>/languageservice/api/<language>`
* [ ] Explore whether `sourcekit-lsp` can be adjusted to send error feedback when it fails to decode incoming data. This would enormously accelerate development of  `sourcekit-lsp` clients, whether they use `sourcekit-lsp` directly or via this Language Service. And it might also have implications for the Language Service.
* [ ] Add a way for client editors to receive the [error output](https://en.wikipedia.org/wiki/Standard_streams#Standard_error_(stderr)) from language server processes
* [ ] Add an endpoint for client editors to detect what languages are available
* [ ] Allow to use multiple different language servers. Proof concept by supporting/testing at least one additional language server (Python or Java)
* [ ] Document how to use the LSH, possibly also provide macOS binary
* [ ] Enable serving different language endpoints with the same language server executable, like `sourcekit-lsp` can work with C, C++ and Objective-c as well.
* [ ] Add web frontend for managing language servers. Consider using [Plot](https://github.com/JohnSundell/Plot)
* [ ] Possibly build a package/framework for simply and typsafely defining, encoding and decoding LSP messages. Consider suggesting to extract that type system from [SwiftLSPClient](https://github.com/chimehq/SwiftLSPClient) and/or from sourcekit-lsp into a dedicated package. Both use a (near) identical typesystem for that already ...
* [ ] Possibly build a Swift package that helps Swift clients (editors) with using the Language Server
* [ ] Enable serving multiple clients who need services for the same language at the same time
* [ ] Explore whether this approach would actually fly with the Mac App Store review, because:
  * The editor app would need to encourage the user to download and install the Language Service Host, but apps in the App Store are not allowed to lead the user to some website, at least as it relates to purchase funnels.
  * The Language Service Host is not really a web API. And it could be argued that it is more of a plugin that effects the behaviour of the editor app, which would break App Store rules.
