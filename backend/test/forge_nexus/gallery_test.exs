defmodule ForgeNexus.GalleryTest do
  use ForgeNexus.DataCase, async: true

  alias ForgeNexus.Gallery
  alias ForgeNexus.Gallery.{Album, MediaItem}
  alias ForgeNexus.Accounts

  defp create_user do
    unique = System.unique_integer([:positive])

    {:ok, user} =
      Accounts.register_user(%{
        username: "gal_u_#{unique}",
        email: "gal_u_#{unique}@example.com",
        password: "ValidPassword123!@#"
      })

    user
  end

  defp album_attrs(user_id, attrs) do
    unique = System.unique_integer([:positive])

    Enum.into(attrs, %{
      title: "Vacation Photos #{unique}",
      description: "Trip photos",
      is_public: true,
      user_id: user_id,
      position: 1
    })
  end

  describe "albums CRUD and listing" do
    test "create, get, list_user_albums, list_public_albums, update, delete" do
      user = create_user()

      assert {:ok, %Album{} = pub_album} =
               Gallery.create_album(
                 album_attrs(user.id, %{title: "Public Album", is_public: true, position: 2})
               )

      assert {:ok, %Album{} = priv_album} =
               Gallery.create_album(
                 album_attrs(user.id, %{title: "Private Album", is_public: false, position: 1})
               )

      assert %Album{id: id} = Gallery.get_album!(pub_album.id)
      assert id == pub_album.id

      # User albums (both public and private)
      user_albums = Gallery.list_user_albums(user.id)
      assert length(user_albums) == 2
      # Ordered by position asc
      assert hd(user_albums).id == priv_album.id

      # Public albums only
      public_albums = Gallery.list_public_albums(user.id)
      assert length(public_albums) == 1
      assert hd(public_albums).id == pub_album.id

      # Update
      assert {:ok, updated} = Gallery.update_album(pub_album.id, %{title: "Updated Album"})
      assert updated.title == "Updated Album"

      # Delete
      assert {:ok, %Album{}} = Gallery.delete_album(priv_album.id)
      assert length(Gallery.list_user_albums(user.id)) == 1
    end
  end

  describe "media items: add_media, remove_media, recent_media" do
    test "adds media, increments album media_count, removes media, decrements count" do
      user = create_user()
      {:ok, album} = Gallery.create_album(album_attrs(user.id, %{is_public: true}))

      media_attrs = %{
        file_url: "https://example.com/photo1.jpg",
        thumbnail_url: "https://example.com/photo1_thumb.jpg",
        caption: "Sunset at the beach",
        file_type: "image",
        position: 1
      }

      assert {:ok, %MediaItem{} = item} = Gallery.add_media(album.id, user.id, media_attrs)
      assert item.file_url == media_attrs.file_url

      reloaded_album = Gallery.get_album!(album.id)
      assert reloaded_album.media_count == 1
      assert length(reloaded_album.items) == 1

      # recent_media/1 includes items from public albums
      recent = Gallery.recent_media(10)
      assert Enum.any?(recent, &(&1.id == item.id))

      # remove_media/1
      assert {:ok, {1, _}} = Gallery.remove_media(item.id)

      after_remove_album = Gallery.get_album!(album.id)
      assert after_remove_album.media_count == 0
      assert after_remove_album.items == []
    end
  end
end
