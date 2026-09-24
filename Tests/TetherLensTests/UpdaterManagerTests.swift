import Testing
import Foundation
@testable import TetherLens

@Suite struct UpdaterManagerTests {

    @Test func 리다이렉트URL에서_태그추출() {
        let url = URL(string: "https://github.com/BoraSarang/TetherLens/releases/tag/v0.38.0")!
        #expect(GitHubReleaseParser.tag(fromReleaseURL: url) == "v0.38.0")
    }

    @Test func 태그없는URL은_nil() {
        #expect(GitHubReleaseParser.tag(fromReleaseURL: URL(string: "https://github.com/BoraSarang/TetherLens/releases")!) == nil)
        #expect(GitHubReleaseParser.tag(fromReleaseURL: URL(string: "https://example.com/")!) == nil)
    }

    @Test func 버전비교_숫자기준() {
        #expect(GitHubReleaseParser.isNewerVersion("v0.39.0", current: "0.38.0"))
        #expect(GitHubReleaseParser.isNewerVersion("0.38.1", current: "0.38.0"))
        #expect(!GitHubReleaseParser.isNewerVersion("v0.38.0", current: "0.38.0"))
        #expect(!GitHubReleaseParser.isNewerVersion("v0.37.0", current: "0.38.0"))
        #expect(!GitHubReleaseParser.isNewerVersion("v0.9.0", current: "0.38.0"))
        #expect(GitHubReleaseParser.isNewerVersion("v1.0.0", current: "0.38.0"))
    }

    @Test func atom에서_해당태그_본문추출() {
        let atom = """
        <?xml version="1.0"?>
        <feed>
          <entry>
            <id>tag:v0.37.0</id>
            <link href="https://github.com/BoraSarang/TetherLens/releases/tag/v0.37.0"/>
            <content type="html">&lt;p&gt;old&lt;/p&gt;</content>
          </entry>
          <entry>
            <id>tag:v0.38.0</id>
            <link href="https://github.com/BoraSarang/TetherLens/releases/tag/v0.38.0"/>
            <content type="html">&lt;h2&gt;주요 변경&lt;/h2&gt;&lt;ul&gt;&lt;li&gt;알림 해소&lt;/li&gt;&lt;/ul&gt;</content>
          </entry>
        </feed>
        """
        let body = GitHubReleaseParser.atomBody(forTag: "v0.38.0", in: atom)
        #expect(body != nil)
        #expect(body?.contains("<h2>주요 변경</h2>") == true)
        #expect(body?.contains("알림 해소") == true)
        #expect(GitHubReleaseParser.atomBody(forTag: "v9.9.9", in: atom) == nil)
    }

    @Test func HTML_엔티티_언에스케이프() {
        #expect(GitHubReleaseParser.unescapeHTML("&lt;b&gt;x&lt;/b&gt; &amp; y") == "<b>x</b> & y")
        #expect(GitHubReleaseParser.unescapeHTML("&quot;q&quot; &#39;a&#39;") == "\"q\" 'a'")
    }
}
