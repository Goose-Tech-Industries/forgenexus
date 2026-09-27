defmodule ForgeNexus.Profiles.CssSanitizerTest do
  use ExUnit.Case, async: true

  alias ForgeNexus.Profiles.CssSanitizer

  describe "sanitize/1" do
    test "returns empty string for nil or empty string" do
      assert {:ok, ""} = CssSanitizer.sanitize(nil)
      assert {:ok, ""} = CssSanitizer.sanitize("")
    end

    test "rejects blocked values and unsafe expressions" do
      unsafe_inputs = [
        "body { width: expression(alert(1)); }",
        "a { background-image: url('javascript:alert(1)'); }",
        "div { behavior: url(vbscript:something); }",
        "img { background: url('data:image/svg+xml,...'); }",
        "p { -moz-binding: url('http://evil.com/xbl'); }"
      ]

      for input <- unsafe_inputs do
        assert {:error, msg} = CssSanitizer.sanitize(input)
        assert msg =~ "CSS contains blocked content"
      end
    end

    test "removes @at-rules: @import, @charset, and @font-face" do
      css = """
      @charset "UTF-8";
      @import url("https://evil.com/style.css");
      @font-face {
        font-family: 'HackerFont';
        src: url('https://evil.com/font.woff');
      }
      .my-class { color: red; }
      """

      assert {:ok, sanitized} = CssSanitizer.sanitize(css)
      refute sanitized =~ "@charset"
      refute sanitized =~ "@import"
      refute sanitized =~ "@font-face"
      assert sanitized =~ ".profile-custom .my-class"
      assert sanitized =~ "color: red;"
    end

    test "scopes selectors properly and preserves existing .profile-custom prefix" do
      css = """
      h1, h2 { color: blue; }
      .profile-custom .already-scoped { font-weight: bold; }
      { margin: 0; }
      """

      assert {:ok, sanitized} = CssSanitizer.sanitize(css)
      assert sanitized =~ ".profile-custom h1, .profile-custom h2 {"
      assert sanitized =~ ".profile-custom .already-scoped {"
    end

    test "strips blocked properties: position, z-index, pointer-events, cursor" do
      css = """
      .box {
        position: fixed;
        z-index: 9999;
        pointer-events: none;
        cursor: crosshair;
        background-color: #f0f0f0;
        border-radius: 4px;
      }
      """

      assert {:ok, sanitized} = CssSanitizer.sanitize(css)
      refute sanitized =~ "position"
      refute sanitized =~ "z-index"
      refute sanitized =~ "pointer-events"
      refute sanitized =~ "cursor"
      assert sanitized =~ "background-color: #f0f0f0;"
      assert sanitized =~ "border-radius: 4px;"
    end

    test "slices input longer than 50_000 characters" do
      long_comment = String.duplicate("/* padding */ ", 4000)
      css = long_comment <> " .title { color: green; }"
      assert byte_size(css) > 50_000

      assert {:ok, sanitized} = CssSanitizer.sanitize(css)
      assert is_binary(sanitized)
    end
  end
end
