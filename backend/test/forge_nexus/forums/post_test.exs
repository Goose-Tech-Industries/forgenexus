defmodule ForgeNexus.Forums.PostTest do
  use ForgeNexus.DataCase, async: true

  alias ForgeNexus.Forums.Post

  describe "Post.changeset/2" do
    test "valid attributes produce valid changeset" do
      attrs = %{
        body: "Hello, this is a test post.",
        body_html: "<p>Hello, this is a test post.</p>",
        thread_id: Ecto.UUID.generate(),
        user_id: Ecto.UUID.generate(),
        position: 1,
        is_first_post: true,
        ip_address: "127.0.0.1"
      }

      changeset = Post.changeset(%Post{}, attrs)
      assert changeset.valid?
      assert get_change(changeset, :position) == 1
      assert get_change(changeset, :is_first_post) == true
    end

    test "requires body, thread_id, and user_id" do
      changeset = Post.changeset(%Post{}, %{})
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).body
      assert "can't be blank" in errors_on(changeset).thread_id
      assert "can't be blank" in errors_on(changeset).user_id
    end

    test "validates body length limits" do
      empty =
        Post.changeset(%Post{}, %{
          body: "",
          thread_id: Ecto.UUID.generate(),
          user_id: Ecto.UUID.generate()
        })

      refute empty.valid?
      assert "can't be blank" in errors_on(empty).body

      too_long =
        Post.changeset(%Post{}, %{
          body: String.duplicate("a", 50_001),
          thread_id: Ecto.UUID.generate(),
          user_id: Ecto.UUID.generate()
        })

      refute too_long.valid?
      assert "should be at most 50000 character(s)" in errors_on(too_long).body
    end
  end

  describe "Post.mod_changeset/2" do
    test "allows moderating visibility and approval" do
      post = %Post{body: "Initial text"}
      changeset = Post.mod_changeset(post, %{is_hidden: true, is_approved: false})

      assert changeset.valid?
      assert get_change(changeset, :is_hidden) == true
      assert get_change(changeset, :is_approved) == false
    end
  end

  describe "Post.edit_changeset/2" do
    test "sets is_edited, edited_at, and increments edit_count from nil" do
      editor_id = Ecto.UUID.generate()
      post = %Post{body: "Original", edit_count: nil}
      changeset = Post.edit_changeset(post, %{body: "Updated text", edited_by_id: editor_id})

      assert changeset.valid?
      assert get_change(changeset, :is_edited) == true
      assert get_change(changeset, :edited_at) != nil
      assert get_change(changeset, :edit_count) == 1
    end

    test "increments existing edit_count" do
      post = %Post{body: "Original", edit_count: 3}
      changeset = Post.edit_changeset(post, %{body: "Third edit"})

      assert changeset.valid?
      assert get_change(changeset, :edit_count) == 4
    end

    test "requires body when editing" do
      post = %Post{body: "Original"}
      changeset = Post.edit_changeset(post, %{body: nil})

      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).body
    end
  end
end
