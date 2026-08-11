defmodule ForgeNexus.BBCode do
  @moduledoc """
  Server-side BBCode-to-HTML converter.
  Supports a safe subset: [b], [i], [u], [s], [color], [size], [url], [img], [quote], [code], [list], [*].
  Also loads admin-defined custom BBCode tags from the database.
  Input is HTML-escaped first, then BBCode tags are converted.
  """

  @doc """
  Converts BBCode text to safe HTML.
  """
  def to_html(nil), do: ""
  def to_html(""), do: ""

  def to_html(text) do
    text
    |> escape_html()
    |> convert_bbcode()
    |> apply_custom_bbcodes()
    |> String.trim()
  end

  defp escape_html(text) do
    text
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
    |> String.replace("'", "&#39;")
  end

  defp convert_bbcode(text) do
    text
    # Simple formatting
    |> replace_tag("b", "strong")
    |> replace_tag("i", "em")
    |> replace_tag("u", "u")
    |> replace_tag("s", "s")
    # Headings + alignment + horizontal rule
    |> replace_tag("h1", "h1")
    |> replace_tag("h2", "h2")
    |> replace_tag("h3", "h3")
    |> re_replace(
      ~r/\[center\](.*?)\[\/center\]/s,
      fn _, content -> ~s(<div style="text-align:center">#{content}</div>) end
    )
    |> re_replace(
      ~r/\[left\](.*?)\[\/left\]/s,
      fn _, content -> ~s(<div style="text-align:left">#{content}</div>) end
    )
    |> re_replace(
      ~r/\[right\](.*?)\[\/right\]/s,
      fn _, content -> ~s(<div style="text-align:right">#{content}</div>) end
    )
    |> re_replace(
      ~r/\[align=(left|right|center|justify)\](.*?)\[\/align\]/s,
      fn _, dir, content -> ~s(<div style="text-align:#{dir}">#{content}</div>) end
    )
    |> String.replace("[hr]", "<hr class=\"bbcode-hr\" />")
    # Color: accepts #hex, named CSS colors (red, royalblue, etc.), and
    # bracket-safe alphanumerics. Pre-escape pass already neutralized HTML
    # so anything weird ends up as inert CSS, not XSS.
    |> re_replace(
      ~r/\[color=([#a-zA-Z0-9_]{2,32})\](.*?)\[\/color\]/s,
      fn _, color, content -> ~s(<span style="color:#{color}">#{content}</span>) end
    )
    # Size: [size=1-7]...[/size]
    |> re_replace(
      ~r/\[size=([1-7])\](.*?)\[\/size\]/s,
      fn _, size, content ->
        em = size_to_em(size)
        ~s(<span style="font-size:#{em}">#{content}</span>)
      end
    )
    # URL with text: [url=...]...[/url] — accepts http(s) or root-relative
    |> re_replace(
      ~r/\[url=((?:https?:\/\/|\/)[^\]]+)\](.*?)\[\/url\]/s,
      fn _, url, content ->
        ~s(<a href="#{url}" target="_blank" rel="noopener noreferrer">#{content}</a>)
      end
    )
    # URL without text: [url]...[/url]
    |> re_replace(
      ~r/\[url\]((?:https?:\/\/|\/)[^\[]+)\[\/url\]/s,
      fn _, url -> ~s(<a href="#{url}" target="_blank" rel="noopener noreferrer">#{url}</a>) end
    )
    # Image: [img]...[/img] — accepts http(s) or root-relative (e.g. /uploads/...)
    |> re_replace(
      ~r/\[img\]((?:https?:\/\/|\/)[^\[]+)\[\/img\]/s,
      fn _, url ->
        ~s(<img src="#{url}" alt="User image" style="max-width:100%;height:auto" loading="lazy" />)
      end
    )
    # Quote: [quote]...[/quote]
    |> re_replace(
      ~r/\[quote\](.*?)\[\/quote\]/s,
      fn _, content -> ~s(<blockquote class="bbcode-quote">#{content}</blockquote>) end
    )
    # Quote with author: [quote=name]...[/quote] or [quote="name"]...[/quote].
    # The forum's quote/multi-quote buttons emit the quoted form; older posts
    # may use the bare form. Strip optional surrounding "…" so the cite renders
    # cleanly as `name wrote:` instead of `"name" wrote:`.
    |> re_replace(
      ~r/\[quote="?([^\]"]+)"?\](.*?)\[\/quote\]/s,
      fn _, author, content ->
        ~s(<blockquote class="bbcode-quote"><cite>#{author} wrote:</cite>#{content}</blockquote>)
      end
    )
    # Code: [code]...[/code]
    |> re_replace(
      ~r/\[code\](.*?)\[\/code\]/s,
      fn _, content -> ~s(<pre class="bbcode-code"><code>#{content}</code></pre>) end
    )
    # Spoiler with label: [spoiler=Label]...[/spoiler]
    |> re_replace(
      ~r/\[spoiler=([^\]]+)\](.*?)\[\/spoiler\]/s,
      fn _, label, content ->
        "<div class=\"spoiler-block\"><button class=\"spoiler-header\" onclick=\"this.parentElement.classList.toggle(&#39;open&#39;)\">Click to reveal: #{label}</button><div class=\"spoiler-content\">#{content}</div></div>"
      end
    )
    # Spoiler without label: [spoiler]...[/spoiler]
    |> re_replace(
      ~r/\[spoiler\](.*?)\[\/spoiler\]/s,
      fn _, content ->
        "<div class=\"spoiler-block\"><button class=\"spoiler-header\" onclick=\"this.parentElement.classList.toggle(&#39;open&#39;)\">Click to reveal: Spoiler</button><div class=\"spoiler-content\">#{content}</div></div>"
      end
    )
    # List: [list]...[/list] with [*] items
    |> re_replace(
      ~r/\[list\](.*?)\[\/list\]/s,
      fn _, content ->
        items =
          content
          |> String.split(~r/\[\*\]/)
          |> Enum.map(&String.trim/1)
          |> Enum.reject(&(&1 == ""))
          |> Enum.map(&"<li>#{&1}</li>")
          |> Enum.join("")

        "<ul class=\"bbcode-list\">#{items}</ul>"
      end
    )
    # Internal user link: [user]username[/user]
    |> re_replace(
      ~r/\[user\]([A-Za-z0-9_\-]+)\[\/user\]/s,
      fn _, name -> ~s(<a href="/profile/#{name}" class="bbcode-mention">@#{name}</a>) end
    )
    # Internal thread link: [thread]slug[/thread]
    |> re_replace(
      ~r/\[thread\]([a-z0-9\-]+)\[\/thread\]/s,
      fn _, slug -> ~s(<a href="/threads/#{slug}" class="bbcode-link">#{slug}</a>) end
    )
    # Internal forum link: [forum]slug[/forum]
    |> re_replace(
      ~r/\[forum\]([a-z0-9\-]+)\[\/forum\]/s,
      fn _, slug -> ~s(<a href="/forums/#{slug}" class="bbcode-link">#{slug}</a>) end
    )
    # Email: [email]addr[/email] or [email=addr]label[/email]
    |> re_replace(
      ~r/\[email=([^\s\]]+@[^\s\]]+)\](.*?)\[\/email\]/s,
      fn _, addr, label -> ~s(<a href="mailto:#{addr}">#{label}</a>) end
    )
    |> re_replace(
      ~r/\[email\]([^\s\[]+@[^\s\[]+)\[\/email\]/s,
      fn _, addr -> ~s(<a href="mailto:#{addr}">#{addr}</a>) end
    )
    # Newlines to <br>
    |> String.replace("\n", "<br />")
  end

  # Pipe-friendly wrapper: text |> re_replace(regex, replacement)
  defp re_replace(text, regex, replacement) do
    Regex.replace(regex, text, replacement)
  end

  defp apply_custom_bbcodes(text) do
    try do
      ForgeNexus.Forums.list_active_custom_bbcodes()
      |> Enum.reduce(text, fn bbcode, acc ->
        tag = Regex.escape(bbcode.tag_name)
        # IMPORTANT: double-backslash so the source string carries a literal
        # "\[" / "\]" into the regex compiler. The single-backslash form here
        # was a long-standing bug — Elixir collapsed "\[" to "[", which the
        # regex engine then interpreted as a CHARACTER CLASS. With multiple
        # custom tags seeded the unioned character classes matched ordinary
        # post text and triggered catastrophic backtracking, hanging every
        # post that passed through the pipeline.
        regex = Regex.compile!("\\[#{tag}\\](.*?)\\[/#{tag}\\]", "s")

        Regex.replace(regex, acc, fn _, content ->
          String.replace(bbcode.replacement_html, "{{content}}", content)
        end)
      end)
    rescue
      _ -> text
    end
  end

  defp replace_tag(text, bb_tag, html_tag) do
    Regex.replace(
      ~r/\[#{bb_tag}\](.*?)\[\/#{bb_tag}\]/s,
      text,
      fn _, content -> "<#{html_tag}>#{content}</#{html_tag}>" end
    )
  end

  defp size_to_em(size) do
    case size do
      "1" -> "0.7em"
      "2" -> "0.85em"
      "3" -> "1em"
      "4" -> "1.2em"
      "5" -> "1.5em"
      "6" -> "2em"
      "7" -> "2.5em"
      _ -> "1em"
    end
  end
end
