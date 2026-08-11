defmodule ForgeNexus.Federation do
  @moduledoc "The Federation context — cross-community identity, instance management, and ActivityPub."

  import Ecto.Query
  alias ForgeNexus.Repo

  alias ForgeNexus.Federation.{
    InstanceKeypair,
    FederatedInstance,
    FederatedIdentity,
    FederationPolicy
  }

  alias ForgeNexus.Federation.ActivityPub.{Actor, Object, Follower, Delivery}
  alias ForgeNexus.Settings

  def federation_enabled?, do: Settings.get_bool("federation_enabled")

  # --- Instance Management ---

  def list_instances(opts \\ []) do
    query = FederatedInstance |> order_by(:domain)

    query =
      case Keyword.get(opts, :status) do
        nil -> query
        status -> where(query, status: ^status)
      end

    Repo.all(query)
  end

  def get_instance!(id), do: Repo.get!(FederatedInstance, id)
  def get_instance_by_domain(domain), do: Repo.get_by(FederatedInstance, domain: domain)

  def create_instance(attrs) do
    %FederatedInstance{} |> FederatedInstance.changeset(attrs) |> Repo.insert()
  end

  def update_instance(%FederatedInstance{} = inst, attrs) do
    inst |> FederatedInstance.changeset(attrs) |> Repo.update()
  end

  def block_instance(id) do
    get_instance!(id) |> Ecto.Changeset.change(%{status: "blocked"}) |> Repo.update()
  end

  # --- Federated Identities ---

  def list_identities(user_id) do
    from(fi in FederatedIdentity,
      where: fi.local_user_id == ^user_id,
      preload: :remote_instance
    )
    |> Repo.all()
  end

  def link_identity(attrs) do
    %FederatedIdentity{} |> FederatedIdentity.changeset(attrs) |> Repo.insert()
  end

  def unlink_identity(id), do: Repo.get!(FederatedIdentity, id) |> Repo.delete()

  # --- Keypairs ---

  def get_active_keypair do
    from(k in InstanceKeypair, where: k.is_active == true, limit: 1) |> Repo.one()
  end

  def generate_keypair do
    # Generate RSA keypair for signing
    {pub, priv} = generate_rsa_pair()

    %InstanceKeypair{}
    |> InstanceKeypair.changeset(%{public_key: pub, private_key_encrypted: priv, is_active: true})
    |> Repo.insert()
  end

  defp generate_rsa_pair do
    key = :public_key.generate_key({:rsa, 2048, 65537})
    private_pem = :public_key.pem_encode([:public_key.pem_entry_encode(:RSAPrivateKey, key)])

    public_key =
      :public_key.pem_encode([
        :public_key.pem_entry_encode(
          :SubjectPublicKeyInfo,
          {:RSAPublicKey, elem(key, 1), elem(key, 2)}
        )
      ])

    {public_key, private_pem}
  end

  # --- ActivityPub Actors ---

  def get_or_create_actor_for_forum(forum) do
    uri = "#{ForgeNexusWeb.Endpoint.url()}/ap/forums/#{forum.slug}"

    case Repo.get_by(Actor, uri: uri) do
      nil ->
        %Actor{}
        |> Actor.changeset(%{
          uri: uri,
          type: "forum",
          local_forum_id: forum.id,
          inbox_url: "#{uri}/inbox",
          outbox_url: "#{uri}/outbox",
          followers_url: "#{uri}/followers",
          is_local: true
        })
        |> Repo.insert()

      actor ->
        {:ok, actor}
    end
  end

  def get_or_create_actor_for_user(user) do
    uri = "#{ForgeNexusWeb.Endpoint.url()}/ap/users/#{user.slug}"

    case Repo.get_by(Actor, uri: uri) do
      nil ->
        %Actor{}
        |> Actor.changeset(%{
          uri: uri,
          type: "user",
          local_user_id: user.id,
          inbox_url: "#{uri}/inbox",
          outbox_url: "#{uri}/outbox",
          followers_url: "#{uri}/followers",
          is_local: true
        })
        |> Repo.insert()

      actor ->
        {:ok, actor}
    end
  end

  def get_actor_by_uri(uri), do: Repo.get_by(Actor, uri: uri)

  # --- ActivityPub Objects ---

  def create_object(attrs) do
    %Object{} |> Object.changeset(attrs) |> Repo.insert()
  end

  def get_object_by_uri(uri), do: Repo.get_by(Object, uri: uri)

  # --- Followers ---

  def add_follower(actor_id, follower_uri, follower_inbox) do
    %Follower{}
    |> Follower.changeset(%{
      actor_id: actor_id,
      follower_uri: follower_uri,
      follower_inbox: follower_inbox
    })
    |> Repo.insert(on_conflict: :nothing, conflict_target: [:actor_id, :follower_uri])
  end

  def accept_follow(actor_id, follower_uri) do
    case Repo.get_by(Follower, actor_id: actor_id, follower_uri: follower_uri) do
      nil -> {:error, :not_found}
      follower -> follower |> Ecto.Changeset.change(%{accepted: true}) |> Repo.update()
    end
  end

  def get_followers(actor_id) do
    from(f in Follower, where: f.actor_id == ^actor_id and f.accepted == true)
    |> Repo.all()
  end

  # --- Delivery ---

  def enqueue_delivery(object_id, target_inbox) do
    %Delivery{}
    |> Delivery.changeset(%{object_id: object_id, target_inbox: target_inbox})
    |> Repo.insert()
  end

  def pending_deliveries(limit \\ 50) do
    from(d in Delivery,
      where: d.status == "pending" and d.attempts < 5,
      order_by: :inserted_at,
      limit: ^limit,
      preload: :object
    )
    |> Repo.all()
  end

  def mark_delivered(delivery_id) do
    Repo.get!(Delivery, delivery_id)
    |> Ecto.Changeset.change(%{status: "delivered"})
    |> Repo.update()
  end

  def mark_failed(delivery_id, error) do
    delivery = Repo.get!(Delivery, delivery_id)

    delivery
    |> Ecto.Changeset.change(%{
      attempts: delivery.attempts + 1,
      last_attempted_at: DateTime.utc_now(),
      error: error,
      status: if(delivery.attempts + 1 >= 5, do: "failed", else: "pending")
    })
    |> Repo.update()
  end

  # --- Federation Policy ---

  def get_policy do
    FederationPolicy |> limit(1) |> Repo.one() ||
      %FederationPolicy{mode: "closed", allowed_domains: [], blocked_domains: []}
  end

  def update_policy(attrs) do
    case FederationPolicy |> limit(1) |> Repo.one() do
      nil -> %FederationPolicy{} |> FederationPolicy.changeset(attrs) |> Repo.insert()
      policy -> policy |> FederationPolicy.changeset(attrs) |> Repo.update()
    end
  end

  def domain_allowed?(domain) do
    policy = get_policy()

    case policy.mode do
      "open" -> domain not in (policy.blocked_domains || [])
      "allowlist" -> domain in (policy.allowed_domains || [])
      "closed" -> false
    end
  end
end
