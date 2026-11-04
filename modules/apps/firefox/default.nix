{ pkgs, ... }:

let
  lock-false = {
    Value = false;
    Status = "locked";
  };
  lock-true = {
    Value = true;
    Status = "locked";
  };
in
{
  programs = {
    firefox = {
      enable = true;
      package = pkgs.firefox-esr;
      languagePacks = [ "en-US" ];

      # ---- POLICIES ----
      # Check about:policies#documentation for options.
      policies = {
        DisableTelemetry = true;
        DisableFirefoxStudies = true;
        EnableTrackingProtection = {
          Value = true;
          Locked = true;
          Cryptomining = true;
          Fingerprinting = true;
        };
        DisablePocket = true;
        DisableFirefoxAccounts = true;
        DisableAccounts = true;
        DisableFirefoxScreenshots = true;
        OverrideFirstRunPage = "";
        OverridePostUpdatePage = "";
        DontCheckDefaultBrowser = true;
        DisplayBookmarksToolbar = "never"; # alternatives: "always" or "newtab"
        DisplayMenuBar = "default-off"; # alternatives: "always", "never" or "default-on"
        SearchBar = "unified"; # alternative: "separate"
        SearchEngines = {
          Default = "DuckDuckGo";
          PreventChangingDefault = true;
        };

        # ---- EXTENSIONS ----
        # Check about:support for extension/add-on ID strings.
        # Valid strings for installation_mode are "allowed", "blocked",
        # "force_installed" and "normal_installed".
        ExtensionSettings = {
          "*".installation_mode = "blocked"; # blocks all addons except the ones specified below
          # uBlock Origin
          # To update: find the latest version URL at
          #   https://addons.mozilla.org/firefox/addon/ublock-origin/versions/ (click "See all versions")
          # then run:  nix-prefetch-url <the .xpi URL> && nix hash convert --hash-algo sha256 <output>
          # It prints the sha256 hash; paste the URL and SRI hash below
          # (prefetch stores the file in /tmp, so the URL stays valid for fetchurl)
          "uBlock0@raymondhill.net" = {
            install_url = "file://${
              pkgs.fetchurl {
                url = "https://addons.mozilla.org/firefox/downloads/file/5203014/ublock_origin-1.75.4.xpi";
                hash = "sha256-4t9QPM589QaRMGGMNJaV9ivd2564wYkVbQJyaa5K4mc=";
              }
            }";
            installation_mode = "force_installed";
          };
          # bitwarden
          # To update: find the latest version URL at
          #   https://addons.mozilla.org/firefox/addon/bitwarden-password-manager/versions/
          # then run:  nix-prefetch-url <the .xpi URL> && nix hash convert --hash-algo sha256 <output>
          # It prints the sha256 hash; paste the URL and SRI hash below
          "{446900e4-71c2-419f-a6a7-df9c091e268b}" = {
            install_url = "file://${
              pkgs.fetchurl {
                url = "https://addons.mozilla.org/firefox/downloads/file/5198653/bitwarden_password_manager-2026.10.2.xpi";
                hash = "sha256-q/nXJz3VWsBYPsxpl/f3rj0p3hHirQpIOLgOK5QdqnM=";
              }
            }";
            installation_mode = "force_installed";
          };
        };

        # ---- PREFERENCES ----
        # Check about:config for options.
        Preferences = {
          "browser.contentblocking.category" = {
            Value = "strict";
            Status = "locked";
          };
          "extensions.pocket.enabled" = lock-false;
          "extensions.screenshots.disabled" = lock-true;
          "browser.topsites.contile.enabled" = lock-false;
          "browser.formfill.enable" = lock-false;
          "browser.search.suggest.enabled" = lock-false;
          "browser.search.suggest.enabled.private" = lock-false;
          "browser.urlbar.suggest.searches" = lock-false;
          "browser.urlbar.showSearchSuggestionsFirst" = lock-false;
          "browser.newtabpage.activity-stream.feeds.section.topstories" = lock-false;
          "browser.newtabpage.activity-stream.feeds.snippets" = lock-false;
          "browser.newtabpage.activity-stream.section.highlights.includePocket" = lock-false;
          "browser.newtabpage.activity-stream.section.highlights.includeBookmarks" = lock-false;
          "browser.newtabpage.activity-stream.section.highlights.includeDownloads" = lock-false;
          "browser.newtabpage.activity-stream.section.highlights.includeVisited" = lock-false;
          "browser.newtabpage.activity-stream.showSponsored" = lock-false;
          "browser.newtabpage.activity-stream.system.showSponsored" = lock-false;
          "browser.newtabpage.activity-stream.showSponsoredTopSites" = lock-false;
          "privacy.fingerprintingProtection" = lock-true;
          "privacy.fingerprintingProtection.pbmode" = lock-true;
          "privacy.resistFingerprinting" = lock-true;
          "privacy.resistFingerprinting.pbmode" = lock-true;
        };
      };
    };
  };
}
