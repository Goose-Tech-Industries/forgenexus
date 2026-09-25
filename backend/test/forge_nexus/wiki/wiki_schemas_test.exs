defmodule ForgeNexus.Wiki.WikiSchemasTest do
  use ForgeNexus.DataCase, async: true

  alias ForgeNexus.Wiki.{
    EditLock,
    WikiCategory,
    WikiPage,
    WikiRevision
  }

  describe "EditLock" do
    @pid Ecto.UUID.generate()
    @uid Ecto.UUID.generate()

    test "valid changeset" do
      now = ~U[2026-03-01 12:00:00Z]
      expires = ~U[2026-03-01 12:15:00Z]

      cs =
        EditLock.changeset(%EditLock{}, %{
          locked_at: now,
          expires_at: expires,
          page_id: @pid,
          user_id: @uid
        })

      assert cs.valid?
      assert get_field(cs, :locked_at) == now

      req_cs = EditLock.changeset(%EditLock{}, %{})
      refute req_cs.valid?
      assert "can't be blank" in errors_on(req_cs).locked_at
      assert "can't be blank" in errors_on(req_cs).expires_at
      assert "can't be blank" in errors_on(req_cs).page_id
      assert "can't be blank" in errors_on(req_cs).user_id
    end
  end

  describe "WikiCategory" do
    test "valid changeset" do
      cs =
        WikiCategory.changeset(%WikiCategory{}, %{
          name: "Guides",
          slug: "guides",
          description: "Official documentation guides",
          position: 1,
          icon: "book"
        })

      assert cs.valid?
      assert get_field(cs, :slug) == "guides"

      req_cs = WikiCategory.changeset(%WikiCategory{}, %{})
      refute req_cs.valid?
      assert "can't be blank" in errors_on(req_cs).name
      assert "can't be blank" in errors_on(req_cs).slug
    end
  end

  describe "WikiPage" do
    @uid Ecto.UUID.generate()

    test "valid changeset" do
      cs =
        WikiPage.changeset(%WikiPage{}, %{
          title: "Getting Started",
          slug: "getting-started",
          body: "# Welcome to ForgeNexus",
          body_html: "<h1>Welcome to ForgeNexus</h1>",
          created_by_id: @uid,
          is_published: true
        })

      assert cs.valid?
      assert get_field(cs, :slug) == "getting-started"

      req_cs = WikiPage.changeset(%WikiPage{}, %{})
      refute req_cs.valid?
      assert "can't be blank" in errors_on(req_cs).title
      assert "can't be blank" in errors_on(req_cs).slug
      assert "can't be blank" in errors_on(req_cs).body
      assert "can't be blank" in errors_on(req_cs).created_by_id
    end
  end

  describe "WikiRevision" do
    @pid Ecto.UUID.generate()
    @uid Ecto.UUID.generate()

    test "valid changeset" do
      cs =
        WikiRevision.changeset(%WikiRevision{}, %{
          body: "Updated wiki page content",
          body_html: "<p>Updated wiki page content</p>",
          edit_summary: "Grammar fix",
          revision_number: 3,
          page_id: @pid,
          edited_by_id: @uid
        })

      assert cs.valid?
      assert get_field(cs, :revision_number) == 3

      req_cs = WikiRevision.changeset(%WikiRevision{}, %{})
      refute req_cs.valid?
      assert "can't be blank" in errors_on(req_cs).body
      assert "can't be blank" in errors_on(req_cs).revision_number
      assert "can't be blank" in errors_on(req_cs).page_id
      assert "can't be blank" in errors_on(req_cs).edited_by_id
    end
  end
end
