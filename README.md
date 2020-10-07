# LanguageServiceHost

A web server for hosting a "language service" locally. The service then provides access to [LSP](https://microsoft.github.io/language-server-protocol/) language servers via HTTP:

![LanguageServiceHost](https://raw.githubusercontent.com/flowtoolz/LanguageServiceHost/master/Documentation/language service host idea.jpg)

It's supposed to be written in Swift using [Vapor](https://github.com/vapor/vapor). And it's just an idea right now. I haven't even figured out how to talk to a language server executable like [`sourcekit-lsp`](https://github.com/apple/sourcekit-lsp). If you wanna help, have a look at `testSourceKitLSP()` in `configure.swift` and adjust the executable path.