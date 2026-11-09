{
  ...
}:

let
  proxySettings = import ../../lib/proxy-settings.nix;
in
{
  # GUI apps never see fish's __proxy_on, so their spawned processes (codex
  # runtimes, updaters) connect to OpenAI directly and stall; mirror the fish
  # proxy values into the graphical session.
  environment.sessionVariables = {
    http_proxy = proxySettings.httpProxy;
    https_proxy = proxySettings.httpsProxy;
    all_proxy = proxySettings.allProxy;
    HTTP_PROXY = proxySettings.httpProxy;
    HTTPS_PROXY = proxySettings.httpsProxy;
    ALL_PROXY = proxySettings.allProxy;
    no_proxy = proxySettings.noProxy;
    NO_PROXY = proxySettings.noProxy;
  };
}
