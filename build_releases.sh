#! /bin/zsh

swift build --configuration release --arch arm64
zip -j ../codeface-io.github.io/lspservice/binaries/arm64-apple-macosx/LSPService.zip .build/arm64-apple-macosx/release/LSPService

swift build --configuration release --arch x86_64
zip -j ../codeface-io.github.io/lspservice/binaries/x86_64-apple-macosx/LSPService.zip .build/x86_64-apple-macosx/release/LSPService
