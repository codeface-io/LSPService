# Language Service Host

A web server for hosting a "language service" locally. The service then allows to access [LSP](https://microsoft.github.io/language-server-protocol/) language servers via an HTTP REST API:

![LanguageServiceHost](https://raw.githubusercontent.com/flowtoolz/LanguageServiceHost/master/Documentation/language_service_host_idea.jpg)

It's written in Swift using [Vapor](https://github.com/vapor/vapor), but it's just an idea right now. I haven't even figured out how to talk to a language server executable like [`sourcekit-lsp`](https://github.com/apple/sourcekit-lsp). If you wanna help, have a look at `Sources/LanguageService/routes.swift`.