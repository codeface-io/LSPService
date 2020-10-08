# Language Service Host

## What?

A web server for hosting a "language service" locally. The service then allows to access local [LSP](https://microsoft.github.io/language-server-protocol/) language servers via an HTTP REST API and/or websockets:

![LanguageServiceHost](https://raw.githubusercontent.com/flowtoolz/LanguageServiceHost/master/Documentation/language_service_host_idea.jpg)

## Why?

To decouple editors (IDEs) from the language servers. Possible benefits:

* **Editors can be sandboxed and (hopefully) even be distributed via the Mac App Store.**
* In the future, the Language Service Host could be a machine's central place for locating, installing and running LSP language servers, which is something each editor still has to do by itself right now.
* Even further ahead, running the Language Service as a remote web service might have some interesting applications where LSP is just used for static code analysis rather than code editing.

## How?

The singular purpose of the Language Service is to forward LSP messages from some editor to some LSP language server and vice versa. HTTP here is just a means of data transport. The Language Service API will ideally know nothing about the LSP standard itself. Encoding LSP messages and generally representing LSP with proper types in the editor's programming language remains a concern of- and in control of the editor.

The project is written in Swift using [Vapor](https://github.com/vapor/vapor), but it's really just an experimental seed right now. I've never done any backend development and have finally just figured out how to talk to [`sourcekit-lsp`](https://github.com/apple/sourcekit-lsp). I appreciate any advice and help! 🙏🏻

## To Do

* Ensure this approach would actually fly with the Mac App Store review, because:
  * The editor would need to encourage the user to download and install the Language Service Host, but apps in the App Store are not allowed to lead the user to some website, at least as it relates to purchase funnels.
  * The Language Service Host is not really a web API. And it could be argued that it is more of a plugin that effects the behaviour of the editor app, which would break App Store rules.
* Implement the API. Use websockets because:
  * Mapping responses to requests requires decoding messages to get their ID, which remains a concern of the client.
  * Language servers also send more "spontaneous" messages/notifications in addition to direct request responses.
* Allow to manage multiple language servers. It is thinkable to have an endpoint for each language, like `http://127.0.0.1:<service port>/<language>` or to encode the language in the request, or as a URL parameter. The client editor should be able to ask what languages are available.
* Enable serving multiple clients who need services for the same language at the same time

