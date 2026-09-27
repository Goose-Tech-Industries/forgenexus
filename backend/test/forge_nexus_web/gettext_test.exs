defmodule ForgeNexusWeb.GettextTest do
  use ExUnit.Case, async: true

  use Gettext, backend: ForgeNexusWeb.Gettext

  test "translates strings with gettext macros" do
    assert gettext("Hello world") == "Hello world"
    assert dgettext("errors", "can't be blank") == "can't be blank"
    assert ngettext("one item", "%{count} items", 1) == "one item"
    assert ngettext("one item", "%{count} items", 2, count: 2) == "2 items"
    assert dngettext("errors", "1 error", "%{count} errors", 1) == "1 error"
    assert dngettext("errors", "1 error", "%{count} errors", 3, count: 3) == "3 errors"
    assert pgettext("chat", "Send") == "Send"
    assert dpgettext("errors", "form", "is invalid") == "is invalid"
    assert pngettext("chat", "one message", "%{count} messages", 1) == "one message"
    assert pngettext("chat", "one message", "%{count} messages", 5, count: 5) == "5 messages"
    assert dpngettext("errors", "form", "one error", "%{count} errors", 1) == "one error"
    assert dpngettext("errors", "form", "one error", "%{count} errors", 4, count: 4) == "4 errors"
  end

  test "with_locale executes block in specified locale" do
    Gettext.with_locale(ForgeNexusWeb.Gettext, "en", fn ->
      assert Gettext.get_locale(ForgeNexusWeb.Gettext) == "en"
    end)
  end
end
