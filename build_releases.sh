swift build --configuration release --arch arm64
zip -j ../flowtoolz.github.io/codeface/lspservice/binaries/arm64-apple-macosx/LSPService.zip .build/arm64-apple-macosx/release/LSPService


swift build --configuration release --arch x86_64
zip -j ../flowtoolz.github.io/codeface/lspservice/binaries/x86_64-apple-macosx/LSPService.zip .build/x86_64-apple-macosx/release/LSPService
