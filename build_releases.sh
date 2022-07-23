swift build --configuration release --arch arm64
cp .build/arm64-apple-macosx/release/LSPService ../flowtoolz.github.io/codeface/lspservice/binaries/arm64-apple-macosx/LSPService

swift build --configuration release --arch x86_64
cp .build/x86_64-apple-macosx/release/LSPService ../flowtoolz.github.io/codeface/lspservice/binaries/x86_64-apple-macosx/LSPService
