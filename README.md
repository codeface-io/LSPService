# LSPService

[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fcodeface-io%2FLSPService%2Fbadge%3Ftype%3Dswift-versions&style=flat-square)](https://swiftpackageindex.com/codeface-io/LSPService) [![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fcodeface-io%2FLSPService%2Fbadge%3Ftype%3Dplatforms&style=flat-square)](https://swiftpackageindex.com/codeface-io/LSPService) [![](https://img.shields.io/badge/License-MIT-lightgrey.svg?style=flat-square)](LICENSE)

👩🏻‍🚀 *This project [is still a tad experimental](#development-status). Contributors and pioneers welcome!*

## What?

LSPService is a local web service that allows editors to talk to any local [LSP language server](https://langserver.org) via [WebSocket](https://en.wikipedia.org/wiki/WebSocket):

![](Documentation/lspservice_idea_dark.png#gh-dark-mode-only)
![](Documentation/lspservice_idea_light.png#gh-light-mode-only)

LSPService is itself written in Swift and also mainly tested with the [Swift language server (sourcekit-lsp)](https://github.com/apple/sourcekit-lsp). **But in principle, LSPService can connect to all language servers and Linux support can easily be added in the future**.

The LSPService package itself comprises very little code because a) it heavily leverages [Vapor](https://github.com/vapor/vapor) and b) I extracted much of what it does into [SwiftLSP](https://github.com/codeface-io/SwiftLSP) and [FoundationToolz](https://github.com/flowtoolz/FoundationToolz).

## Why?

The [Language Server Protocol](https://microsoft.github.io/language-server-protocol/) is the present and future of software development tools. But leveraging it for a tool project turned out to be difficult. 

For instance, I distribute [a developer tool](https://apps.apple.com/app/codeface/id1578175415) via the Mac App Store, so it must be sandboxed, which makes it impossible to directly deal with language servers or any other "tooling" of the tech world.

So I thought: **What if a language server was simply a local web service?** Possible benefits:

* **Editors don't need to install, locate, launch, configure and talk to different language server executables.**
  * Today's tendency of each editor needing some sort of "extension" or "plugin" developed for each language in part defeats [the whole idea](https://langserver.org/) of the Language Server **Protocol**. LSPService aims to solve that by centralizing and abstracting away the low level issues involved in leveraging language servers.
* **macOS apps that require no other tooling except for LSP servers can be sandboxed and even be distributed via the App Store.**
* In the future, LSPService could be a machine's central place for managing and monitoring LSP language servers, possibly via a local web frontend.
* Even further down the road, running LSPService as an actual web service unlocks interesting possibilities for remote inspection and monitoring of code bases.

## How?

### First of All: How to Configure LSPService

`LSPService` creates an `LSPServiceConfig.json` file on launch if the file doesn't exist yet. If the file exists, it loads server configurations from the file.

A user or admin **should** configure `LSPService` by editing `LSPServiceConfig.json`. In the future, the config file that `LSPService` creates **will** already contain entries for selected installed language servers. Right now, that automatic detection only works for Swift.

### As the User of an Editor

1. Download and open `LSPService`. It will run in terminal, and as long as it's running there, the service is available. Check: <http://localhost:8080>
2. To add language servers, add corresponding entries to `LSPServiceConfig.json` and restart `LSPService`. The `LSPServiceConfig.json` file created by `LSPService` already contains at least one entry, and the JSON structure is quite self-explanatory.

### As the Developer of an Editor

1. Let your editor use LSPService:
  * [Make a WebSocket connection to LSPService](#Developing-an-Editor) for a specified language.
  * If you write the editor in Swift, you may use [LSPServiceKit](https://github.com/codeface-io/LSPServiceKit).
  * If you want to put your editor into the Mac App Store: Ensure it's also valuable without LSPService. This may help with the review process.
2. Provide downloads of the LSPService binaries (for Apple + Intel chips) to your users:
  * Either build them yourself:
    - `swift build --configuration release --arch arm64`
    - `swift build --configuration release --arch x86_64`
    - get them from `.build/<target architecture>/release/LSPService`
    - upload them somewhere ...
  * ... or just use the [download links](https://codeface.io/blog/posts/using-lsp-servers-in-codeface-via-lspservice/index.html) I provide for Codeface
3. Let your editor encourage users to download and run `LSPService`:
  * Succinctly describe which features LSPService unlocks.
  * Offer a link to a user friendly download page (or similar), like [this one](https://codeface.io/blog/posts/using-lsp-servers-in-codeface-via-lspservice/index.html).

## Developing an Editor

### Editor vs. LSPService – Who's Responsible?

The singular purpose of LSPService is to make local LSP language servers accessible via WebSockets.

LSPService forwards LSP messages from some editor (incoming via WebSockets) to some language server (outgoing to stdin) and vice versa. It knows nothing about the LSP standard itself (except for how to detect LSP packets in the output of language servers). Encoding and decoding LSP messages and generally representing LSP with proper types remains a concern of the editor. 

The editor, on the other hand, knows nothing about how to talk to-, locate and launch language servers. Those remain concerns of LSPService.

### The WebSocket

* See [LSPServiceKit](https://github.com/codeface-io/LSPServiceKit) as example code or use it directly if your client is written in Swift.

* LSPService has basically one endpoint. You connect to a websocket on it in order to talk to the language server associated with language `<lang>`: 

	```
	http://127.0.0.1:8080/lspservice/api/language/<lang>/websocket
	```

* Depending on the frameworks you use, you may need to set the URL scheme `ws://` explicitly.

* Encode LSP messages according to the LSP specification, including [header](https://microsoft.github.io/language-server-protocol/specifications/specification-current/#headerPart) and content part.

* Send and receive LSP messages via the data channel of the WebSocket. The data channel is used exclusively for LSP messages. It never outputs any other type of data. Each data message it puts out is one LSP packet (header + content), as LSPService pieces packets together from the language server output.

* [LSP response messages](https://microsoft.github.io/language-server-protocol/specifications/specification-current/#responseMessage) may inform about errors. These LSP errors are critical feedback for your editor.

* Besides LSP messages, there are only two ways the WebSocket gives live feedback:
	* It sends the language server's [error output](https://en.wikipedia.org/wiki/Standard_streams#Standard_error_(stderr)) via the text channel. These are unstructured pure text strings that are useful error logs for debugging.
	* It terminates the connection when some serious problem occured, for example when the language server in use had to shut down.

## Architecture

Here is the internal architecture (composition and [essential](https://en.wikipedia.org/wiki/Transitive_reduction#In_acyclic_directed_graphs) dependencies) of LSPService:

![](Documentation/architecture.png)

The above image was generated with [Codeface](https://codeface.io).

## Development Status

From version/tag 0.1.0 on, LSPService adheres to [semantic versioning](https://semver.org). So until it has reached 1.0.0, the REST API or setup mechanism may still break frequently, but this will be expressed in version bumps.

LSPService is already being used in production, but [Codeface](https://codeface.io) is still its primary client. LSPService will move to version 1.0.0 as soon as:

1. Basic practicality and conceptual soundness have been validated by serving multiple real-world clients.
2. LSPService has a versioning mechanism (see roadmap).

## To Do / Roadmap

* [x] Implement proof of concept with WebSockets and sourcekit-lsp

* [x] Have a dynamic endpoint for all languages, like `127.0.0.1:<service port>/lspservice/api/<language>`

* [x] Let LSPService locate sourcekit-lsp for the Swift endpoint

* [x] Evaluate whether client editors need to to receive the [error output](https://en.wikipedia.org/wiki/Standard_streams#Standard_error_(stderr)) from language server processes.
  
  * Result: LSP errors come as regular LSP messages from standard output, and using different streams is not part of the LSP standard and a totally different abstraction level anyway. So stdErr should be irrelevant to the editor. But for debugging, we provide it via the WebSocket's text channel.
  
* [x] Explore whether sourcekit-lsp can be adjusted to send error feedback when it fails to decode incoming data. This would likely accelerate development of LSPService and of other sourcekit-lsp clients.
  
  * Result: sourcekit-lsp [now sends an LSP error response message](https://github.com/apple/sourcekit-lsp/pull/334) in response to an undecodable message, if that message has at least a [valid header](https://microsoft.github.io/language-server-protocol/specifications/specification-current/#headerPart). Prepending that header is easy, so development of LSPService can now rely on immediate well formed feedback from sourcekit-lsp.
  
* [x] Add an endpoint for client editors to detect what languages are available

* [x] Properly handle websocket connection attempt for unavailable languages: send feedback, then close connection.

* [x] Lift logging and error handling up to the best practices of Vapor. Ensure that users launching the host app see all errors in the terminal, and that clients get proper error responses.

* [x] Allow to use multiple different language servers. Proof concept by supporting/testing a Python language server

* [x] Add a CLI so users can manage the list of language servers from the command line

* [x] Clean up interfaces: Future proof and rethink API structure, then align CLI, API and web frontend

* [x] Document how to use LSPService

* [x] Evaluate whether to build a Swift package that helps clients of LSPService (that are written in Swift) to define, encode and decode LSP messages. Consider suggesting to extract that type system from [SwiftLSPClient](https://github.com/chimehq/SwiftLSPClient) and/or from sourcekit-lsp into a dedicated package.
	* Result: Extraction already happened anyway in form of sourcekit-lsp's static library product `LSPBindings`. However, `LSPBindings` didn't work for decoding as it's decoding is entangled with matching requests to responses.
	* Result: [SwiftLSPClient](https://github.com/chimehq/SwiftLSPClient)'s type system is incomplete and obviously not backed by Apple.
	* Result: The idea to strictly type LSP messages down to every property seems inappropriate for their amorphous "free value" nature anyway. So we opt for a custom, simpler and more dynamic LSP type system (now as [SwiftLSP](https://github.com/codeface-io/SwiftLSP)).
	
* [x] Get a sourcekit-lsp client project to function with sourcekit-lsp at all, before moving on with LSPService

* [x] Remove "Process ID injection". Add endpoint that provides process ID.

* [x] Detect LSP packets properly (piece them together from server process output)

* [x] Extract general LSP type system (not LSPService specific) into package [SwiftLSP](https://github.com/codeface-io/SwiftLSP)

* [x] Build a Swift package that helps client editors written in Swift to use LSPService: [LSPServiceKit](https://github.com/codeface-io/LSPServiceKit)

* [x] Get "find references" request to work via LSPService

* [x] Add [trouble shooting guide](Documentation/build_a_sourcekit-lsp_client.md) for client developers to sourcekit-lsp repo (from the insights gained developing LSPService and SwiftLSP)

* [x] Replace CLI with a json file, which defines server paths, arguments and environment variables. This also makes a web frontend unnecessary for mere configuration, adds persistency and bumps usability ...

* [x] Adjust API and documentation: Remove all routes except for ProcessID and websocket. If we provide a configuration API at all in the future, it will be based on a proper language config type / JSON.

* [x] Fix this: Clients (at least Codeface) lose websocket connection to LSPService on large Swift packages like sourcekit-lsp itself. Are some LSP messages too large to be sent in one chunk via websockets?

* [x] Since [this PR](https://github.com/vapor/vapor/pull/2498) is done: Decline upgrade to Websocket protocol right away for unavailable languages, instead of opening the connection, sending feedback and then closing it again.

* [x] Adjust LSPServiceKit to the radically pruned API ...

* [x] **MILESTONE** "Releasability": review code and error logs, versioning, upload binaries for Intel and Apple chips ... 

* [x] Explore whether an app that effectively requires LSPService would pass the Mac App Store review.
  
* Result: [it does](https://apps.apple.com/app/codeface/id1578175415) 🥳. The second update was also accepted with full on promotion of features that depend on LSPService, but still referencing LSPService only from within the app.
  
* [x] Research: There are new indications we might be able to launch LSP servers from the sandbox via XPC afterall. This would delight users (of [Codeface](https://codeface.io)) and add a whole new technical pathway (and package product) to LSPService.
    * Result: No success. It seems to be impossible, so we stick to LSPService and WebSockets.

* [ ] 🐍 Experiment again with python language servers (and get one to work)

* [ ] 🐣 Make LSPService independent of LSP and turn it into a service that allows any app to use any local commands and tools.

* [ ] ✍🏻 Sign/notarize LSPService so it's easier to install and trust

* [ ] 🔢 Add a versioning mechanism that allows developing LSPService while multiple editors/clients depend on it. This may need to involve:
  * The REST API provides available versions via a GET request
  * The REST API includes explicit version numbers in its endpoint URLs
  * LSPService outputs its version on launch
  * Downloadable binaries somehow indicate their version
  * Codeface (as proof of concept by the pioneering client) can handle an outdated LSPService

* [ ] 📢 Get this project out there: documentation, promo, collaboration, contact potential client apps etc. ...

* [ ] Ensure sourcekit-lsp can be used to support C, C++ and Objective-c 

* [ ] What about clients which can't be released in the app store anyway and want the LSPService functionality as an imported Swift package rather than a local webservice? This may require moving more functionality to SwiftLSP and defining a precise boundary/abstraction for it.

### Rather Optional Stuff (Backlog)

* [ ] What about building / running LSPService on Linux? LSPService and SwiftLSP depend on Foundation, maybe compiler directives are needed or generally sticking to [this](https://github.com/apple/swift-corelibs-foundation).

* [ ] What about multiple clients who need services for the same language at the same time?
