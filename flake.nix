{
  description = "Elixir OTP Development Environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };

        # Use fswatch instead of inotify-tools on macOS
        fileWatcher = if pkgs.stdenv.isDarwin then pkgs.fswatch else pkgs.inotify-tools;

      in {
        devShells.default = pkgs.mkShell {
          buildInputs = [
            pkgs.elixir
            pkgs.erlang
            pkgs.rebar3
            pkgs.hex
            fileWatcher  # File watcher for hot reloading (fswatch on macOS, inotify-tools on Linux)
            pkgs.openssl  # Secure communication in Erlang
            pkgs.postgresql  # Optional: if working with Phoenix
            pkgs.sqlite  # Optional: if using SQLite with Ecto
            pkgs.nodejs  # Optional: if using Phoenix with frontend
            pkgs.direnv  # Auto-load shell environments
          ];

          shellHook = ''
            echo "Elixir OTP Environment Loaded!"
            export ERL_AFLAGS="-kernel shell_history enabled"
            export MIX_ENV=dev
          '';
        };
      }
    );
}