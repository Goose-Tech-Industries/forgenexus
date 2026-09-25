defmodule ForgeNexus.Forums.CategoryForumSchemaTest do
  use ForgeNexus.DataCase, async: true

  alias ForgeNexus.Forums.{Category, Forum}

  describe "Category.changeset/2" do
    test "valid attributes generate slug" do
      attrs = %{name: "Hardware Lounge", description: "PC talk"}
      changeset = Category.changeset(%Category{}, attrs)

      assert changeset.valid?
      assert get_change(changeset, :slug) == "hardware-lounge"
      assert get_change(changeset, :description) == "PC talk"
    end

    test "respects explicit slug" do
      attrs = %{name: "Hardware Lounge", slug: "custom-hardware"}
      changeset = Category.changeset(%Category{}, attrs)

      assert changeset.valid?
      assert get_change(changeset, :slug) == "custom-hardware"
    end

    test "requires name and handles nil name in slug generation" do
      changeset = Category.changeset(%Category{}, %{})

      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).name
      assert get_change(changeset, :slug) == nil
    end
  end

  describe "Forum.changeset/2" do
    test "valid attributes generate slug" do
      cat_id = Ecto.UUID.generate()
      attrs = %{name: "Graphics Cards", category_id: cat_id, description: "GPU news"}
      changeset = Forum.changeset(%Forum{}, attrs)

      assert changeset.valid?
      assert get_change(changeset, :slug) == "graphics-cards"
      assert get_change(changeset, :category_id) == cat_id
    end

    test "respects explicit slug" do
      cat_id = Ecto.UUID.generate()
      attrs = %{name: "Graphics Cards", category_id: cat_id, slug: "gpus"}
      changeset = Forum.changeset(%Forum{}, attrs)

      assert changeset.valid?
      assert get_change(changeset, :slug) == "gpus"
    end

    test "requires name and category_id and handles nil name in slug generation" do
      changeset = Forum.changeset(%Forum{}, %{})

      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).name
      assert "can't be blank" in errors_on(changeset).category_id
      assert get_change(changeset, :slug) == nil
    end
  end
end
