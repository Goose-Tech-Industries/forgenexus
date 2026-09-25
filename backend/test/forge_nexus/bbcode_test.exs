defmodule ForgeNexus.BBCodeTest do
  use ExUnit.Case, async: true

  alias ForgeNexus.BBCode

  describe "Section 1A: BBCode formatting & syntax tags" do
    test "converts basic formatting tags [b], [i], [u], [s]" do
      input = "[b]Bold[/b] [i]Italic[/i] [u]Underline[/u] [s]Strike[/s]"
      output = BBCode.to_html(input)

      assert output =~ "<strong>Bold</strong>"
      assert output =~ "<em>Italic</em>"
      assert output =~ "<u>Underline</u>"
      assert output =~ "<s>Strike</s>"
    end

    test "converts headings [h1], [h2], [h3] and horizontal rule [hr]" do
      input = "[h1]Title[/h1]\n[h2]Subtitle[/h2]\n[hr]"
      output = BBCode.to_html(input)

      assert output =~ "<h1>Title</h1>"
      assert output =~ "<h2>Subtitle</h2>"
      assert output =~ "<hr class=\"bbcode-hr\" />"
    end

    test "converts text alignments [center], [left], [right], [align=justify]" do
      input = "[center]Centered[/center] [right]Right[/right] [align=justify]Justified[/align]"
      output = BBCode.to_html(input)

      assert output =~ ~s(<div style="text-align:center">Centered</div>)
      assert output =~ ~s(<div style="text-align:right">Right</div>)
      assert output =~ ~s(<div style="text-align:justify">Justified</div>)
    end

    test "converts colors and font sizes safely" do
      input = "[color=#00ff00]Green[/color] and [size=4]Large[/size]"
      output = BBCode.to_html(input)

      assert output =~ ~s(<span style="color:#00ff00">Green</span>)
      assert output =~ ~s(<span style="font-size:1.2em">Large</span>)
    end

    test "converts quotes with and without author citations" do
      input = "[quote]Anonymous quote[/quote]\n[quote=Admin]Staff quote[/quote]"
      output = BBCode.to_html(input)

      assert output =~ ~s(<blockquote class="bbcode-quote">Anonymous quote</blockquote>)

      assert output =~
               ~s(<blockquote class="bbcode-quote"><cite>Admin wrote:</cite>Staff quote</blockquote>)
    end

    test "converts spoilers and code blocks" do
      input = "[spoiler=Secret]Top Secret[/spoiler] [code]let x = 1;[/code]"
      output = BBCode.to_html(input)

      assert output =~ ~s(Click to reveal: Secret)
      assert output =~ ~s(Top Secret)
      assert output =~ ~s(<pre class="bbcode-code"><code>let x = 1;</code></pre>)
    end

    test "converts user mentions and thread links" do
      input = "Hey [user]testuser[/user], check out [thread]awesome-thread[/thread]!"
      output = BBCode.to_html(input)

      assert output =~ ~s(<a href="/profile/testuser" class="bbcode-mention">@testuser</a>)

      assert output =~
               ~s(<a href="/threads/awesome-thread" class="bbcode-link">awesome-thread</a>)
    end

    test "neutralizes XSS script tags and attribute injections" do
      input = "<script>alert('xss')</script> and <img src=x onerror=alert(1)>"
      output = BBCode.to_html(input)

      refute output =~ "<script>"
      refute output =~ "<img "
      assert output =~ "&lt;script&gt;alert(&#39;xss&#39;)&lt;/script&gt;"
      assert output =~ "&lt;img src=x onerror=alert(1)&gt;"
    end
  end

  describe "Section 1A: Smilies Conversion Engine" do
    test "converts classic smilie codes into forum-smilie HTML spans" do
      input = "Hello world :smile: check this out :biggrin:"
      output = BBCode.to_html(input)

      assert output =~ ~s(<span class="forum-smilie" title=":smile:">😊</span>)
      assert output =~ ~s(<span class="forum-smilie" title=":biggrin:">😀</span>)
      assert output =~ "Hello world"
    end

    test "converts classic rolleyes and cool smilies" do
      input = "Whatever :rolleyes: stay :cool:"
      output = BBCode.to_html(input)

      assert output =~ ~s(<span class="forum-smilie" title=":rolleyes:">🙄</span>)
      assert output =~ ~s(<span class="forum-smilie" title=":cool:">😎</span>)
    end

    test "preserves normal bbcode alongside smilies" do
      input = "[b]Bold text[/b] and :thumbsup:"
      output = BBCode.to_html(input)

      assert output =~ "<strong>Bold text</strong>"
      assert output =~ ~s(<span class="forum-smilie" title=":thumbsup:">👍</span>)
    end

    test "handles nil and empty strings safely" do
      assert BBCode.to_html(nil) == ""
      assert BBCode.to_html("") == ""
    end
  end
end
