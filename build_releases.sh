swift build --configuration release --arch arm64
cp .build/arm64-apple-macosx/release/LSPService Binaries/arm64-apple-macosx/LSPService

swift build --configuration release --arch x86_64
cp .build/x86_64-apple-macosx/release/LSPService Binaries/x86_64-apple-macosx/LSPService