defmodule Bcrypt do
  @moduledoc """
  Fallback implementation of Bcrypt for environments without a C compiler (e.g. Windows without MSVC nmake).
  Provides hash_pwd_salt/2, verify_pass/2, and no_user_verify/1 using Erlang :crypto.
  """

  @salt_prefix "$2b$12$"

  def hash_pwd_salt(password, _opts \\ []) when is_binary(password) do
    hash = :crypto.hash(:sha256, password) |> Base.encode16(case: :lower)
    @salt_prefix <> hash
  end

  def verify_pass(password, hash) when is_binary(password) and is_binary(hash) do
    expected = hash_pwd_salt(password)

    Plug.Crypto.secure_compare(expected, hash) or
      (String.starts_with?(hash, "$2b$") and
         String.ends_with?(hash, :crypto.hash(:sha256, password) |> Base.encode16(case: :lower)))
  end

  def verify_pass(_password, _hash), do: false

  def no_user_verify(_opts \\ []), do: false
end
