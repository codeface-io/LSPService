# Language Service Host

🚨 *This project is at an early experimental stage.*

👩🏻‍🚀 *Contributors and pioneers welcome!*

## What?

The Language Service Host (LSH) is an app that locally hosts a web service (the "Language Service") which then allows editors and IDEs to use local [LSP language servers](https://langserver.org) simply via WebSockets.

![LanguageServiceHost](https://raw.githubusercontent.com/flowtoolz/LanguageServiceHost/master/Documentation/language_service_host_idea.jpg)

## Why?

The [Language Server Protocol](https://microsoft.github.io/language-server-protocol/) is the present and future of software development tools. But leveraging it for my own tool project turned out to be more difficult than expected. 

Most of all, I want to distribute my tool via the Mac App Store, so it must be sandboxed, which makes it impossible to deal with language servers directly or with any other "tooling" of the tech world.

So I thought: What if a language server was simply a local web service? Possible benefits:

* **On macOS, editors can be sandboxed and probably even be distributed via the App Store.**
* **Editors don't need to locate, install, run and talk to language servers.**
* In the future, the Language Service could be a machine's central place for managing LSP language servers, through a CLI and/or through a web front end.
* Even further down the road, running the Language Service on actual web servers might have interesting applications, in particular where LSP is used for static code analysis or remote inspection.

## How?

### As the Developer of an Editor

1. Let your editor use the Language Service API:
	* [The API](#API) allows talking to language servers and configuring them.
	* If you want to put your editor into the Mac App Store: Ensure your editor is also usable without the LSH. This should help with the review process.
2. Provide a download of the LSH to your users:
	* Build it via `swift build --configuration release`.
	* Get the resulting binary from `.build/<target architecture>/release/LanguageServiceHost`.
	* Upload the binary to where your users should download it.
3. Let your editor encourage the user to download and run the LSH:
	* Give a short explanation for why the LSH is helpful.
	* Offer a convenient way to download and save the LSH.

### As the User of an Editor

Of course, we assume here the editor supports the Language Service.

1. Download and open the LSH app. It's named "LanguageServiceHost". It will run in Terminal, and as long as it's running there, the Language Service is available.
2. Check that the Language Service is indeed available: Open <http://localhost:8080/languageservice>.
3. Set the language server locations (file paths) for the languages you want to have supported. 
	* There's a command line interface for that. After the LSH starts running in Terminal, the Language Service explains its commands there.
	* The Language Service automatically locates the Swift language server (if Xcode is installed) and it guesses the location of a [python language server](https://github.com/palantir/python-language-server). But in general, users still have to locate their language servers manually.


## API

### Editor vs. Language Service – Who's Responsible?

The singular purpose of the Language Service is to present LSP language servers as simple WebSockets.

The Language Service forwards LSP messages from some editor to some language server and vice versa. It knows nothing about the LSP standard itself. Encoding and decoding LSP messages and generally representing LSP with proper types remains a concern of the editor. 

The editor, on the other hand, knows nothing about how to locate, install, run and talk to language servers. This remains a concern of the Language Service.

This is the intended separation of concerns. Compromises may be necessary here and there, in particular in this early stage of the project.

### Endpoints

The root of the Language Service API is `http://127.0.0.1:8080/languageservice/api/`.

| URL Path |     Types     |      Methods | Usage |
| :------------ | :---------- | :---------- |:----------- |
| `languages` | `[String]` | `GET` | Get names of available languages. An available language is one for which the path of the associated language server is set. |
| `language/<lang>` | `String` | `GET`, `POST` | Get and set the path of the language server associated with language "lang". |
| `language/<lang>/websocket` | `String`, `Data` | WebSocket | Connect and talk to the language server associated with language "lang". |

### Using the WebSocket

Depending on the frameworks you use, you may need to set the URL scheme `ws://` explicitly.

Encode LSP messages according to the LSP specification, including [header](https://microsoft.github.io/language-server-protocol/specifications/specification-current/#headerPart) and content part.

Send and receive LSP messages via the data channel of the WebSocket. The data channel is used exclusively for LSP messages. It never outputs any other type of data.

The LSP standard also specifies errors, and LSP messages can contain these errors. These "LSP error messages" are critical feedback for your editor. The language service may also at some point send its own errors in the form of LSP messages where appropriate, so editors can handle these errors in the same systematic way.

Besides LSP messages, there are only two ways the WebSocket gives live feedback:

* It sends log messages via its text channel. These are unstructured pure text strings that are useful for debugging. 
* It terminates the connection if some serious problem occured, for example if the language server in use had to shut down.

## To Do

* [x] Implement proof of concept with WebSockets and `sourcekit-lsp`
* [x] Let the Language Service locate `sourcekit-lsp` for the Swift endpoint
* [x] Have a dynamic endpoint for all languages, like `ws://127.0.0.1:<service port>/languageservice/api/<language>`
* [x] Evaluate whether client editors need to to receive the [error output](https://en.wikipedia.org/wiki/Standard_streams#Standard_error_(stderr)) from language server processes.
  * Result: LSP errors come as regular LSP messages from standard output, and using different streams is not part of the LSP standard and a totally different abstraction level anyway. So stdErr should be irrelevant to the editor.
* [x] Explore whether `sourcekit-lsp` can be adjusted to send error feedback when it fails to decode incoming data. This would likely accelerate development of  `sourcekit-lsp` clients, whether they use `sourcekit-lsp` directly or via this Language Service.
  * Result: sourcekit-lsp [now sends an LSP error response message](https://github.com/apple/sourcekit-lsp/pull/334) if the message it receives has at least a [valid header](https://microsoft.github.io/language-server-protocol/specifications/specification-current/#headerPart). Prepending that header is easy, so all development can now rely on immediate well formed feedback.
* [x] Add an endpoint for client editors to detect what languages are available
* [x] Properly handle websocket connection attempt for unavailable languages: send feedback, then close connection.
* [x] Lift logging and error handling up to the best practices of Vapor. Ensure that users launching the host app see all errors in the terminal, and that clients get proper error responses.
* [x] Allow to use multiple different language servers. Proof concept by supporting/testing a Python language server
* [x] Add a CLI for the host app so users can manage the list of language servers from the command line
* [x] Clean up interfaces: Future proof and rethink API structure, then align structure of CLI to API
* [x] Document how to use the LSH
* [x] Evaluate whether to build a Swift package to help LSH client editors written in Swift to define, encode and decode LSP messages. Consider suggesting to extract that type system from [SwiftLSPClient](https://github.com/chimehq/SwiftLSPClient) and/or from sourcekit-lsp into a dedicated package. Both use a similar typesystem for that already ...
	* Result: Building it is too big of a task but extraction already happened anyway: Such editors can use the static library product `LSPBindings` of the sourcekit-lsp package, assuming `LSPBindings` doesn't reach out of the app sandbox. It's unclear why [SwiftLSPClient](https://github.com/chimehq/SwiftLSPClient) reimplemented all that ...
* [ ] Add support for C, C++ and Objective-c via `sourcekit-lsp`
* [ ] As soon as [this PR](https://github.com/vapor/vapor/pull/2498) is done: Decline upgrade to Websocket protocol right away for unavailable languages, instead of opening the connection, sending feedback and then closing it again.
* [ ] Consider adding a web frontend for managing language servers. Possibly use [Plot](https://github.com/JohnSundell/Plot)
* [ ] Possibly build a Swift package that helps client editors written in Swift to use the Language Service
* [ ] Enable serving multiple clients who need services for the same language at the same time
* [ ] Explore whether this approach would actually fly with the Mac App Store review, because:
  * The editor app would need to encourage the user to download and install the Language Service Host, but apps in the App Store are not allowed to lead the user to some website, at least as it relates to purchase funnels.
  * The Language Service Host is not really a web API. And it could be argued that it is more of a plugin that effects the behaviour of the editor app, which would break App Store rules.
