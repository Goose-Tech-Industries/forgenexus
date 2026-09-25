defmodule ForgeNexus.Houses.HouseInvitationSchemaTest do
  use ForgeNexus.DataCase, async: true

  alias ForgeNexus.Houses.HouseInvitation

  describe "HouseInvitation" do
    @cid Ecto.UUID.generate()

    test "valid changeset, role inclusion, and hash/1" do
      token = "secure_token_secret_123"
      token_hash = HouseInvitation.hash(token)
      assert is_binary(token_hash)
      assert byte_size(token_hash) == 64

      expires = ~U[2026-04-01 12:00:00Z]

      for role <- ~w(creator admin) do
        cs =
          HouseInvitation.changeset(%HouseInvitation{}, %{
            community_id: @cid,
            email: "creator@example.com",
            token_hash: token_hash,
            expires_at: expires,
            role: role
          })

        assert cs.valid?
        assert get_field(cs, :role) == role
      end

      req_cs = HouseInvitation.changeset(%HouseInvitation{}, %{})
      refute req_cs.valid?
      assert "can't be blank" in errors_on(req_cs).community_id
      assert "can't be blank" in errors_on(req_cs).email
      assert "can't be blank" in errors_on(req_cs).token_hash
      assert "can't be blank" in errors_on(req_cs).expires_at

      bad_cs =
        HouseInvitation.changeset(%HouseInvitation{}, %{
          community_id: @cid,
          email: "not_an_email",
          token_hash: token_hash,
          expires_at: expires,
          role: "owner"
        })

      refute bad_cs.valid?
      assert "has invalid format" in errors_on(bad_cs).email
      assert "is invalid" in errors_on(bad_cs).role
    end
  end
end
