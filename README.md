# LSPService

🚨 *This project already serves clients but is not mature enough yet to warrant versioning.*

👩🏻‍🚀 *Contributors and pioneers welcome!*

## What?

LSPService is a local web service that allows editors to talk to any local [LSP language server](https://langserver.org) via [WebSocket](https://en.wikipedia.org/wiki/WebSocket):

![LSPService](https://raw.githubusercontent.com/flowtoolz/LSPService/master/Documentation/lspservice_idea.jpg)

I use mainly the [Swift language server (sourcekit-lsp)](https://github.com/apple/sourcekit-lsp) as my example language server, and LSPService is itself written in Swift. **But in principle, LSPService runs on macOS and Linux and can connect to all language servers**. 

## Why?

The [Language Server Protocol](https://microsoft.github.io/language-server-protocol/) is the present and future of software development tools. But leveraging it for a tool project turned out to be difficult. 

For instance, I want to distribute a developer tool via the Mac App Store, so it must be sandboxed, which makes it impossible to directly deal with language servers or any other "tooling" of the tech world.

So I thought: **What if a language server was simply a local web service?** Possible benefits:

* **Editors don't need to install, locate, launch, configure and talk to different language server executables.**
  * Today's tendency of each editor needing some sort of "extension" or "plugin" developed for each language in part defeats [the whole idea](https://langserver.org/) of the Language Server **Protocol**. LSPService aims to solve that by centralizing and abstracting away the low level issues involved in leveraging language servers.
* **On macOS, editors can be sandboxed and probably even be distributed via the App Store.**
* In the future, LSPService could be a machine's central place for managing and monitoring LSP language servers, possibly via a local web frontend.
* Even further down the road, running LSPService as an actual web service might have interesting applications, in particular where LSP is used for static code analysis or remote inspection.

## How?

### First of All: Who Shall Configure LSPService?

`LSPService` creates an `LSPServiceConfig.json` file on launch if the file doesn't exist yet. If the file exists, it loads server configurations from the file.

A user or admin **should** configure `LSPService` by editing `LSPServiceConfig.json`. In the future, the config file that `LSPService` creates **will** already contain entries for selected installed language servers. Right now, that automatic detection only works for Swift.

### As the Developer of an Editor

1. Let your editor use LSPService:
	* [The API](#API) allows connecting to a language server via WebSocket.
	* If you write the editor in Swift, you may use [LSPServiceKit](https://github.com/flowtoolz/LSPServiceKit).
	* If you want to put your editor into the Mac App Store: Ensure it's also usable without LSPService. This should help with the review process.
2. Provide a download of LSPService to your users:
	* Build it via `swift build --configuration release`.
	* Get the resulting binary: `.build/<target architecture>/release/LSPService`.
	* Upload the binary so users can download it.
3. Let your editor encourage users to download and run `LSPService`:
	* Succinctly describe which features LSPService unlocks.
	* Offer a link to a user friendly download page (or similar).

### As the User of an Editor

Of course, we assume here the editor supports LSPService.

1. Download and open `LSPService`. It will run in terminal, and as long as it's running there, the service is available. Check: <http://localhost:8080/lspservice>
2.  To add language servers, add corresponding entries to `LSPServiceConfig.json` and restart `LSPService`.

## API

### Editor vs. LSPService – Who's Responsible?

The singular purpose of LSPService is to make local LSP language servers accessible via WebSockets.

LSPService forwards LSP messages from some editor (incoming via WebSockets) to some language server (outgoing to stdin) and vice versa. It knows nothing about the LSP standard itself (except for how to detect LSP packets in the output of language servers). Encoding and decoding LSP messages and generally representing LSP with proper types remains a concern of the editor. 

The editor, on the other hand, knows nothing about how to talk to-, locate and launch language servers. Those remain concerns of LSPService.

### Endpoints

The root of the LSPService API is `http://127.0.0.1:8080/lspservice/api/`.

| URL Path |     Types     |      Methods | Usage |
| :------------ | :---------- | :---------- |:----------- |
| `processID` | `Int` | `GET` | Get process ID of LSPService, to set it in the [LSP initialize request](https://microsoft.github.io/language-server-protocol/specification#initialize). |
| `language/<lang>/websocket` | `Data`, `String` | WebSocket | Connect and talk to the language server associated with language `<lang>`. |

### Using the WebSocket

* Depending on the frameworks you use, you may need to set the URL scheme `ws://` explicitly.

* Encode LSP messages according to the LSP specification, including [header](https://microsoft.github.io/language-server-protocol/specifications/specification-current/#headerPart) and content part.

* Send and receive LSP messages via the data channel of the WebSocket. The data channel is used exclusively for LSP messages. It never outputs any other type of data. Each data message it puts out is one LSP packet (header + content), as LSPService pieces packets together from the language server output.

* [LSP response messages](https://microsoft.github.io/language-server-protocol/specifications/specification-current/#responseMessage) may inform about errors. These LSP errors are critical feedback for your editor.

* Besides LSP messages, there are only two ways the WebSocket gives live feedback:
	* It sends the language server's [error output](https://en.wikipedia.org/wiki/Standard_streams#Standard_error_(stderr)) via the text channel. These are unstructured pure text strings that are useful error logs for debugging.
	* It terminates the connection when some serious problem occured, for example when the language server in use had to shut down.

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
	* Result: The idea to strictly type LSP messages down to every property seems inappropriate for their amorphous "free value" nature anyway. So we opt for a custom, simpler and more dynamic LSP type system (now as [SwiftLSP](https://github.com/flowtoolz/SwiftLSP)).
* [x] Get a sourcekit-lsp client project to function with sourcekit-lsp at all, before moving on with LSPService
* [x] Remove "Process ID injection". Add endpoint that provides process ID.
* [x] Detect LSP packets properly (piece them together from server process output)
* [x] Extract general LSP type system (not LSPService specific) into package [SwiftLSP](https://github.com/flowtoolz/SwiftLSP)
* [x] Build a Swift package that helps client editors written in Swift to use LSPService: [LSPServiceKit](https://github.com/flowtoolz/LSPServiceKit)
* [x]     Get "find references" request to work via LSPService
* [x] Add [trouble shooting guide](Documentation/build_a_sourcekit-lsp_client.md) for client developers to sourcekit-lsp repo (from the insights gained developing LSPService and SwiftLSP)
* [x] Replace CLI with a json file, which defines server paths, arguments and environment variables. This also makes a web frontend unnecessary for mere configuration, adds persistency and bumps usability ...
* [x] Adjust API and documentation: Remove all routes except for ProcessID and websocket. If we provide a configuration API at all in the future, it will be based on a proper language config type / JSON.
* [x] Fix this: Clients (at least Codeface) lose websocket connection to LSPService on large Swift packages like sourcekit-lsp itself. Are some LSP messages too large to be sent in one chunk via websockets?
* [ ] 💎 **MILESTONE** "Releasability": failure tolerance, expressive error logs, versioning, upload binaries for Intel and Apple chips ... 
* [ ] 🍏 Explore whether an editor app that kind of requires LSPService would actually pass the Mac App Store review.
* [ ] 🗑 Adjust LSPServiceKit to the radically pruned new API ...
* [ ] Since [this PR](https://github.com/vapor/vapor/pull/2498) is done: Decline upgrade to Websocket protocol right away for unavailable languages, instead of opening the connection, sending feedback and then closing it again.
* [ ] 🐍 Experiment again with python language servers (and get one to work)
* [ ] 📢 Get this project out there: documentation, promo, collaboration, contact potential client apps etc. ...
* [ ] Ensure sourcekit-lsp can be used to support C, C++ and Objective-c 
* [ ] Make the web frontend fully equivalent to the CLI and also pretty. Possibly use [Plot](https://github.com/JohnSundell/Plot)
* [ ] What about clients which can't be released in the app store anyway and want to use LSPService as an imported Swift package rather than a local webservice? This requires moving more functionality to SwiftLSP and defining a precise boundary/abstraction for it.
* [ ] What about building / running LSPService on Linux? LSPService and SwiftLSP depend on Foundation, maybe compiler directives are needed or generally sticking to [this](https://github.com/apple/swift-corelibs-foundation).
* [ ] What about multiple clients who need services for the same language at the same time?
