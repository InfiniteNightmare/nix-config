# amdxdna NPU: XRT pins large BOs with mlock; rootless access needs this
{ ... }:
{
  security.pam.loginLimits = [
    {
      domain = "*";
      type = "-";
      item = "memlock";
      value = "unlimited";
    }
  ];
}
