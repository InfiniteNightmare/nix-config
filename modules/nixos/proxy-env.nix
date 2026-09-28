{
  ...
}:

{
  # GUI apps never see fish's __proxy_on, so their spawned processes (codex
  # runtimes, updaters) connect to OpenAI directly and stall; mirror the fish
  # proxy values into the graphical session.
  environment.sessionVariables = {
    http_proxy = "http://127.0.0.1:7890";
    https_proxy = "http://127.0.0.1:7890";
    all_proxy = "socks5h://127.0.0.1:7890";
    HTTP_PROXY = "http://127.0.0.1:7890";
    HTTPS_PROXY = "http://127.0.0.1:7890";
    ALL_PROXY = "socks5h://127.0.0.1:7890";
    no_proxy = "localhost,127.0.0.1,::1,cache.numtide.com,noctalia.cachix.org,niri.cachix.org,mirrors.ustc.edu.cn,cache.nixos.org,tarballs.nixos.org,fnos-lan.charname.fnos.net,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16";
    NO_PROXY = "localhost,127.0.0.1,::1,cache.numtide.com,noctalia.cachix.org,niri.cachix.org,mirrors.ustc.edu.cn,cache.nixos.org,tarballs.nixos.org,fnos-lan.charname.fnos.net,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16";
  };
}
