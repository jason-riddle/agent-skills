{
  pkgs,
  lib,
  config,
  ...
}:

{
  # ============================================================================
  # ENVIRONMENT CONFIGURATION
  # ============================================================================

  # https://devenv.sh/integrations/dotenv/
  dotenv = {
    enable = true;
    filename = [
      ".env"
      ".env.local"
    ];
  };

  # ============================================================================
  # LANGUAGE & RUNTIME
  # ============================================================================

  # https://devenv.sh/languages/
  # languages.go = {
  #   enable = true;
  #   package = pkgs.go;
  # };

  # ============================================================================
  # PACKAGES & TOOLS
  # ============================================================================

  # https://devenv.sh/packages/
  # https://search.nixos.org/packages
  packages =
    with pkgs;
    [
      pkgs.bash-completion # Enable bash programmable completion

      # Go
      # pkgs.gopls

      # Claude Code
      # pkgs.claude-code
      # Claude Code Router
      # pkgs.claude-code-router

      # MCP Servers
      # pkgs.docker
      # pkgs.gopls
      # pkgs.deno

      # Local MCP server
      # (pkgs.buildGoModule rec {
      #   pname = "mcp-server";
      #   version = "0.1.0";
      #   src = ./.;
      #   vendorHash = "sha256-Y/JwXXoXscXmgTCBcPkG9ZWgfw2mmhovranQTpqIcL8=";
      #   subPackages = [ "cmd/server" ];
      # })
    ]
    ++ lib.optionals pkgs.stdenv.isLinux [
      # Conditionally include glibcLocales only on Linux systems
      # to address potential locale warnings with tools like perl.
      # perl: warning: Setting locale failed.
      # perl: warning: Please check that your locale settings:
      pkgs.glibcLocales
    ];

  # ============================================================================
  # CLAUDE CODE CONFIGURATION
  # ============================================================================

  # imports = [
  #   ./nix/claude-code.nix
  # ];

  # ============================================================================
  # SCRIPTS
  # ============================================================================

  # https://devenv.sh/scripts/
  # enterShell = ''
  #   echo "Converting Nix MCP config to OpenCode JSON..."
  #   export DEVENV_ROOT="${config.devenv.root}"
  #   cd nix && make convert
  # '';

  # ============================================================================
  # GIT HOOKS CONFIGURATION
  # ============================================================================

  # https://devenv.sh/git-hooks/

  git-hooks.hooks = {

    # ==========================================================================
    # FAST VALIDATION (< 1s)
    # ==========================================================================

    # File format and integrity checks
    # check-xml = {
    #   enable = true;
    # };
    # check-yaml = {
    #   enable = true;
    # };
    # check-json = {
    #   enable = true;
    # };
    check-merge-conflicts = {
      enable = true;
    };
    check-case-conflicts = {
      enable = true;
    };
    check-executables-have-shebangs = {
      enable = true;
    };
    check-shebang-scripts-are-executable = {
      enable = true;
    };
    check-symlinks = {
      enable = true;
    };

    check-added-large-files = {
      enable = true;
      args = [ "--maxkb=1024" ]; # 1MB limit for API projects
    };

    # File formatting fixes
    end-of-file-fixer = {
      enable = true;
      excludes = [
        ".kilocode/"
        ".opencode/"
        ".specify/"
      ];
    };
    fix-byte-order-marker = {
      enable = true;
    };
    mixed-line-endings = {
      enable = true;
    };
    trim-trailing-whitespace = {
      enable = true;
      excludes = [
        ".kilocode/"
        ".opencode/"
        ".specify/"
      ];
    };

    # ==========================================================================
    # CODE FORMATTING (1-5s)
    # ==========================================================================

    # NIX
    nixfmt-rfc-style = {
      enable = true;
    };

    # GOLANG
    # Standard Go formatting
    # gofmt = {
    #   enable = true;
    # };

    # Go testing (requires serial execution)
    # gotest = {
    #   enable = true;
    # };

    # Go static analysis (requires serial execution)
    # govet = {
    #   enable = true;
    # };

    # Advanced static analysis for Go
    # staticcheck = {
    #   enable = true;
    #   excludes = [ ".specify/" ];
    # };

    # SHELL/BASH
    # shellcheck: Static analysis for shell scripts
    # shfmt: Shell script formatter (Google Bash Style Guide)
    shellcheck = {
      enable = true;
      excludes = [
        "^\\.envrc$"
        ".specify/"
      ]; # Exclude direnv config files and .specify directory
    };
    shfmt = {
      enable = true;
      entry = "${pkgs.shfmt}/bin/shfmt -i 2 -ci -bn -sr -w";
      types = [ "shell" ];
      pass_filenames = true;
      excludes = [
        ".kilocode/"
        ".opencode/"
        ".specify/"
      ];
    };

    # Custom bash variable syntax enforcement
    # bash-variable-braces = {
    #   enable = true;
    #   entry = "\\$[A-Za-z_][A-Za-z0-9_]*(?![}\\[])";
    #   language = "pygrep";
    #   files = "\\.(sh|bash)$";
    #   name = "Require \${VAR} instead of $VAR in bash scripts";
    #   description = "Require \${VAR} syntax instead of $VAR for bash variables";
    # };

    # YAML
    # MARKUP/CONFIG LANGUAGES
    yamllint = {
      enable = true;
    };

    # ==========================================================================
    # SECURITY VALIDATION
    # ==========================================================================

    # Fast regex-based secret detection
    ripsecrets = {
      enable = true;
    };

    # SOPS encryption enforcement
    pre-commit-hook-ensure-sops = {
      enable = true;
    };

    # Comprehensive secrets scanner (slower but thorough)
    # trufflehog = {
    #   enable = true;
    #   pass_filenames = false;
    #   stages = [
    #     "pre-commit"
    #     "manual"
    #   ];
    # };

    # AWS credentials detection
    detect-aws-credentials = {
      enable = true;
      args = [ "--allow-missing-credentials" ];
    };

    # Private key detection
    detect-private-keys = {
      enable = true;
    };

    # VCS permalink validation
    check-vcs-permalinks = {
      enable = true;
    };

  };
}
