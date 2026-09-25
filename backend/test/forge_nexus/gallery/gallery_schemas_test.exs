defmodule ForgeNexus.Gallery.GallerySchemasTest do
  use ForgeNexus.DataCase, async: true

  alias ForgeNexus.Gallery.{Album, MediaItem}

  describe "Album" do
    @uid Ecto.UUID.generate()

    test "valid changeset" do
      cs =
        Album.changeset(%Album{}, %{
          title: "Community Meetup Photos",
          description: "Photos from March 2026 meetup",
          user_id: @uid,
          is_public: true
        })

      assert cs.valid?
      assert get_field(cs, :title) == "Community Meetup Photos"

      req_cs = Album.changeset(%Album{}, %{})
      refute req_cs.valid?
      assert "can't be blank" in errors_on(req_cs).title
      assert "can't be blank" in errors_on(req_cs).user_id
    end
  end

  describe "MediaItem" do
    @aid Ecto.UUID.generate()
    @uid Ecto.UUID.generate()

    test "valid changeset and file_type inclusions" do
      for ftype <- ~w(image video gif) do
        cs =
          MediaItem.changeset(%MediaItem{}, %{
            file_url: "https://cdn.example.com/item.#{ftype}",
            album_id: @aid,
            user_id: @uid,
            file_type: ftype
          })

        assert cs.valid?
        assert get_field(cs, :file_type) == ftype
      end

      req_cs = MediaItem.changeset(%MediaItem{}, %{})
      refute req_cs.valid?
      assert "can't be blank" in errors_on(req_cs).file_url
      assert "can't be blank" in errors_on(req_cs).album_id
      assert "can't be blank" in errors_on(req_cs).user_id

      bad_type_cs =
        MediaItem.changeset(%MediaItem{}, %{
          file_url: "https://cdn.example.com/audio.mp3",
          album_id: @aid,
          user_id: @uid,
          file_type: "audio"
        })

      refute bad_type_cs.valid?
      assert "is invalid" in errors_on(bad_type_cs).file_type
    end
  end
end
