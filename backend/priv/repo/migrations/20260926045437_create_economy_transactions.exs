defmodule ForgeNexus.Repo.Migrations.CreateEconomyTransactions do
  use Ecto.Migration

  def change do
    create_if_not_exists table(:economy_transactions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false

      add :currency_id, references(:currencies, type: :binary_id, on_delete: :delete_all),
        null: false

      add :amount, :integer, null: false
      add :balance_after, :integer, null: false
      add :type, :string, null: false
      add :reason, :string
      add :reference_type, :string
      add :reference_id, :binary_id

      timestamps()
    end

    create_if_not_exists index(:economy_transactions, [:user_id])
    create_if_not_exists index(:economy_transactions, [:currency_id])
    create_if_not_exists index(:economy_transactions, [:type])
  end
end
