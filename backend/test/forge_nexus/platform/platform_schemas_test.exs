defmodule ForgeNexus.Platform.PlatformSchemasTest do
  use ForgeNexus.DataCase, async: true

  alias ForgeNexus.Platform.{ApiKey, InfraCost, LedgerEntry}

  describe "ApiKey" do
    @uid Ecto.UUID.generate()

    test "valid changeset, generate_key/0, plans/0, all_scopes/0" do
      {raw_key, prefix, hash} = ApiKey.generate_key()
      assert String.starts_with?(raw_key, "fnx_")
      assert String.starts_with?(raw_key, prefix)
      assert byte_size(hash) == 64

      plans = ApiKey.plans()
      assert Map.has_key?(plans, "free")
      assert Map.has_key?(plans, "pro")

      scopes = ApiKey.all_scopes()
      assert "read" in scopes
      assert "admin" in scopes

      cs =
        ApiKey.changeset(%ApiKey{}, %{
          name: "CI/CD Key",
          key_hash: hash,
          key_prefix: prefix,
          user_id: @uid,
          scopes: ["read", "write"]
        })

      assert cs.valid?
      assert get_field(cs, :name) == "CI/CD Key"

      req_cs = ApiKey.changeset(%ApiKey{}, %{})
      refute req_cs.valid?
      assert "can't be blank" in errors_on(req_cs).name
      assert "can't be blank" in errors_on(req_cs).key_hash
      assert "can't be blank" in errors_on(req_cs).key_prefix
      assert "can't be blank" in errors_on(req_cs).user_id

      long_name = String.duplicate("k", 101)

      long_cs =
        ApiKey.changeset(%ApiKey{}, %{
          name: long_name,
          key_hash: hash,
          key_prefix: prefix,
          user_id: @uid
        })

      refute long_cs.valid?
      assert "should be at most 100 character(s)" in errors_on(long_cs).name
    end
  end

  describe "InfraCost" do
    test "valid changeset and required fields" do
      cs =
        InfraCost.changeset(%InfraCost{}, %{
          provider: "AWS",
          service: "RDS PostgreSQL",
          amount_cents: 25000,
          period_start: ~D[2026-03-01],
          period_end: ~D[2026-03-31]
        })

      assert cs.valid?
      assert get_field(cs, :amount_cents) == 25000

      req_cs = InfraCost.changeset(%InfraCost{}, %{})
      refute req_cs.valid?
      assert "can't be blank" in errors_on(req_cs).provider
      assert "can't be blank" in errors_on(req_cs).service
      assert "can't be blank" in errors_on(req_cs).amount_cents
      assert "can't be blank" in errors_on(req_cs).period_start
      assert "can't be blank" in errors_on(req_cs).period_end
    end
  end

  describe "LedgerEntry" do
    test "valid changeset and required fields" do
      cs =
        LedgerEntry.changeset(%LedgerEntry{}, %{
          type: "subscription_revenue",
          amount_cents: 10000,
          infra_allocation_cents: 2000,
          profit_allocation_cents: 8000,
          source: "stripe"
        })

      assert cs.valid?
      assert get_field(cs, :amount_cents) == 10000

      req_cs = LedgerEntry.changeset(%LedgerEntry{}, %{})
      refute req_cs.valid?
      assert "can't be blank" in errors_on(req_cs).type
      assert "can't be blank" in errors_on(req_cs).amount_cents
      assert "can't be blank" in errors_on(req_cs).infra_allocation_cents
      assert "can't be blank" in errors_on(req_cs).profit_allocation_cents
    end
  end
end
