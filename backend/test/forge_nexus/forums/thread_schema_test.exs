defmodule ForgeNexus.Forums.ThreadTest do
  use ForgeNexus.DataCase, async: true

  alias ForgeNexus.Forums.Thread

  @valid_attrs %{
    title: "Awesome Release Announcement",
    forum_id: Ecto.UUID.generate(),
    user_id: Ecto.UUID.generate(),
    prefix: "[Release]",
    tags: ["news", "v1"]
  }

  describe "Thread.changeset/2" do
    test "valid attributes generate slug from title" do
      changeset = Thread.changeset(%Thread{}, @valid_attrs)
      assert changeset.valid?
      assert get_change(changeset, :slug) == "awesome-release-announcement"
      assert get_change(changeset, :prefix) == "[Release]"
      assert get_change(changeset, :tags) == ["news", "v1"]
    end

    test "respects explicit slug if provided" do
      changeset = Thread.changeset(%Thread{}, Map.put(@valid_attrs, :slug, "custom-thread-slug"))
      assert changeset.valid?
      assert get_change(changeset, :slug) == "custom-thread-slug"
    end

    test "requires title, forum_id, and user_id" do
      changeset = Thread.changeset(%Thread{}, %{})
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).title
      assert "can't be blank" in errors_on(changeset).forum_id
      assert "can't be blank" in errors_on(changeset).user_id
    end

    test "validates title length (3 to 200)" do
      short = Thread.changeset(%Thread{}, Map.put(@valid_attrs, :title, "ab"))
      refute short.valid?
      assert "should be at least 3 character(s)" in errors_on(short).title

      long =
        Thread.changeset(%Thread{}, Map.put(@valid_attrs, :title, String.duplicate("a", 201)))

      refute long.valid?
      assert "should be at most 200 character(s)" in errors_on(long).title
    end

    test "validates status inclusion" do
      invalid = Thread.changeset(%Thread{}, Map.put(@valid_attrs, :status, "archived_invalid"))
      refute invalid.valid?
      assert "is invalid" in errors_on(invalid).status

      for valid_status <- ["published", "scheduled", "draft"] do
        cs = Thread.changeset(%Thread{}, Map.put(@valid_attrs, :status, valid_status))
        assert cs.valid?
      end
    end

    test "automatically sets status to scheduled and is_hidden to true when scheduled_at is in the future" do
      future = DateTime.utc_now() |> DateTime.add(3600, :second) |> DateTime.truncate(:second)

      changeset =
        Thread.changeset(
          %Thread{},
          Map.merge(@valid_attrs, %{scheduled_at: future, status: "draft"})
        )

      assert changeset.valid?
      assert get_change(changeset, :status) == "scheduled"
      assert get_change(changeset, :is_hidden) == true
    end

    test "does not override status if scheduled_at is in the past" do
      past = DateTime.utc_now() |> DateTime.add(-3600, :second) |> DateTime.truncate(:second)

      changeset =
        Thread.changeset(
          %Thread{},
          Map.merge(@valid_attrs, %{scheduled_at: past, status: "draft"})
        )

      assert changeset.valid?
      assert get_change(changeset, :status) == "draft"
      assert get_change(changeset, :is_hidden) == nil
    end
  end

  describe "Thread.mod_changeset/2" do
    test "accepts moderation fields" do
      target_forum_id = Ecto.UUID.generate()
      merged_id = Ecto.UUID.generate()
      auto_close = DateTime.utc_now() |> DateTime.add(86400, :second)

      attrs = %{
        is_pinned: true,
        is_locked: true,
        is_hidden: true,
        is_approved: true,
        forum_id: target_forum_id,
        moved_from_forum_id: Ecto.UUID.generate(),
        merged_into_id: merged_id,
        auto_close_at: auto_close,
        status: "published"
      }

      changeset = Thread.mod_changeset(%Thread{}, attrs)
      assert changeset.valid?
      assert get_change(changeset, :is_pinned) == true
      assert get_change(changeset, :is_locked) == true
      assert get_change(changeset, :forum_id) == target_forum_id
      assert get_change(changeset, :merged_into_id) == merged_id
    end
  end
end
