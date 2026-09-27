defmodule ForgeNexus.Tournaments.RegistrationTest do
  use ForgeNexus.DataCase

  alias ForgeNexus.Accounts.User
  alias ForgeNexus.Economy
  alias ForgeNexus.Repo
  alias ForgeNexus.Tournaments.{Participant, Registration, Tournament}

  defp create_user(attrs \\ %{}) do
    uid = System.unique_integer([:positive])

    defaults = %{
      email: "user_#{uid}@example.com",
      username: "user_#{uid}",
      password: "Password1234!",
      password_confirmation: "Password1234!"
    }

    user =
      %User{}
      |> User.registration_changeset(Map.merge(defaults, attrs))
      |> Repo.insert!()

    if initial_points = attrs[:points] do
      from(u in User, where: u.id == ^user.id)
      |> Repo.update_all(set: [points: initial_points])

      Repo.get!(User, user.id)
    else
      user
    end
  end

  defp create_tournament(user, attrs \\ %{}) do
    uid = System.unique_integer([:positive])

    defaults = %{
      name: "Tournament #{uid}",
      format: "single_elimination",
      status: "upcoming",
      created_by_id: user.id,
      entry_fee_points: 0,
      prize_pool_points: 0
    }

    %Tournament{}
    |> Tournament.changeset(Map.merge(defaults, attrs))
    |> Repo.insert!()
  end

  describe "register/2" do
    test "returns error when tournament status is not upcoming" do
      user = create_user()
      tournament = create_tournament(user, %{status: "active"})

      assert {:error, :registration_closed} = Registration.register(tournament.id, user.id)
    end

    test "returns error when already registered" do
      user = create_user()
      tournament = create_tournament(user)

      assert {:ok, :registered} = Registration.register(tournament.id, user.id)
      assert {:error, :already_registered} = Registration.register(tournament.id, user.id)
    end

    test "registers successfully when tournament is free (entry_fee_points == 0)" do
      user = create_user()
      tournament = create_tournament(user, %{entry_fee_points: 0})

      assert {:ok, :registered} = Registration.register(tournament.id, user.id)

      assert Repo.exists?(
               from p in Participant,
                 where: p.tournament_id == ^tournament.id and p.user_id == ^user.id
             )
    end

    test "returns error when user has insufficient points for entry fee" do
      user = create_user(%{points: 50})
      tournament = create_tournament(user, %{entry_fee_points: 100})

      assert {:error, :insufficient_points} = Registration.register(tournament.id, user.id)
      assert Economy.get_points(user.id) == 50
    end

    test "deducts points and updates prize pool when user has sufficient points" do
      user = create_user(%{points: 200})

      tournament =
        create_tournament(user, %{name: "Open Cup", entry_fee_points: 100, prize_pool_points: 50})

      assert {:ok, :registered} = Registration.register(tournament.id, user.id)
      assert Economy.get_points(user.id) == 100

      updated_tournament = Repo.get!(Tournament, tournament.id)
      assert updated_tournament.prize_pool_points == 150

      assert Repo.exists?(
               from p in Participant,
                 where: p.tournament_id == ^tournament.id and p.user_id == ^user.id
             )
    end
  end

  describe "unregister/2" do
    test "returns error when tournament status is not upcoming" do
      user = create_user()
      tournament = create_tournament(user, %{status: "in_progress"})

      assert {:error, :cannot_unregister} = Registration.unregister(tournament.id, user.id)
    end

    test "unregisters participant and refunds entry fee points" do
      user = create_user(%{points: 300})
      tournament = create_tournament(user, %{name: "Grand Slam", entry_fee_points: 100})

      assert {:ok, :registered} = Registration.register(tournament.id, user.id)
      assert Economy.get_points(user.id) == 200

      assert {:ok, :unregistered} = Registration.unregister(tournament.id, user.id)
      assert Economy.get_points(user.id) == 300

      refute Repo.exists?(
               from p in Participant,
                 where: p.tournament_id == ^tournament.id and p.user_id == ^user.id
             )
    end

    test "unregisters participant without refund when tournament was free" do
      user = create_user(%{points: 50})
      tournament = create_tournament(user, %{entry_fee_points: 0})

      assert {:ok, :registered} = Registration.register(tournament.id, user.id)
      assert {:ok, :unregistered} = Registration.unregister(tournament.id, user.id)
      assert Economy.get_points(user.id) == 50
    end

    test "handles unregistered user without failing" do
      user = create_user()
      tournament = create_tournament(user, %{entry_fee_points: 100})

      assert {:ok, :unregistered} = Registration.unregister(tournament.id, user.id)
    end
  end

  describe "distribute_prizes/2" do
    test "returns empty list when prize pool is zero or nil" do
      user = create_user()
      tournament = create_tournament(user, %{prize_pool_points: 0})

      assert {:ok, []} = Registration.distribute_prizes(tournament.id, [user.id])

      from(t in Tournament, where: t.id == ^tournament.id)
      |> Repo.update_all(set: [prize_pool_points: nil])

      assert {:ok, []} = Registration.distribute_prizes(tournament.id, [user.id])
    end

    test "distributes full prize pool to 1 placement" do
      user = create_user(%{points: 0})
      tournament = create_tournament(user, %{prize_pool_points: 1000})
      assert {:ok, :registered} = Registration.register(tournament.id, user.id)

      assert {:ok, [1000]} = Registration.distribute_prizes(tournament.id, [user.id])
      assert Economy.get_points(user.id) == 1000

      participant = Repo.get_by!(Participant, tournament_id: tournament.id, user_id: user.id)
      assert participant.prize_points == 1000
    end

    test "distributes 70% and 30% to 2 placements" do
      u1 = create_user(%{points: 0})
      u2 = create_user(%{points: 0})
      tournament = create_tournament(u1, %{prize_pool_points: 1000})

      assert {:ok, :registered} = Registration.register(tournament.id, u1.id)
      assert {:ok, :registered} = Registration.register(tournament.id, u2.id)

      assert {:ok, [700, 300]} = Registration.distribute_prizes(tournament.id, [u1.id, u2.id])
      assert Economy.get_points(u1.id) == 700
      assert Economy.get_points(u2.id) == 300

      p1 = Repo.get_by!(Participant, tournament_id: tournament.id, user_id: u1.id)
      p2 = Repo.get_by!(Participant, tournament_id: tournament.id, user_id: u2.id)
      assert p1.prize_points == 700
      assert p2.prize_points == 300
    end

    test "distributes 50%, 30%, and 20% to 3 or more placements" do
      u1 = create_user(%{points: 0})
      u2 = create_user(%{points: 0})
      u3 = create_user(%{points: 0})
      u4 = create_user(%{points: 0})
      tournament = create_tournament(u1, %{prize_pool_points: 1000})

      assert {:ok, :registered} = Registration.register(tournament.id, u1.id)
      assert {:ok, :registered} = Registration.register(tournament.id, u2.id)
      assert {:ok, :registered} = Registration.register(tournament.id, u3.id)
      assert {:ok, :registered} = Registration.register(tournament.id, u4.id)

      assert {:ok, [500, 300, 200]} =
               Registration.distribute_prizes(tournament.id, [u1.id, u2.id, u3.id, u4.id])

      assert Economy.get_points(u1.id) == 500
      assert Economy.get_points(u2.id) == 300
      assert Economy.get_points(u3.id) == 200
      assert Economy.get_points(u4.id) == 0
    end

    test "handles distribution where rounded amount is 0" do
      u1 = create_user(%{points: 0})
      u2 = create_user(%{points: 0})
      u3 = create_user(%{points: 0})
      # With total = 1, round(1 * 0.5) = 1, round(1 * 0.3) = 0, round(1 * 0.2) = 0
      tournament = create_tournament(u1, %{prize_pool_points: 1})

      assert {:ok, :registered} = Registration.register(tournament.id, u1.id)
      assert {:ok, :registered} = Registration.register(tournament.id, u2.id)
      assert {:ok, :registered} = Registration.register(tournament.id, u3.id)

      assert {:ok, [1, 0, 0]} =
               Registration.distribute_prizes(tournament.id, [u1.id, u2.id, u3.id])

      assert Economy.get_points(u1.id) == 1
      assert Economy.get_points(u2.id) == 0
      assert Economy.get_points(u3.id) == 0

      p2 = Repo.get_by!(Participant, tournament_id: tournament.id, user_id: u2.id)
      assert p2.prize_points == nil
    end
  end
end
