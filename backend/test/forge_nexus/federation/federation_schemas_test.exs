defmodule ForgeNexus.Federation.FederationSchemasTest do
  use ForgeNexus.DataCase, async: true

  alias ForgeNexus.Federation.{
    FederatedIdentity,
    FederatedInstance,
    FederationPolicy,
    InstanceKeypair,
    ActivityPub.Actor,
    ActivityPub.Delivery,
    ActivityPub.Follower,
    ActivityPub.Object
  }

  describe "FederatedIdentity" do
    @luid Ecto.UUID.generate()
    @riid Ecto.UUID.generate()

    test "valid changeset" do
      cs =
        FederatedIdentity.changeset(%FederatedIdentity{}, %{
          remote_user_id: "https://remote.social/users/alice",
          remote_username: "alice",
          remote_display_name: "Alice Wonderland",
          local_user_id: @luid,
          remote_instance_id: @riid
        })

      assert cs.valid?
      assert get_field(cs, :remote_username) == "alice"

      req_cs = FederatedIdentity.changeset(%FederatedIdentity{}, %{})
      refute req_cs.valid?
      assert "can't be blank" in errors_on(req_cs).remote_user_id
      assert "can't be blank" in errors_on(req_cs).remote_username
      assert "can't be blank" in errors_on(req_cs).local_user_id
      assert "can't be blank" in errors_on(req_cs).remote_instance_id
    end
  end

  describe "FederatedInstance" do
    test "valid changeset and inclusions" do
      for trust <- ["trusted", "verified", "untrusted"] do
        for status <- ["active", "suspended", "pending", "blocked"] do
          cs =
            FederatedInstance.changeset(%FederatedInstance{}, %{
              domain: "remote.social",
              name: "Remote Social",
              trust_level: trust,
              status: status
            })

          assert cs.valid?
          assert get_field(cs, :trust_level) == trust
          assert get_field(cs, :status) == status
        end
      end

      req_cs = FederatedInstance.changeset(%FederatedInstance{}, %{})
      refute req_cs.valid?
      assert "can't be blank" in errors_on(req_cs).domain

      bad_cs =
        FederatedInstance.changeset(%FederatedInstance{}, %{
          domain: "remote.social",
          trust_level: "godmode",
          status: "destroyed"
        })

      refute bad_cs.valid?
      assert "is invalid" in errors_on(bad_cs).trust_level
      assert "is invalid" in errors_on(bad_cs).status
    end
  end

  describe "FederationPolicy" do
    test "valid changeset and mode inclusions" do
      for mode <- ["open", "allowlist", "closed"] do
        cs =
          FederationPolicy.changeset(%FederationPolicy{}, %{
            mode: mode,
            auto_accept_follows: true
          })

        assert cs.valid?
        assert get_field(cs, :mode) == mode
      end

      req_cs = FederationPolicy.changeset(%FederationPolicy{}, %{mode: nil})
      refute req_cs.valid?
      assert "can't be blank" in errors_on(req_cs).mode

      bad_mode_cs = FederationPolicy.changeset(%FederationPolicy{}, %{mode: "anarchy"})
      refute bad_mode_cs.valid?
      assert "is invalid" in errors_on(bad_mode_cs).mode
    end
  end

  describe "InstanceKeypair" do
    test "valid changeset" do
      cs =
        InstanceKeypair.changeset(%InstanceKeypair{}, %{
          public_key: "-----BEGIN PUBLIC KEY-----\nMIIB...",
          private_key_encrypted: <<1, 2, 3, 4, 5>>,
          is_active: true
        })

      assert cs.valid?
      assert get_field(cs, :is_active) == true

      req_cs = InstanceKeypair.changeset(%InstanceKeypair{}, %{})
      refute req_cs.valid?
      assert "can't be blank" in errors_on(req_cs).public_key
      assert "can't be blank" in errors_on(req_cs).private_key_encrypted
    end
  end

  describe "ActivityPub.Actor" do
    test "valid changeset" do
      cs =
        Actor.changeset(%Actor{}, %{
          uri: "https://example.com/users/alice",
          type: "Person",
          inbox_url: "https://example.com/users/alice/inbox",
          outbox_url: "https://example.com/users/alice/outbox"
        })

      assert cs.valid?
      assert get_field(cs, :type) == "Person"

      req_cs = Actor.changeset(%Actor{}, %{})
      refute req_cs.valid?
      assert "can't be blank" in errors_on(req_cs).uri
      assert "can't be blank" in errors_on(req_cs).type
      assert "can't be blank" in errors_on(req_cs).inbox_url
    end
  end

  describe "ActivityPub.Delivery" do
    @oid Ecto.UUID.generate()

    test "valid changeset" do
      cs =
        Delivery.changeset(%Delivery{}, %{
          target_inbox: "https://remote.social/inbox",
          object_id: @oid,
          status: "pending"
        })

      assert cs.valid?
      assert get_field(cs, :target_inbox) == "https://remote.social/inbox"

      req_cs = Delivery.changeset(%Delivery{}, %{})
      refute req_cs.valid?
      assert "can't be blank" in errors_on(req_cs).target_inbox
      assert "can't be blank" in errors_on(req_cs).object_id
    end
  end

  describe "ActivityPub.Follower" do
    @aid Ecto.UUID.generate()

    test "valid changeset" do
      cs =
        Follower.changeset(%Follower{}, %{
          follower_uri: "https://remote.social/users/bob",
          follower_inbox: "https://remote.social/users/bob/inbox",
          actor_id: @aid,
          accepted: true
        })

      assert cs.valid?
      assert get_field(cs, :accepted) == true

      req_cs = Follower.changeset(%Follower{}, %{})
      refute req_cs.valid?
      assert "can't be blank" in errors_on(req_cs).follower_uri
      assert "can't be blank" in errors_on(req_cs).follower_inbox
      assert "can't be blank" in errors_on(req_cs).actor_id
    end
  end

  describe "ActivityPub.Object" do
    @aid Ecto.UUID.generate()

    test "valid changeset" do
      cs =
        Object.changeset(%Object{}, %{
          uri: "https://example.com/objects/1",
          type: "Note",
          actor_id: @aid,
          data: %{"content" => "Hello federated world!"}
        })

      assert cs.valid?
      assert get_field(cs, :type) == "Note"

      req_cs = Object.changeset(%Object{}, %{})
      refute req_cs.valid?
      assert "can't be blank" in errors_on(req_cs).uri
      assert "can't be blank" in errors_on(req_cs).type
      assert "can't be blank" in errors_on(req_cs).actor_id
    end
  end
end
