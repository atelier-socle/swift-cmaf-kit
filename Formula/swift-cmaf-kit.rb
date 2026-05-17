class SwiftCmafKit < Formula
  desc "CLI for pure-Swift ISOBMFF / CMAF / CENC inspection and validation"
  homepage "https://github.com/atelier-socle/swift-cmaf-kit"
  url "https://github.com/atelier-socle/swift-cmaf-kit/archive/refs/tags/0.1.0.tar.gz"
  sha256 "REPLACE_AT_RELEASE"
  license "Apache-2.0"
  head "https://github.com/atelier-socle/swift-cmaf-kit.git", branch: "main"

  depends_on xcode: ["15.0", :build]
  depends_on macos: :sonoma

  def install
    system "swift", "build",
           "-c", "release",
           "--disable-sandbox",
           "--product", "cmafkit-cli"
    bin.install ".build/release/cmafkit-cli"
  end

  test do
    assert_match "cmafkit-cli", shell_output("#{bin}/cmafkit-cli --help")
  end
end
